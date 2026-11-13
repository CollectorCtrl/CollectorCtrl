# Architecture

CollectorCtrl is a self-hosted control plane for OpenTelemetry Collector fleets. It manages collectors; it never sits in the telemetry data path.

```mermaid
flowchart TB
    People["People<br/>browser · SSO"] -- "HTTPS :4321" --> CP
    Agents["AI agents<br/>MCP clients"] -- "HTTPS :4321 /api/mcp" --> CP

    subgraph CP["CollectorCtrl Server · single binary"]
        direction LR
        A["Web UI · REST API · MCP<br/>AI Copilot"]
        B["OpAMP gateway :4320<br/>Package repo · Onboarding"]
        C["Git sync · Rollouts · Watchdogs<br/>Governance (Telemetry Governor) · Audit"]
    end

    CP --- DB[("SQLite / PostgreSQL")]
    CP --- DATA[("Data directory<br/>CA · keys · secrets · packages")]
    CP -. "your approved model" .-> LLM["LLM provider or<br/>self-hosted model"]
    CP <-. "HTTPS" .-> GH["GitHub / GitHub Enterprise"]
    CP -. "OTLP audit stream" .-> SIEM["SIEM"]

    subgraph H["Each managed host"]
        SUP["Supervisor"] --> MAIN["Main collector"]
        SUP -.-> SIDE["Sidecar collector"]
        SUP -.-> APPS["Instrumented apps"]
    end
    SUP == "OpAMP · WSS · per-agent credential<br/>HTTPS · signed packages" ==> CP
    MAIN -- "telemetry" --> BE["Any backend"]
```

## Components

### Server

A single Go binary that embeds the web UI and serves:

- the **web UI** and **REST API** (port 4321, HTTPS), including onboarding scripts, the server CA and the package mirror (`/packages/`) that install commands and supervisors download from;
- `/readyz` and `/metrics` (Prometheus) for operations;
- the **MCP endpoint** (`/api/mcp`) for AI clients;
- the **OpAMP gateway** (port 4320, WSS) that every supervisor connects to;
- background services: Git sync, canary and rollout state, upgrade governor and watchdogs, notifications, SIEM audit streaming, package mirror sync, Governance (Telemetry Governor) ingest and analytics.

State lives in **SQLite** (default) or **PostgreSQL**, plus a **data directory** that holds the per-install CA, private keys and secrets (see [Configuration](configuration.md#data-directory)). Run **one server instance**: running two active servers against one database is not supported.

The web console is organised by job: **Overview**, **Fleet**, **Rollouts**, **Catalog**, **Governance**, **Instrumentation**, **Settings** and **Docs & API**.

### Supervisor

A small OS-native agent on each host: a Windows service, systemd unit or launchd daemon. It runs as root or LocalSystem by default; on Linux it can run as an unprivileged user (opt-in). It:

- keeps a persistent, authenticated OpAMP connection to the server (outbound only);
- starts, stops and restarts the **main** collector and an optional **sidecar** collector, independently. It runs the collector you already have: the installer takes over a collector that ran as its own service;
- **validates every new configuration** with the collector before applying it, and rolls back to the last known good config if a new one crash-loops the collector;
- reports health, effective configuration and its hash, component details and attributes, including the labels set at install time;
- installs **signed** collector and supervisor packages, with a connection watchdog that rolls back a supervisor upgrade that can't reconnect;
- optionally discovers and instruments applications (ZeroTouch).

The Supervisor keeps running, and stays reachable, when the collector crashes.

### Collector

Any OpenTelemetry Collector binary: upstream `otelcol` / `otelcol-contrib`, a vendor distribution, or a build from the integrated Custom Builder (`ocb`).

### Kubernetes observer (pilot)

An optional component for clusters, run as a single replica: the [Kubernetes observer](https://github.com/CollectorCtrl/CollectorCtrl-K8s-Operator). It watches collector Deployments, DaemonSets and StatefulSets and reports their identity, observed configuration and pods to the server over OpAMP, using enrolled credentials it keeps on persistent storage. It is read-only: deployments and configuration stay with your Helm charts, GitOps or CI/CD.

## Configuration flow

1. A change is made in the UI, through the API or MCP (after approval), or merged in Git.
2. The server resolves which collectors it applies to (policy selectors, overrides, canary cohort), validates the YAML, stores the new version with its SHA-256 and history, and writes an audit entry.
3. The configuration is sent to each matching supervisor over OpAMP. Offline collectors receive it when they reconnect.
4. The supervisor merges it with local configuration sources, has the collector validate it, then restarts only the pipeline whose configuration changed (main or sidecar). It saves the remote configuration, so a restart while the server is unreachable keeps it.
5. The supervisor reports the configuration as applied only after the collector has restarted with it and passed a health check, with the applied hash. The server marks the change delivered and confirmed, or failed with the collector's error.
6. From then on, every heartbeat carries the effective config hash. A difference is reported as **drift** and, per policy, reverted.

## Agent identity and transport

- The server creates its own **CA** on first start and serves TLS on both ports. Supervisors pin the CA's SHA-256 fingerprint at enrollment.
- Each supervisor enrolls once with a short-lived **enrollment token** and receives a **per-agent credential** bound to its instance UID. Later connections authenticate with that credential, and a connection can't act as another instance.
- Governance taps get per-agent tap tokens issued by the server over OpAMP. Every tap and external source samples at one global rate set on the server.
- The server verifies the release signature of every supervisor package it mirrors, and the one-line install commands check the package against that signature.

More detail: [Security](security.md).

## Ports

| Port | Direction | Purpose |
| :--- | :--- | :--- |
| 4320 | Inbound to server | OpAMP gateway (WSS) |
| 4321 | Inbound to server | UI, REST API, MCP, onboarding, package downloads, `/readyz`, `/metrics` (HTTPS) |
| 5432 | Server to database | PostgreSQL, if used |
| 13133 | Local on each host | Collector health check (`127.0.0.1` by default) |
