# Security Policy

## Supported Versions

We provide security updates for the following versions of CollectorCtrl:

| Version | Supported          |
| ------- | ------------------ |
| 1.1.x   | :white_check_mark: |
| < 1.1   | :x:                |

## Reporting a Vulnerability

We take the security of CollectorCtrl seriously. If you believe you have found a security vulnerability, please report it to us privately.

**Please do not report security vulnerabilities through public GitHub issues, discussions, or pull requests.**

Instead, contact the CollectorCtrl security team at [connect@collectorctrl.com](mailto:connect@collectorctrl.com) with the subject line **"Security Vulnerability Report"**.

### What to include

- A description of the vulnerability and its potential impact.
- Steps to reproduce or a proof-of-concept (if available).
- Affected version(s) and deployment environment (Windows/Linux/Docker).

### What to expect

- We will acknowledge receipt of your report within **48 hours**.
- We will provide an estimated timeframe for a fix and keep you informed of progress.
- We will notify you once the vulnerability is patched and coordinate disclosure timing with you.

## Security Practices

CollectorCtrl undergoes automated security scanning, including:

- **SAST:** GitHub CodeQL & `gosec` static analysis
- **SCA:** Dependency monitoring via GitHub Dependency Graph and security advisories
- **Integrity:** OpenSSF Scorecard

For details on CollectorCtrl's security architecture (TLS, mTLS, RBAC, audit streaming), see [Security & Compliance](docs/security.md).
