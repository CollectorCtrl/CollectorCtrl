# Changelog

A summary of every CollectorCtrl release. Full notes, downloads and signatures for each version are on the [Releases](https://github.com/CollectorCtrl/CollectorCtrl/releases) page. Upgrade guidance is in [docs/upgrading.md](docs/upgrading.md).

⚠️ marks releases with breaking changes.

## 0.8.x: Enterprise installation and Governance

| Version | Date | Highlights |
| :--- | :--- | :--- |
| [v0.8.0-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.8.0-beta) | 2026-11-12 | Supervisor installers take over a collector that already runs as its own service; a supervisor MSI (amd64 and arm64; `.deb` and `.rpm` are not attached to this release), an Ansible role and Packer, cloud-init and Terraform examples; administrator password chosen or generated at install time and generated passwords for the bundled PostgreSQL; enrollment token, server CA (`--ca-file`), labels, machine-image options (`--no-start`, `-reset-identity`) and an optional unprivileged mode (Linux) in the supervisor installers; the server verifies the release signature of every supervisor package it mirrors and the one-line install commands check the package against it; supervisor upgrades start with a canary cohort; redesigned web console with job-based navigation, an Overview page, and rebuilt Notification Center and Catalog → Packages; "Telemetry" is now **Governance**, with **Instrumentation** as its own section; one global Governor sampling rate (default 10%), bounded and cached Insights queries, `collectorctrl_governor_*` metrics. ⚠️ Unattended supervisor installs stop and disable an existing collector service; per-collector sampling rates and the MCP tool `governor_set_sampling` are removed; the package mirror refuses unsigned supervisor packages; supervisor upgrades wait for a canary stage. |

## 0.7.x: Security hardening, scale and Custom Builder

| Version | Date | Highlights |
| :--- | :--- | :--- |
| [v0.7.3-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.7.3-beta) | 2026-11-05 | Custom Builder: cross-platform builds work, the default builder version follows the newest OpenTelemetry release (0.164.0 when offline), component version mismatches are caught before the build, builds run on Windows servers installed as a service; named builds with description and tags, a Build History tab, search and filters for build outputs; cancel, a 60-minute timeout (`COLLECTORCTRL_OCB_TIMEOUT`) and a bounded build log; new `server-ocb` image target. ⚠️ Builds need Go 1.25 or newer on the server (or the `server-ocb` image) and access to a Go module proxy; `/api/packages` returns newest first. |
| [v0.7.1-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.7.1-beta) | 2026-11-03 | Counterpart to Kubernetes operator 0.9: accepts its reports, shows the auto-instrumentation rollout state of every opted-in workload with guided next steps, and lists each container's `OTEL_*` settings; instrumentation readiness moves to ZeroTouch Instrumentation → Kubernetes; observed ConfigMap YAML in the read-only editor; topology draws local exporters per collector. ⚠️ Rollout state needs operator 0.9 and the settings table needs operator 0.9.1; bookmarks to the readiness panel on the Fleet page need updating. |
| [v0.7.0-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.7.0-beta) | 2026-11-01 | Browser sessions in an HttpOnly cookie with CSRF tokens; environment-scoped API tokens enforced on every action; production installs generate a one-time administrator password instead of `admin` / `admin`; security headers and login throttling; a configuration is reported as applied only after the collector restarts with it and passes a health check; crash-loop detection for slow crashes; background package installs with a timeout and size cap; graceful collector stops on Windows; Copilot proposals with a unified diff; exact Governor pattern matching and a canary requirement for optimizer drop rules; Fleet page paging and filtering in the database; `/readyz`, `/metrics` and JSON logs; versioned database migrations. ⚠️ Everyone signs in again once; reverse proxies need `COLLECTORCTRL_TRUST_PROXY_HEADERS=true`; the collector health check listens on `127.0.0.1:13133`; editors lose access to MCP settings; standalone instrumentation no longer restarts processes without confirmation. |

## 0.6.x: Kubernetes fleet visibility

| Version | Date | Highlights |
| :--- | :--- | :--- |
| [v0.6.4-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.6.4-beta) | 2026-10-28 | Instrumentation readiness for Kubernetes: OpenTelemetry coverage per cluster, APM agents from other vendors detected read-only, one next step per workload; MCP tool `k8s_instrumentation_readiness` and prompt `plan_kubernetes_otel_adoption`; collector role, stack and topology in Kubernetes; container images signed with cosign, with an SPDX SBOM and SLSA provenance; signed SBOMs for every binary and installer; versioned image tags; PostgreSQL 15.19 in the Windows PostgreSQL installers. ⚠️ Readiness needs Kubernetes operator 0.8.0; the collector in the supervisor image moves from 0.96.0 to 0.162.0. |
| [v0.6.3-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.6.3-beta) | 2026-10-23 | Environments work the same everywhere: Notification Center filter, environment-scoped API tokens, alert channels routed by environment; one summary alert per environment during outages; canaries promote only when every canary collector is healthy on the new version; automatic server address detection and CA-verified agent onboarding. Environment names are no longer case-sensitive. |
| [v0.6.2-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.6.2-beta) | 2026-10-21 | Telemetry Insights ranks recurring patterns by received records instead of estimating volume; one tap sampling rate for every severity, default 10%; plain-language findings and charts; searchable, filterable pattern table with CSV export. |
| [v0.6.1-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.6.1-beta) | 2026-10-16 | Log Pattern / Span Route Optimizer: AI advisory review sees the complete generated rule, verdict-first layout, Copilot inside the optimizer; 4 new MCP and Copilot optimization tools. |
| [v0.6.0-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.6.0-beta) | 2026-10-09 | **Kubernetes workload observation (pilot):** see collector Deployments, DaemonSets and StatefulSets deployed by your own Helm/GitOps next to host collectors, via the [K8s observer](https://github.com/CollectorCtrl/CollectorCtrl-K8s-Operator); All / Host collectors / Kubernetes workloads views with cluster and namespace filters; pod lifecycle and explicit observation freshness; Kubernetes-aware Copilot and MCP; observed workloads excluded from host policies, canaries, upgrades and host-only actions; inventory scans no longer truncated. ⚠️ Observer now enrolls with an Agent Enrollment token, needs a retained credential volume and one replica; upgrade server and observer together. |

## 0.5.x: GA hardening

| Version | Date | Highlights |
| :--- | :--- | :--- |
| [v0.5.5-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.5.5-beta) | 2026-10-01 | Sidecar status across fleet, honeycomb and topology views; sidecar start/restart fully isolated from the main collector; 32 new MCP tools and 4 runbook prompts (proposal tracking, templates, config history, policies, GitOps); turning discovery off really stops it, with every toggle audited; notifications link to the right page. |
| [v0.5.3-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.5.3-beta) | 2026-09-30 | Streaming Copilot with slash commands and @mentions; classification rules with live preview and collector roles; grant-ceiling RBAC; tamper-evident, searchable, exportable audit trail; per-user notifications and PagerDuty; guided SSO setup with test sign-in; independent main/sidecar lifecycle; **GitOps** with GitHub. ⚠️ Viewer role narrowed; Git webhooks need a secret. |
| [v0.5.2-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.5.2-beta) | 2026-09-29 | Canary rollouts survive restarts, abort never leaks, rollback restores the full policy; durable config saves; **HTTPS by default**, fail-closed TLS; one-command backup and restore; ZeroTouch hardened for production. ⚠️ UI moves to `https://`. |
| [v0.5.1-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.5.1-beta) | 2026-09-28 | **Secure by default:** per-agent enrollment, per-install CA and `wss://`, signed packages, validate-before-apply and crash-loop rollback, configuration history with diffs, four-eyes AI approvals, signed release files. ⚠️ Agents must enroll, supervisors must be reinstalled once, licenses re-issued. |
| [v0.5.0-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.5.0-beta) | 2026-09-23 | Telemetry Governor tap: much lighter, safer and self-healing. |

## 0.4.x: The agentic control plane

| Version | Date | Highlights |
| :--- | :--- | :--- |
| [v0.4.9-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.4.9-beta) | 2026-09-22 | Telemetry Governor Command Center, Copilot audit trail, destination search and filters. |
| [v0.4.7-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.4.7-beta) | 2026-09-16 | Streamlined node onboarding, reliable bootstrap configuration, more resilient server installation. |
| [v0.4.6-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.4.6-beta) | 2026-09-15 | Single-approver workflow, execution feedback for approved actions, separate sidecar logs, more accurate fleet status. |
| [v0.4.4-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.4.4-beta) | 2026-09-10 | Copilot hardening: around 70% fewer tokens per conversation, fleet health summary, log-tail tools, crash fixes. |
| [v0.4.3-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.4.3-beta) | 2026-09-10 | **Introducing the CollectorCtrl Copilot:** an AI assistant inside the control plane that works within your permissions. |
| [v0.4.2-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.4.2-beta) | 2026-09-08 | Per-host ZeroTouch discovery controls, supervisor upgrade hardening, security fixes. |
| [v0.4.0-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.4.0-beta) | 2026-09-07 | Enterprise identity hardening (account lockout, endpoint authorization), safer fleet upgrades. |

## 0.3.x: Fleet scale, packages and governance

| Version | Date | Highlights |
| :--- | :--- | :--- |
| [v0.3.9-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.3.9-beta) | 2026-09-04 | Custom Builder build targets (main or sidecar), package provenance, build hardening. |
| [v0.3.8-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.3.8-beta) | 2026-09-03 | Automatic collector upgrade rollback, strict main/sidecar separation, CPU-architecture-aware packages, Windows install fixes. |
| [v0.3.7-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.3.7-beta) | 2026-09-01 | Fleet configuration templates and drift inspector with side-by-side diffs. |
| [v0.3.6-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.3.6-beta) | 2026-08-31 | Fleet-scale performance (API compression, polling guard, fast filtering), clustered topology view. |
| [v0.3.5-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v.0.3.5-beta) | 2026-08-28 | UI refresh, redesigned topology visualizer, Custom Builder workspace. |
| [v0.3.4-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.3.4-beta) | 2026-08-28 | Agent and SDK setup guides for six runtimes in the APM control plane. |
| [v0.3.3-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.3.3-beta) | 2026-08-27 | Continuous host process discovery, unified cross-platform versioning. |
| [v0.3.2-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.3.2-beta) | 2026-08-25 | Telemetry Governor AI pattern intelligence and edge filter generator. |
| [v0.3.1-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.3.1-beta) | 2026-08-24 | Notification center and outbound alerting. |
| [v0.3.0-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.3.0-beta) | 2026-08-24 | Dynamic environment, cluster and host filters. |

## 0.2.x and earlier

| Version | Date | Highlights |
| :--- | :--- | :--- |
| [v0.2.9-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.2.9-beta) | 2026-08-19 | Pipeline visualizer: multi-stage DAG and per-signal swimlanes, component inspector. |
| [v0.2.8-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.2.8-beta) | 2026-08-18 | APM instrumentation control plane (alpha) and central agent catalog. |
| [v0.2.7-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.2.7-beta) | 2026-08-11 | MCP validation tools, propose/approve workflow, Pending AI Actions panel. |
| [v0.2.6-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.2.6-beta) | 2026-08-10 | **Get Started** onboarding wizard for Linux, Windows, macOS, Kubernetes and Docker. |
| [v0.2.5-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.2.5-beta) | 2026-08-07 | Application discovery, topology view, saved views, S3 improvements. |
| [v0.2.4-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.2.4-beta) | 2026-07-15 | Granular RBAC and feature-based access control. |
| [v0.2.3](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.2.3) | 2026-07-02 | Feature and stability update. |
| [v0.2.2-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.2.2-beta) | 2026-06-16 | Feature and stability update. |
| [v0.2.1-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.2.1-beta) | 2026-06-11 | Telemetry Governor engine and UI. |
| [v0.2.0-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.2.0-beta) | 2026-06-10 | First public beta. |
| [v0.1.0-alpha](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.1.0-alpha) | 2026-05-05 | First alpha. |
