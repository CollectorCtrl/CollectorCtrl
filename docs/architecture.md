# CollectorCtrl: Technical Architecture

CollectorCtrl is an on-prem, enterprise-grade control plane designed for **high availability, zero-drift configuration management, and low-latency fleet governance** at global scale.

---

## Component Overview

### 1. Management Server (Main Control Plane)

The **Management Server** is the heart of the platform. It is deployed on-premise or within your private cloud and exposes:

- **Admin UI Console**: A modern, secure, web-based dashboard for administration, policy design, fleet visualization, and configuration management.
- **REST API & SDKs**: Full programmatic access to manage configurations, query agent state, trigger rollouts, and sync package assets.
- **OpAMP Gateway**: A high-performance WebSocket endpoint executing the OpenTelemetry Agent Management Protocol (OpAMP) — the core control channel for all active Supervisor connections.
- **Metadata Database**: Tracks fleet state, users, roles, audit trails, and versioned policy history.
  - **SQLite** (Standard): Zero-config, single-file database for developer/sandbox deployments and small fleets (< 50 agents).
  - **PostgreSQL** (Production): High-concurrency database engine required for production fleets.

### 2. Supervisor Agent (The "Manager")

The **Supervisor** is an extremely lightweight, OS-native daemon deployed alongside the OTel Collector on each target node. It runs as a **Windows Service** or **Linux systemd unit**. Its primary responsibilities:

- **Process Lifecycle Management**: Spawns, monitors, and automatically restarts the OTel Collector process if it crashes or stalls.
- **OpAMP Client Connection**: Maintains a secure, persistent, bidirectional WebSocket channel to the Management Server.
- **Active Reconciler**: Pulls assigned configurations from the control plane, writes them to the local `config_path`, and signals the Collector to hot-reload dynamically (via SIGHUP on Linux or the local admin API reload hook on Windows).
- **Local Drift Guardian**: Continuously watches on-disk file integrity. Any manual configuration edits are **instantly overwritten** by the Supervisor with the server's authorized configuration snapshot.

### 3. OpenTelemetry Collector (The "Worker")

The **Collector** is the actual OpenTelemetry Collector binary execution process managed by the Supervisor as a child worker. This can be:

- The upstream **OTel Core** or **OTel Contrib** distribution
- A vendor-supported binary (e.g., Coralogix, Dynatrace, Datadog Agent)
- A custom-compiled binary created via the CollectorCtrl **Custom Builder**

---

## Data Flow & Protocol

### OpAMP Protocol

CollectorCtrl uses the **Open Agent Management Protocol (OpAMP)** to ensure standardized, bidirectional communication between the Management Server and all Supervisor agents.

- **Agent → Server (Heartbeats)**: Agents send periodic health reports and current configuration hashes. The server compares hashes to detect drift and initiates reconciliation if needed.
- **Server → Agent (Policy Push)**: The server pushes new configuration payloads, upgrade instructions, or control commands (Restart/Start/Stop) over the WebSocket channel.
- **Agent → Server (Effective Config)**: Agents report their effective (applied) configuration after a successful reload, confirming the policy is active.

### Dynamic Configuration Trigger (Hot-Reload Flow)

When an administrator publishes a policy update from the UI console:

1. **Validation Check**: The server compiles the final YAML (resolving target selectors and merge rules) and executes a dry-run check.
2. **File Writing**: The Supervisor receives the YAML payload over the OpAMP channel and writes it to the designated `config_path`.
3. **Triggering the Reload**:
   - **Linux Hosts**: The Supervisor sends a `SIGHUP` signal directly to the OTel Collector process ID, prompting it to hot-reload without tearing down sockets.
   - **Windows Hosts**: The Supervisor calls the collector's local admin API reload hook (`POST http://localhost:13133/schema/reload`). If the reload endpoint is unavailable, the Supervisor executes a fast process restart within 150 milliseconds.

---

## Network Requirements (Firewall)

| Port | Protocol | Direction | Description |
| :--- | :--- | :--- | :--- |
| **4320** | TCP / WSS | Inbound to Server | **OpAMP Gateway**: Core WebSocket control channel for active Supervisor agents |
| **4321** | TCP / HTTPS | Inbound to Server | **Dashboard Console**: Exposes the Admin UI and REST API |
| **13133** | TCP | Localhost only | **OTel Health Check**: Used by the Supervisor to check Collector process health |
| **5432** | TCP | Outbound from Server | **PostgreSQL Store**: Database connection (if using Postgres) |

> *Note: The Supervisor Agent connects **outbound** to the Server on port 4320. No inbound ports need to be opened on the agent machines themselves.*

---

## Scalability & Production Datastores

Developer trials run out-of-the-box using an embedded **SQLite** database. Production deployments must use **PostgreSQL** for high-concurrency workloads.

### PostgreSQL Sizing Guidelines

| Fleet Size (Active Agents) | Recommended CPU (vCPUs) | Recommended RAM (GB) | Storage Engine IOPS |
| :--- | :--- | :--- | :--- |
| **Developer / Sandbox** (< 50) | 2 | 4 | 500 (General SSD) |
| **Mid-Scale Enterprise** (50 – 1,000) | 4 | 8 | 3,000 (Provisioned) |
| **Global Infrastructure** (1,000 – 10,000+) | 8 – 16 | 16 – 32 | 10,000+ (High Performance) |

*For larger environments exceeding 10,000 concurrent supervisors, configure read replicas to offload API query operations and reporting analytics.*

---

## Security Model

- **TLS Encryption**: All traffic is encrypted via TLS. Minimum supported version: **TLS 1.2** (TLS 1.3 recommended).
- **Mutual TLS (mTLS)**: Agents can be provisioned with unique client certificates for strong, hardware-rooted authentication — preventing spoofing.
- **JWT Auth**: User sessions in the Admin UI are secured via JSON Web Tokens (JWT).
- **OIDC / SSO**: Integrate with Azure AD, Okta, Auth0, or any OIDC-compliant identity provider.

---

*The architecture is designed to be "Supervisor-first": the Supervisor remains running and manageable even if the OTel Collector binary crashes. The Supervisor restarts the Collector automatically and maintains its OpAMP connection to the Management Server throughout.*
