# Changelog

A summary of every CollectorCtrl release. Full notes, downloads and signatures for each version are on the [Releases](https://github.com/CollectorCtrl/CollectorCtrl/releases) page. Upgrade guidance is in [docs/upgrading.md](docs/upgrading.md).

⚠️ marks releases with breaking changes.

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
