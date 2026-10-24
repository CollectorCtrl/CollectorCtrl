# Features

What CollectorCtrl does as of **v0.6.3-beta**. Everything is **beta** unless marked otherwise.

- [Fleet management](#fleet-management)
- [Kubernetes workloads (pilot)](#kubernetes-workloads-pilot)
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
- **Fleet Classification Rules:** ordered environment and role rules (agent, gateway, K8s sidecar) with operators such as equals, contains, starts/ends with and regex. A live preview shows exactly which collectors a rule matches, and what would be left without an environment, before you save. Environment names are case-insensitive everywhere, one spelling is kept per environment, and collectors without one show as **Unclassified**.
- **Environment scoping:** pick an environment on the Fleet page and the Notification Center, search and Copilot follow it.
- **Remote control:** start, stop and restart collectors (and sidecars) individually or in bulk. Every command is audit-logged.
- **Configuration templates:** the distinct configurations running across the fleet, which collectors use each one, and which recently moved between templates.

## Kubernetes workloads (pilot)

- **Observe existing collectors in Kubernetes** with the [Kubernetes observer](https://github.com/CollectorCtrl/CollectorCtrl-K8s-Operator): Deployments, DaemonSets and StatefulSets deployed by your own Helm charts or GitOps appear next to host collectors. You keep your existing charts, repositories and pipelines.
- **One inventory:** switch between All, Host collectors and Kubernetes workloads, with cluster and namespace filters.
- **Workload detail:** observed ConfigMap references, configuration hashes, optional configuration content (opt-in), pod instances with their lifecycle, and source and ownership information.
- **Freshness:** stale or disconnected observations are shown as historical, not current.
- **Safe by design:** observed workloads are read-only. Host policies, canaries, upgrades, taps and host-only actions skip them, and Copilot and MCP answers distinguish them from managed hosts.
- The observer enrolls with its own credential. Pilot limits: no Secret-backed configs, native OpenTelemetry Operator resources or OpenShift DeploymentConfigs yet, and live-cluster validation on managed Kubernetes platforms is still in progress.

## Configuration and policies

- **Fleet policies** target collectors with Kubernetes-style label selectors (`matchLabels`, `matchExpressions`), including the `collectorctrl.environment` and `collectorctrl.role` classification attributes.
- **Versioned configurations:** every change is SHA-256 hashed and versioned, with full policy history.
- **Canary rollouts:** deploy to a share of the matching collectors first, then **Promote** or **Abort**. A canary can be promoted only once every canary collector is connected, has received the policy and runs its current version; forcing a promotion is recorded in the audit log. Canaries survive server restarts, and aborting never releases the new config to the rest of the fleet.
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
- **60+ tools:** fleet, configs, policies and canaries, GitOps, templates, history, upgrades, Telemetry Governor (including pattern ranking and rule optimization), discovery, sidecars and notifications. Also **5 runbook prompts**: triage an unhealthy collector, standardize config drift, make a safe fleet change, troubleshoot a sidecar, optimize telemetry volume.
- **Governed:** API-token authentication, per-tool RBAC, an audit entry per call (`mcp:<user>`), human approval for every change, blast-radius caps, 15-minute proposal expiry, and optional four-eyes approval.

## Telemetry Governor

- **Telemetry taps** on running collectors sample logs and traces at one rate across every severity (default 10%), without blocking or slowing the primary pipeline. Traces are sampled by trace ID, so a sampled trace stays complete.
- **Telemetry Insights** ranks recurring log patterns and span routes by the records received, with plain-language findings (for example, the share of the top patterns, health checks, debug logs or the noisiest service), charts, and a searchable pattern table with CSV export. It shows measured counts only, never projected volumes or savings.
- **Log Pattern / Span Route Optimizer:** turns a noisy pattern into a filter, sampling, tail-sampling or normalization rule, previews its measured impact, checks it, and rolls it out through a policy. Warnings and errors are never suggested for dropping. An optional AI review adds advisory notes.
- **Destinations:** fan out to S3 (partitioned, Athena-ready) or OTLP endpoints, with connectivity tests.
- Use it to find where ingest cost comes from and cut it at the edge, before data reaches paid backends.

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
- **API tokens** for automation and MCP clients, scoped by role and environment. An environment-scoped token sees and acts only on that environment (collectors, notifications, search and Copilot answers) and can only create tokens for its own environment.

## Audit and compliance

- **Tamper-evident audit trail:** entries are hash-chained, and **Verify integrity** pinpoints any altered entry.
- Each event records who acted (person, named API token, AI or system), source IP, user agent, request ID and outcome. Refused requests are recorded too.
- Server-side search across the full history, shareable filtered links, CSV export.
- **SIEM streaming:** audit events in real time as OTLP logs, over TLS, to any OTLP-compatible endpoint.

## Notifications

- In-app notifications with per-user read state, linking to the affected collector or page.
- **By environment:** every notification records its environment. The Notification Center, bell count, **Mark read** and **Clear** follow the selected environment, and each environment keeps its own history. Installation-wide events show as **Fleet-wide**.
- **Alert channels:** email (SMTP), Slack, Microsoft Teams, PagerDuty and webhooks. Each channel can receive all environments or only selected ones, for example Production to PagerDuty and Development to Slack, and every alert includes its environment.
- **Fewer alerts during outages:** when many collectors disconnect or reject a config at once, more than 5 in an environment become one summary alert.
- Events include disconnects, rejected configs, failed or rolled-back upgrades, impersonation attempts, Git sync failures and instrumentation results.

## Operations

- **Single binary** server with an embedded web UI. SQLite or PostgreSQL. Windows service, systemd, launchd or container.
- **TLS by default** with a per-install CA, or bring your own certificates or reverse proxy.
- **One-command backup and restore**, including keys, certificates and state.
- **REST API** with an OpenAPI specification ([docs/api/openapi.json](api/openapi.json)).
- **Verified onboarding:** the server detects its own address, and Linux, macOS and Windows onboarding commands check the server's CA fingerprint before downloading anything.
- **Signed releases:** every download has a detached Ed25519 signature, and server and supervisor binaries have an SPDX SBOM.
