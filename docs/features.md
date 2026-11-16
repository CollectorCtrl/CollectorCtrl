# Features

What CollectorCtrl does as of **v0.8.0-beta**. Everything is **beta** unless marked otherwise.

The side menu of the web console is **Overview**, **Fleet**, **Rollouts**, **Catalog**, **Governance**, **Instrumentation**, **Settings** and **Docs & API**. Governance is the section formerly called Telemetry; the engine behind it is the Telemetry Governor.

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
- [Installation and enrollment](#installation-and-enrollment)
- [Governance](#governance)
- [Instrumentation (alpha)](#instrumentation-alpha)
- [Identity and access](#identity-and-access)
- [Audit and compliance](#audit-and-compliance)
- [Notifications](#notifications)
- [Operations](#operations)

---

## Fleet management

- **Live inventory** of every collector connected over OpAMP: health, status reason, version, OS and architecture, effective configuration, attributes and last heartbeat.
- **Three views:** a **List** with one filter bar, an attention line that links to what needs a person, and fifty rows per page; a **Map**; and a **Topology** view of collectors, gateways and their connections. Paging and filtering run in the database, and a page shows at most 5,000 collectors.
- **Overview:** a first-run page with the server's address, **Add collector** and a setup checklist, and a summary page afterwards.
- **Fleet Classification Rules:** ordered environment and role rules (agent, gateway, K8s sidecar) with operators such as equals, contains, starts/ends with and regex. A live preview shows exactly which collectors a rule matches, and what would be left without an environment, before you save. Environment names are case-insensitive everywhere, one spelling is kept per environment, and collectors without one show as **Unclassified**.
- **Environment scoping:** the environment scope in the top bar applies on every page, and the Notification Center, search and Copilot follow it.
- **Remote control:** start, stop and restart collectors (and sidecars) individually or in bulk. Every command is audit-logged.
- **Configuration templates:** the distinct configurations running across the fleet, which collectors use each one, and which recently moved between templates.

## Kubernetes workloads (pilot)

- **Observe existing collectors in Kubernetes** with the [Kubernetes observer](https://github.com/CollectorCtrl/CollectorCtrl-K8s-Operator): Deployments, DaemonSets and StatefulSets deployed by your own Helm charts or GitOps appear next to host collectors. You keep your existing charts, repositories and pipelines.
- **One inventory:** switch between All, Host collectors and Kubernetes workloads, with cluster and namespace filters.
- **Workload detail:** observed ConfigMap references, configuration hashes, optional configuration content (opt-in), pod instances with their lifecycle, and source and ownership information.
- **Freshness:** stale or disconnected observations are shown as historical, not current.
- **Instrumentation readiness** (**Instrumentation → Kubernetes**): OpenTelemetry coverage per cluster, the APM agent each application workload runs (OpenTelemetry or another vendor, detected read-only), one next step per workload, and the auto-instrumentation rollout state reported by the Kubernetes operator. Readiness needs operator 0.8.0, rollout state 0.9 and the `OTEL_*` settings table 0.9.1.
- **Safe by design:** observed workloads are read-only. Host policies, canaries, upgrades, taps and host-only actions skip them, and Copilot and MCP answers distinguish them from managed hosts.
- The observer enrolls with its own credential. Pilot limits: no Secret-backed configs, native OpenTelemetry Operator resources or OpenShift DeploymentConfigs yet, and live-cluster validation on managed Kubernetes platforms is still in progress.

## Configuration and policies

- **Fleet policies** target collectors with Kubernetes-style label selectors (`matchLabels`, `matchExpressions`), including the `collectorctrl.environment` and `collectorctrl.role` classification attributes.
- **Versioned configurations:** every change is SHA-256 hashed and versioned, with full policy history.
- **Canary rollouts:** deploy to a share of the matching collectors first, then **Promote** or **Abort**. A canary can be promoted only once every canary collector is connected, has received the policy and runs its current version; forcing a promotion is recorded in the audit log. A collector reports a configuration as applied only after it has restarted with it and passed a health check. Canaries survive server restarts, and aborting never releases the new config to the rest of the fleet.
- **Rollouts and approvals:** **Rollouts** lists rollouts in priority order, with a page per rollout for promote, resume and abort. Copilot and MCP proposals wait under **Rollouts → Approvals**.
- **Rollback** restores the complete saved policy and records it as a new version.
- **Safe editing:** optimistic concurrency means a save is refused instead of overwriting a colleague's newer change.
- **Durable saves:** a save reports success only once it's stored. The UI shows separately whether the change was delivered and whether the collector confirmed it.
- **Per-collector overrides** and **configuration history** with side-by-side or unified diffs, compare-any-two, search by author or SHA, and one-click restore.

## Drift prevention and configuration integrity

- Every supervisor reports its effective configuration hash. The server compares it with the governed configuration and shows each collector as in sync, reconciling or drifted.
- Per policy, drift is either **reported** or **automatically reverted**.
- **Validate before apply:** the Supervisor checks every new config with the collector itself. A config the collector rejects never replaces the running one, and the push is marked failed with the collector's own error message.
- **Crash-loop rollback:** if a config passes validation but makes the collector crash repeatedly, the Supervisor returns to the last known good config and reports the failure. A configuration becomes last known good only after five minutes of health (`agent.stable_window`), and three unexpected exits within ten minutes revert it.
- **Pushed configuration survives a restart:** the Supervisor saves the last remote configuration and restores it at start, so a restart while the server is unreachable keeps it.

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
- Sidecar status in the fleet views, with **Has sidecar** and **Sidecar issues** filters.

## Supervisor and collector lifecycle

- **Signed package repository** for supervisor, collector and sidecar packages.
- **Catalog → Packages:** search, filters for type, OS and trust (Release-signed / Signed / Unsigned), and a table that shows the signer, signing date and SHA-256. Deleting a package asks for confirmation; it does not check whether collectors or rollouts still use the package.
- **Supervisor upgrades** accept only the vendor release signature, so even a compromised server can't push a new supervisor.
- **Collector and sidecar upgrades** accept a release signature or an explicit **Sign** approval in the UI, recorded in the audit log.
- **Canary supervisor upgrades:** an upgrade of two or more supervisors goes to a small cohort first (10%, at least one, one per operating system). The rest wait until every canary reports the new version and has stayed connected for 2 minutes. A canary that fails, falls back or stays disconnected halts the queue, and **Settings → Supervisors** says why. The queue advances on the server but is kept in memory: after a server restart during a rollout, start the upgrade again.
- **Fleet-wide upgrade governance:** upgrades are throttled and queued, and a bulk upgrade halts automatically if too many fail. A new supervisor that can't reconnect within its watchdog window rolls itself back to the previous version. Collector upgrades are verified after install and rolled back on failure. A collector you stopped on purpose stays stopped after an upgrade.

## Custom Builder

- Build tailored collector binaries with the OpenTelemetry Collector Builder (`ocb`) under **Catalog → Custom builds**, choosing only the components you need. Builds can target an OS or architecture other than the server's own.
- The server needs Go 1.25 or newer (or the `server-ocb` image target) and access to a Go module proxy. One build runs at a time, can be cancelled, and times out after 60 minutes (`COLLECTORCTRL_OCB_TIMEOUT`).
- Each build has a name, description and tags. **Build History** lists every build with who started it, platform, OCB version, components, log and manifest.
- The page warns when a component is on a different release line than the builder.
- Built packages land in the package repository, where you sign them and roll them out like any other collector.

## AI Copilot

- A chat assistant **inside the control plane** that answers from **live fleet data** using read-only tools (fleet health, configs, history, policies, audit, Governor analytics), with web search optional.
- **Streams** its answer and each tool step as it works. Supports slash commands, `@`-mentions of collectors, policies and pipelines, syntax-highlighted YAML, and a dockable panel. Open it from the config editor with a collector's configuration attached.
- **Proposes, never applies:** a change comes as a proposal with a diff and blast radius, with a unified diff against the current configuration, which a person approves under **Rollouts → Approvals**. The Copilot can't approve its own proposals.
- **Bring your own model:** OpenAI, Anthropic, Google Gemini, or any **OpenAI-compatible endpoint**, including self-hosted and enterprise-approved models. Optional PII redaction.
- Every Copilot tool call is audit-logged and rate-limited, and the MCP kill switch stops the Copilot too.

Details: [AI Copilot and MCP](ai-copilot-and-mcp.md).

## MCP server

- A built-in **Model Context Protocol** endpoint (`/api/mcp`), plus a stdio adapter (`collectorctrl-mcp`) for Claude Desktop, Cursor and other MCP clients.
- **60+ tools:** fleet, configs, policies and canaries, GitOps, templates, history, upgrades, Governance (including pattern ranking and rule optimization), discovery, instrumentation, Kubernetes readiness, sidecars and notifications. Also **7 runbook prompts**: triage an unhealthy collector, standardize config drift, make a safe fleet change, troubleshoot a sidecar, optimize telemetry volume, inspect a Kubernetes workload, plan Kubernetes OpenTelemetry adoption.
- **Governed:** API-token authentication, per-tool RBAC, an audit entry per call (`mcp:<user>`), human approval for every change, blast-radius caps, 15-minute proposal expiry, and optional four-eyes approval.

## Installation and enrollment

- **Administrator password at install time:** the Windows and Linux server installers ask for the administrator password or generate one. There is no well-known default in an installer or production-mode install. The bundled PostgreSQL gets a generated password.
- **Enrollment built into the supervisor installers:** they take the enrollment token and the server's CA certificate, and the Windows setup program confirms that the server accepted the host.
- **Takeover of an existing collector:** the Linux, Windows and macOS supervisor installers find a collector that runs as its own service, stop and disable it, and start it under the Supervisor with the same binary and configuration. The macOS takeover has not been run on a Mac yet.
- **Windows MSI** of the supervisor for SCCM, Intune and Group Policy, with the setup program's options as properties.
- **Machine images:** install without starting the service, or remove an identity with `-reset-identity`, so each machine created from the image enrolls as itself.
- **Labels at install time**, reported as collector attributes. A `deployment.environment` label is the collector's environment, and classification rules can match any label.
- **Running without root (Linux, opt-in):** the supervisor and its collector run as an unprivileged user in a systemd sandbox. Some features need root and stop working in this mode.
- **Air-gapped sites:** the server's package mirror serves the supervisor packages, and can be filled by upload.
- **Release signatures at install time:** the server keeps a mirrored supervisor package only if its release signature verifies, and the one-line install commands compare the package with that signature. Other install methods do not check.

Details: [Connecting collectors](agent-onboarding.md) and [Enterprise deployment scenarios](enterprise-deployment.md).

## Governance

Governance is the Telemetry Governor in the web console, with the tabs **Sources**, **Insights**, **Destinations** and **Configuration**. It is shown to users with the Governor view permission.

- **Telemetry taps** on running collectors sample logs and traces without blocking or slowing the primary pipeline. Traces are sampled by trace ID, so a sampled trace stays complete. Logs without a trace ID are sampled per record on OpenTelemetry Collector Contrib 0.88 and newer.
- **One global sampling rate** (default 10%), set under **Governance → Configuration**, applies to every tapped collector and every external source, so Insights compares like with like. Changing it asks for confirmation and re-configures every tapped collector. There are no per-collector rates.
- **External sources report their rate.** The configuration generated for an external source uses the global rate. **Sources** shows each source's rate and flags one that differs or has not reported one. The server cannot change a configuration you deployed: copy the current one from the source's Details to bring it in line.
- **Insights** ranks recurring log patterns and span routes by the records received, with plain-language findings, charts, and a searchable pattern table with CSV export. It shows measured counts only, never projected volumes or savings, and shows a notice when the global rate changed inside the selected range or sources in scope report different rates.
- **Bounded queries:** a pattern or overview query reads at most the newest 100,000 records in scope (`COLLECTORCTRL_GOVERNOR_QUERY_SCAN_LIMIT`) and says when the range holds more. Identical queries within 30 seconds are answered from memory.
- **Log Pattern / Span Route Optimizer:** turns a noisy pattern into a filter, sampling, tail-sampling or normalization rule, previews its measured impact, checks it, and rolls it out through a policy. A policy that adds or changes an optimizer drop, sample or trace filter rule must be rolled out as a canary unless it is saved with `force`. Warnings and errors are never suggested for dropping. An optional AI review adds advisory notes.
- **Destinations:** fan out to S3 (partitioned, Athena-ready) or OTLP endpoints, with connectivity tests.
- **Ingest limits and metrics:** concurrent uploads, payload size, a daily quota and retention (7 days by default) are bounded and configurable; a saturated server answers `429` with `Retry-After`. Ingest and forwarding counters are exported at `/metrics` as `collectorctrl_governor_*` gauges. See [Configuration](configuration.md#governance).
- **Limits:** Governance has not been load-tested. Samples are stored one row per record in the server's database, and no capacity figure for large fleets is published yet.

## Instrumentation (alpha)

**Instrumentation** in the side menu is ZeroTouch instrumentation, with the tabs Applications, Agent versions and Kubernetes.


- **Application discovery** on managed hosts: runtime, framework and version of running applications. Off by default and controlled per host, with every toggle audited.
- **Enable or remove** OpenTelemetry agents for **Java, .NET, Node.js and Python** from the UI, with an optional canary cohort. Services (Windows services, IIS app pools, systemd units) are marked "restart required" and pick up instrumentation on their next restart. A standalone process also picks the change up on its next restart; an immediate restart needs an explicit confirmation.
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
- **Notification Center:** a timeline grouped by day with the clock time of each event, a severity dot, and filters for Critical, Warning, Info and Unread. Back-to-back repeats of one event fold into one row with a count, and opening a row shows the full message and marks it read.
- **By environment:** every notification records its environment. The Notification Center, bell count, **Mark read** and **Clear** follow the selected environment, and each environment keeps its own history. Installation-wide events show as **Fleet-wide**.
- **Alert channels:** email (SMTP), Slack, Microsoft Teams, PagerDuty and webhooks. Each channel can receive all environments or only selected ones, for example Production to PagerDuty and Development to Slack, and every alert includes its environment.
- **Fewer alerts during outages:** when many collectors disconnect or reject a config at once, more than 5 in an environment become one summary alert.
- Events include disconnects, rejected configs, failed or rolled-back upgrades, impersonation attempts, Git sync failures and instrumentation results.

## Operations

- **Single binary** server with an embedded web UI. SQLite or PostgreSQL. Windows service, systemd, launchd or container.
- **TLS by default** with a per-install CA, or bring your own certificates or reverse proxy.
- **One-command backup and restore**, including keys, certificates and state.
- **REST API** with an OpenAPI specification ([docs/api/openapi.json](api/openapi.json)).
- **Health and metrics:** `/api/health` (liveness), `/readyz` (database and OpAMP listener) and `/metrics` in Prometheus format. Logs can be emitted as JSON (`COLLECTORCTRL_LOG_FORMAT=json`).
- **Browser security:** sessions in an HttpOnly cookie with CSRF tokens, security headers including a Content-Security-Policy, and sign-in throttling.
- **Verified onboarding:** the server detects its own address, and the Linux, macOS and Windows **Add collector** commands check the server's CA fingerprint before downloading anything.
- **Signed releases:** every download has a detached Ed25519 signature and an SPDX SBOM. Container images are signed with cosign. The Windows setup programs and MSI are not Authenticode-signed.
