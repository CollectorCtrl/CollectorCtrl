# CollectorCtrl: Security & Compliance

CollectorCtrl is designed with a "Secure by Default" philosophy to meet the requirements of financial and enterprise environments.

## Communication Security

### TLS Encryption
- All communication between the Supervisor and the Management Server occurs over **WSS (Secure WebSockets)**.
- The Web UI and API are served over **HTTPS**.
- Minimum supported TLS version: **1.2** (TLS 1.3 recommended).

### Mutual TLS (mTLS) Support
- CollectorCtrl supports client-certificate-based authentication for agents.
- Each agent can be provisioned with a unique certificate to prevent spoofing.

## Access Control

### Role-Based Access Control (RBAC)
User permissions are strictly enforced at the API level. Standard roles include:
- **Admin**: Full control over the system, users, and all fleets.
- **Operator**: Can manage configurations and control agents but cannot manage users or system settings.
- **Viewer**: Read-only access to the fleet status.

### Authentication
- **JWT (JSON Web Tokens)**: Secure, signed tokens for session management.
- **Bcrypt Hashing**: All user passwords are salted and hashed using Bcrypt before being stored in the database.

## Data Protection & Audit

### Audit Logging
CollectorCtrl maintains an immutable record of all significant actions:
- User login/logout.
- Configuration changes (who, when, what).
- Agent control commands (Restart, Stop, Upgrade).
- User and role modifications.

### Database Security
- Supports standard database security practices for both SQLite and PostgreSQL.
- Sensitive environment variables (passwords, secrets) can be passed to the server via protected environment variables or secrets managers.

## Vulnerability Management
- **Dependency Scanning**: Continuous monitoring of third-party libraries via GitHub Dependency Graph and security advisories.
- **Static Analysis**: Source code is periodically scanned for common Go security pitfalls (e.g., via `gosec`).
- **Reports**: Security and vulnerability reports can be generated for compliance audits upon request.

---
*For specific security inquiries or vulnerability disclosures, please contact the CollectorCtrl security team.*
