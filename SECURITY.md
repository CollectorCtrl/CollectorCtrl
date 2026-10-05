# Security policy

## Supported versions

CollectorCtrl is in public beta. Security fixes are made in the **latest release** only, so please stay on the newest version.

| Version | Supported |
| :--- | :--- |
| Latest 0.5.x beta (currently v0.5.5-beta) | ✅ |
| Earlier 0.5.x betas | ⚠️ Upgrade to the latest release |
| 0.4.x and earlier | ❌ |

Releases before v0.5.1-beta lack per-agent enrollment, per-install TLS and package signing. If you run one, upgrade: see [docs/upgrading.md](docs/upgrading.md).

## Reporting a vulnerability

**Please don't report security vulnerabilities in public GitHub issues, discussions or pull requests.**

Report them privately by email to [connect@collectorctrl.com](mailto:connect@collectorctrl.com) with the subject **"Security Vulnerability Report"**.

Please include:

- a description of the issue and its potential impact;
- steps to reproduce or a proof of concept;
- the affected version(s) and deployment (Windows, Linux, macOS, Docker, Kubernetes; SQLite or PostgreSQL).

What happens next:

- We acknowledge your report within **48 hours**.
- We confirm the issue, agree on a timeline for a fix, and keep you informed.
- We credit you in the release notes when the fix ships, unless you'd rather we didn't.

## Verifying releases

Every release file has a detached Ed25519 signature. See [docs/verifying-downloads.md](docs/verifying-downloads.md).

## Security design

Agent enrollment, TLS, RBAC, SSO, AI guardrails, package signing and the audit trail are described in [docs/security.md](docs/security.md).
