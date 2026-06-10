# CollectorCtrl Beta v0.2.0 Release Notes

We are thrilled to announce the release of **CollectorCtrl Beta v0.2.0**, the next major milestone in our journey toward definitive OpenTelemetry fleet control and governance.

This release transitions CollectorCtrl from a Windows-centric preview into a robust, cross-platform, enterprise-ready control plane. Version 0.2.0 introduces Linux support, PostgreSQL compatibility for enterprise-scale deployments, OpenID Connect (OIDC) Single Sign-On, real-time SIEM audit streaming, and the new agent-side Drift Guardian.

---

## What's New in Beta v0.2.0

### 🐧 1. Linux Support (Server & Agent)
CollectorCtrl is now fully cross-platform. We have expanded our management capabilities and background services to support enterprise Linux distributions.
- **Server Deployment**: Extract and run with our automated `install.sh` script, which configures PostgreSQL dependencies, database schemas, and systemd services.
- **Supervisor systemd Daemon**: Register the Supervisor Agent as a systemd service (`collectorctrl-supervisor.service`) with standard process recovery options.
- **Hot-Reload Mechanics**: On Linux, the Supervisor triggers configuration updates using the POSIX `SIGHUP` signal to reload the OTel Collector process in place with zero downtime.

### 🐘 2. PostgreSQL Enterprise Store
To support massive scale, we have added a dual-storage database layer.
- **SQLite** remains the default for local development, fast testing, and single-instance proofs-of-concept.
- **PostgreSQL** is now supported as a production-grade database store. The schema features zero-downtime auto-migrations and scales to manage **10,000+ concurrent agents** across multi-region networks.

### 🔐 3. OIDC Identity & Single Sign-On (SSO)
Secure access to the Admin UI using your existing identity provider (IdP).
- **Federated Authentication**: Direct integration with Azure AD, Okta, and Auth0 via the OpenID Connect (OIDC) protocol.
- **Just-in-Time (JIT) Provisioning**: User profiles are dynamically created upon successful identity provider login.
- **Dynamic Group Mappings**: Automatically assign roles (`Admin`, `Operator`, or `Viewer`) based on directory group memberships.

### 📊 4. SIEM OTLP Audit Streaming
Maintain compliance easily with our native, real-time audit logging engine.
- **OTLP Event Streaming**: Every administrator action, user login/logout, configuration update, and API token generation is emitted in real time as structured OTLP log events.
- **Native SIEM Integration**: Forward audit trails directly to Splunk, Elastic, Datadog, or any OTLP-compatible security backend.
- **Compliance Ready**: Helps satisfy audit log requirements for SOC 2 Type II and other regulatory frameworks.

### 🛡️ 5. Local Drift Guardian & Integrity
Keep your collection edge clean of configuration sprawl and unauthorized alterations.
- **Local Drift Guardian**: The Supervisor Agent runs an active on-disk file checksum watcher.
- **Self-Healing Configs**: Any unauthorized manual edits to the managed `config.yaml` file on an agent node are instantly overwritten by the Supervisor with the server's authorized snapshot.
- **Visual Sync Status**: Track sync states (`In sync`, `Reconciling`, or `Drifted`) in real time from the central Admin UI.

---

## Port Allocations & Network Requirements

| Port | Protocol | Direction | Component / Purpose |
| :--- | :--- | :--- | :--- |
| **4320** | TCP / WSS | Inbound to Server | **OpAMP Gateway** (Control plane communications) |
| **4321** | TCP / HTTPS | Inbound to Server | **Dashboard Console** & REST API |
| **13133** | TCP | Localhost only | **OTel Health Check** (Local agent monitoring) |
| **5432** | TCP | Outbound from Server | **PostgreSQL Store** (Database connection) |

---

## Upgrade & Installation Guide

### Upgrading the Server
1. Stop the active service:
   - **Windows**: `Stop-Service -Name "CollectorCtrlServer"`
   - **Linux**: `sudo systemctl stop collectorctrl.service`
2. Apply the new executable or extraction package.
3. Start the service. Auto-migrations will apply database updates automatically:
   - **Windows**: `Start-Service -Name "CollectorCtrlServer"`
   - **Linux**: `sudo systemctl start collectorctrl.service`

### Upgrading the Supervisor Agent
1. Replace the supervisor binary on client nodes.
2. For Windows, you can optionally perform manual service registration using the new PowerShell script:
   ```powershell
   New-Service -Name "CollectorCtrlSupervisor" `
               -BinaryPathName '"C:\Program Files\CollectorCtrl\CollectorCtrlSupervisor.exe" -config "C:\Program Files\CollectorCtrl\supervisor.conf"' `
               -DisplayName "CollectorCtrl Supervisor" `
               -StartupType Automatic
   Start-Service -Name "CollectorCtrlSupervisor"
   ```
3. For Linux, verify that your `/etc/collectorctrl/supervisor.yaml` matches the new configuration schema, then restart the daemon:
   ```bash
   sudo systemctl restart collectorctrl-supervisor.service
   ```

---

## Looking Ahead
This beta release brings us one step closer to our production-ready **v1.0 release scheduled for Q4 2026**. Upcoming highlights include:
- Granular custom RBAC permissions definition.
- Native Kubernetes Operator integration.
- Expanded package management and custom collector builders.

---
*© 2026 CollectorCtrl. All rights reserved. For issues or questions, contact us at connect@collectorctrl.com.*
