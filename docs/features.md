# Features

What CollectorCtrl does as of **v0.5.5-beta**. Everything is **beta** unless marked otherwise.

- [Fleet management](#fleet-management)
- [Configuration and policies](#configuration-and-policies)
- [Drift prevention and configuration integrity](#drift-prevention-and-configuration-integrity)
- [GitOps](#gitops)
- [Sidecar collectors](#sidecar-collectors)
- [Supervisor and collector lifecycle](#supervisor-and-collector-lifecycle)
- [Custom Builder](#custom-builder)
- [AI Copilot](#ai-copilot)
- [MCP server](#mcp-server)
- [Telemetry Governor](#telemetry-governor)
- [ZeroTouch instrumentation (alpha)](#zerotouch-instrumentation-alpha)
- [Identity and access](#identity-and-access)
- [Audit and compliance](#audit-and-compliance)
- [Notifications](#notifications)
- [Operations](#operations)

---

## Fleet management

- **Live inventory** of every collector connected over OpAMP: health, status reason, version, OS and architecture, effective configuration, attributes and last heartbeat.
- **Three views:** a searchable table with configurable columns and quick filters, a **honeycomb** health map, and a **topology** view of collectors, gateways and their connections.
- **Classification:** ordered environment and role rules (agent, gateway, sidecar) with operators such as equals, contains, starts/ends with and regex. A live preview shows exactly which collectors a rule matches before you save it.
- **Remote control:** start, stop and restart collectors (and sidecars) individually or in bulk. Every command is audit-logged.
- **Configuration templates:** the distinct configurations running across the fleet, which collectors use each one, and which recently moved between templates.

## Configuration and policies

- **Fleet policies** target collectors with Kubernetes-style label selectors (`matchLabels`, `matchExpressions`), including the `collectorctrl.environment` and `collectorctrl.role` classification attributes.
- **Versioned configurations:** every change is SHA-256 hashed and versioned, with full policy history.
- **Canary rollouts:** deploy to a share of the matching collectors first, then **Promote** or **Abort**. Canaries survive server restarts. Aborting never releases the new config to the rest of the fleet.
- **Rollback** restores the complete saved policy and records it as a new version.
- **Safe editing:** optimistic concurrency means a save is refused instead of overwriting a colleague's newer change.
- **Durable saves:** a save reports success only once it's stored. The UI shows separately whether the change was delivered and whether the collector confirmed it.
- **Per-collector overrides** and **configuration history** with side-by-side or unified diffs, compare-any-two, search by author or SHA, and one-click restore.

## Drift prevention and configuration integrity

- Every supervisor reports its effective configuration hash. The server compares it with the governed configuration and shows each collector as in sync, reconciling or drifted.
- Per policy, drift is either **reported** or **automatically reverted**.
- **Validate before apply:** the Supervisor checks every new config with the collector itself. A config the collector rejects never replaces the running one, and the push is marked failed with the collector's own error message.
- **Crash-loop rollback:** if a config passes validation but makes the collector crash repeatedly, the Supervisor returns to the last known good config and reports the failure.

## GitOps

- Connect a **GitHub or GitHub Enterprise** repository, with a built-in check of repository access, branch, write permission and policy files.
- **Export** current policies and overrides to the repository in one commit.
- **Automatic sync** on a schedule (default 60 s), and within seconds via a signed webhook. Every change goes through the same validation, canary gate, history and audit as a UI edit.
- **Drift view:** side-by-side diff between Git and the running state. Choose report-only, or let Git restore the approved configuration.
- **Pull requests from CollectorCtrl,** with status tracking; **emergency commits** require a reason.
- Details: [GitOps guide](gitops.md).

## Sidecar collectors

- A second collector on the same host, supervised independently: for example a SIEM pipeline kept separate from the observability pipeline, with RBAC per team.
- Start, stop, restart, reconfigure or disable the sidecar without touching the main collector. **Restart Both** is available when you need it.
- Separate health: a failing sidecar never marks the main collector unhealthy.
- Sidecar status in the fleet table, summary, honeycomb and topology views, with **Has sidecar** and **Sidecar issues** filters.

## Supervisor and collector lifecycle

- **Signed package repository** for supervisor, collector and sidecar packages, with a Trust column (Release-signed / Signed by … / Unsigned).
- **Supervisor upgrades** accept only the vendor release signature, so even a compromised server can't push a new supervisor.
- **Collector and sidecar upgrades** accept a release signature or an explicit **Sign** approval in the UI, recorded in the audit log.
- **Fleet-wide upgrade governance:** upgrades are throttled and queued, and a bulk upgrade halts automatically if too many fail. A new supervisor that can't reconnect within its watchdog window rolls itself back to the previous version. Collector upgrades are verified after install and rolled back on failure. A collector you stopped on purpose stays stopped after an upgrade.

## Custom Builder

- Build tailored collector binaries with the OpenTelemetry Collector Builder (`ocb`) from the UI, choosing only the components you need.
- Built packages land in the package repository, where you sign them and roll them out like any other collector.

## AI Copilot

- A chat assistant **inside the control plane** that answers from **live fleet data** using read-only tools (fleet health, configs, history, policies, audit, Governor analytics), with web search optional.
- **Streams** its answer and each tool step as it works. Supports slash commands, `@`-mentions of collectors, policies and pipelines, syntax-highlighted YAML, and a dockable panel. Open it from the config editor with a collector's configuration attached.
- **Proposes, never applies:** a change comes as a proposal with a diff and blast radius, which a person approves in **Settings → Pending AI Actions**. The Copilot can't approve its own proposals.
- **Bring your own model:** OpenAI, Anthropic, Google Gemini, or any **OpenAI-compatible endpoint**, including self-hosted and enterprise-approved models. Optional PII redaction.
- Every Copilot action is audit-logged.

Details: [AI Copilot and MCP](ai-copilot-and-mcp.md).

## MCP server

- A built-in **Model Context Protocol** endpoint (`/api/mcp`), plus a stdio adapter (`collectorctrl-mcp`) for Claude Desktop, Cursor and other MCP clients.
- **60+ tools:** fleet, configs, policies and canaries, GitOps, templates, history, upgrades, Telemetry Governor, discovery, sidecars and notifications. Also **4 runbook prompts**: triage an unhealthy collector, standardize config drift, make a safe fleet change, troubleshoot a sidecar.
- **Governed:** API-token authentication, per-tool RBAC, an audit entry per call (`mcp:<user>`), human approval for every change, blast-radius caps, 15-minute proposal expiry, and optional four-eyes approval.

## Telemetry Governor

- **Telemetry taps** on running collectors that keep **100% of errors** (error logs, failed spans) and sample the rest, without blocking or slowing the primary pipeline.
- **Command Center:** volume and cardinality analytics, pattern intelligence, and an edge filter generator that turns recurring noise into filter rules.
- **Destinations:** fan out to S3 (partitioned, Athena-ready) or OTLP endpoints, with connectivity tests.
- Use it to see where ingest cost comes from and cut it at the edge, before data reaches paid backends.

## ZeroTouch instrumentation (alpha)

- **Application discovery** on managed hosts: runtime, framework and version of running applications. Off by default and controlled per host, with every toggle audited.
- **Enable or remove** OpenTelemetry agents for **Java, .NET, Node.js and Python** from the UI, with an optional canary cohort. Services (Windows services, IIS app pools, systemd units) are marked "restart required" and pick up instrumentation on their next restart; standalone processes are relaunched under supervision.
- **Agent baselines and central catalog** manage instrumentation agent versions across the fleet, with group overrides and per-node pins.
- **Safety:** nodes act only on their own discovery data, only `OTEL_*` variables are accepted, services are never restarted without consent, relaunched apps keep their original user, and agent assets are checksum-pinned.
- Verified end to end for Java, Node.js and Python. .NET support is partial and depends on the framework.

## Identity and access

- **Per-agent identity:** enrollment tokens and per-agent credentials bound to the instance UID, impersonation detection, revoke and re-enroll.
- **OIDC single sign-on** with guided setup and presets for Okta, Microsoft Entra ID, Google Workspace, Keycloak and Auth0. A **test sign-in** shows the claims and resulting role before you switch SSO on. Includes JIT provisioning, ordered group-to-role rules, break-glass local admins, and local sign-in that keeps working if the IdP is down.
- **RBAC:** built-in Admin, Editor and Viewer roles plus custom roles with granular permissions and environment scoping. A **grant ceiling** means nobody can hand out permissions they don't hold.
- **API tokens** for automation and MCP clients, scoped by role and environment.

## Audit and compliance

- **Tamper-evident audit trail:** entries are hash-chained, and **Verify integrity** pinpoints any altered entry.
- Each event records who acted (person, named API token, AI or system), source IP, user agent, request ID and outcome. Refused requests are recorded too.
- Server-side search across the full history, shareable filtered links, CSV export.
- **SIEM streaming:** audit events in real time as OTLP logs, over TLS, to any OTLP-compatible endpoint.

## Notifications

- In-app notifications with per-user read state, linking to the affected collector or page.
- Alert channels including email (SMTP), webhooks and PagerDuty (routing keys, with repeat alerts grouped).
- Events include disconnects, rejected configs, failed or rolled-back upgrades, impersonation attempts, Git sync failures and instrumentation results.

## Operations

- **Single binary** server with an embedded web UI. SQLite or PostgreSQL. Windows service, systemd, launchd or container.
- **TLS by default** with a per-install CA, or bring your own certificates or reverse proxy.
- **One-command backup and restore**, including keys, certificates and state.
- **REST API** with an OpenAPI specification ([docs/api/openapi.json](api/openapi.json)).
- **Signed releases:** every download has a detached Ed25519 signature.
