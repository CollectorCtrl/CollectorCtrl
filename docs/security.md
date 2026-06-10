# CollectorCtrl: Security & Compliance

CollectorCtrl is designed with a **"Secure by Default"** philosophy to meet the requirements of financial, enterprise, and regulated environments.

---

## Communication Security

### TLS Encryption

- All communication between Supervisor agents and the Management Server occurs over **WSS (Secure WebSockets)**.
- The Admin UI Console and REST API are served over **HTTPS**.
- Minimum supported TLS version: **TLS 1.2** (TLS 1.3 strongly recommended for production).

### Mutual TLS (mTLS) Support

- CollectorCtrl supports **client-certificate-based authentication** for Supervisor agents.
- Each agent can be provisioned with a unique certificate to prevent impersonation and spoofing.
- Certificate configuration is managed via the `tls.ca_file` field in `supervisor.yaml` (Linux) or the Server Configuration page of the Windows installer.

---

## Identity & Access Control

### OIDC Identity & SSO

CollectorCtrl integrates with enterprise identity providers using the **OpenID Connect (OIDC)** protocol:

- **Supported Providers**: Azure AD, Okta, Auth0, and any OIDC-compliant identity provider.
- **Just-in-Time (JIT) Provisioning**: User accounts are created automatically upon first login — no manual user creation required.
- **Group-to-Role Mapping**: Directory groups are dynamically mapped to CollectorCtrl roles, ensuring access stays synchronized with your identity provider.

### Role-Based Access Control (RBAC)

User permissions are strictly enforced at the API level. Standard roles include:

| Role | Permissions |
| :--- | :--- |
| **Admin** | Full control — manage system settings, users, roles, and all fleet configurations |
| **Operator** | Manage configurations and control agents; cannot manage users or system settings |
| **Viewer** | Read-only access to fleet status, configuration history, and audit logs |

Custom roles with granular permission sets are available in the System Settings.

### Authentication

- **JWT (JSON Web Tokens)**: Secure, signed tokens for session management. Tokens are short-lived and automatically rotated.
- **API Tokens**: Long-lived machine tokens for Supervisor agent registration and programmatic API access (managed in *System Settings > SSO & API Tokens*).
- **Bcrypt Hashing**: All local user passwords are salted and hashed using Bcrypt before storage.

---

## Data Protection & Audit

### SIEM OTLP Audit Streaming

Every administrator action and data mutation is streamed in real time as **structured OTLP log events** directly into your SIEM — no custom integrations or log scrapers required.

CollectorCtrl maintains an immutable audit record of all significant platform events:
- User login/logout events.
- Configuration changes — who made the change, when, and what the diff was.
- Agent control commands (Restart, Stop, Upgrade).
- User and role modifications.
- API token issuance and revocation.

Compatible SIEM destinations: **Splunk**, **Elastic**, **Datadog**, and any OTLP-compatible endpoint. Designed for **SOC 2** compliance audit requirements.

### Database Security

- Supports standard database security practices for both **SQLite** and **PostgreSQL**.
- Sensitive environment variables (passwords, secrets, API tokens) should be passed to the server via protected environment variables or dedicated secrets managers (e.g., HashiCorp Vault, AWS Secrets Manager).
- For PostgreSQL: configure row-level security, connection pooling (e.g., PgBouncer), and SSL connections at the database level.

### Drift Guardian — Configuration Integrity

The Supervisor's **Local Drift Guardian** provides tamper-resistance at the edge:
- Continuously watches on-disk configuration file integrity via checksum comparison.
- Any manual edits to the managed `config.yaml` on the agent node are **instantly overwritten** with the server's authorized configuration snapshot.
- This ensures that agent nodes cannot independently diverge from the centrally-governed policy — even with direct OS-level access.

---

## Vulnerability Management

- **Dependency Scanning**: Continuous monitoring of third-party Go and Node.js libraries via GitHub Dependency Graph and security advisories.
- **Static Analysis**: Source code is periodically scanned for common Go security pitfalls using `gosec` and standard linting pipelines.
- **Responsible Disclosure**: Security and vulnerability reports can be submitted to the CollectorCtrl security team. Please **do not** report security vulnerabilities via public GitHub Issues.

---

*For specific security inquiries, enterprise compliance requirements, or vulnerability disclosures, please contact the CollectorCtrl security team at [connect@collectorctrl.com](mailto:connect@collectorctrl.com).*
