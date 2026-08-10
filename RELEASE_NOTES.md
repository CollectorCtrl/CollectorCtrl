# CollectorCtrl 1.1.x Release Notes

CollectorCtrl 1.1.x is the current stable release line of the cross-platform OpenTelemetry fleet control plane. This document summarizes the current state of the platform — including the latest installer and protocol-default changes — and consolidates the major capabilities delivered since the early betas.

---

## Latest Updates (1.1.x)

### 🌐 Unified HTTP-First Defaults (Windows & Linux)

The default protocol behavior is now consistent across platforms, removing the most common first-run friction:

- **Web Console**: Served over plain **HTTP** at `http://localhost:4321` (or `http://<server-ip>:4321`). Browsers that auto-upgrade to `https://` will fail to connect — use `http://`.
- **OpAMP Endpoint**: Supervisors connect over **`ws://<server-ip>:4320/v1/opamp`** by default. `wss://` is used when TLS is configured.
- **Production TLS**: HTTPS can be enabled via a reverse proxy (IIS / Nginx / Caddy, recommended) or natively with the `COLLECTORCTRL_UI_HTTPS`, `COLLECTORCTRL_UI_ADDR`, `COLLECTORCTRL_UI_CERT`, and `COLLECTORCTRL_UI_KEY` environment variables. See the [Setup Guide](docs/setup.md#4-production-https).

### 🪟 Windows Installer Improvements

- The interactive `.exe` setup wizard registers and starts the **`CollectorCtrl`** Windows Service automatically.
- Two editions: **Standard (SQLite)** and **PostgreSQL** — the PostgreSQL wizard collects host, port, user, and password during setup.
- On completion, the installer launches the Web Console in your default browser at `http://localhost:4321`.

### 🐧 Linux Installer Improvements

- A **single-command automated installer** (`sudo ./install.sh`) for Ubuntu, Debian, RHEL, CentOS, and Amazon Linux 2023:
  - Detects the package manager (`apt-get` / `yum` / `dnf`).
  - Installs PostgreSQL (PostgreSQL edition), creates the `collectorctrl` database and user, and auto-configures `pg_hba.conf` for local authentication (`scram-sha-256`).
  - Writes the database connection string into the systemd unit and installs the service at `/etc/systemd/system/collectorctrl.service`.
- **Interactive Supervisor installer**: prompts for the Management Server endpoint (default `ws://localhost:4320/v1/opamp`), writes `supervisor.yaml`, and registers the `collectorctrl-supervisor` systemd service.

### 🐳 Docker Distribution

Official server images are published to GitHub Container Registry:

```bash
docker run -d \
  --name collectorctrl \
  --restart always \
  -p 4320:4320 \
  -p 4321:4321 \
  -v collectorctrl-data:/opt/collectorctrl \
  ghcr.io/collectorctrl/collectorctrl-server:latest
```

---

## Platform Capabilities (Cumulative)

- **Fleet Management**: Centralized, real-time overview of all connected OpAMP agents across Windows, Linux, and Kubernetes.
- **Remote Configuration**: Policy-driven configuration with Kubernetes-style label selectors, SHA-versioned snapshots, canary rollouts, and one-click rollback.
- **Drift Prevention**: The server continuously compares each agent's reported effective configuration against the governed policy. A configurable **DriftPolicy** (`alert_only` or `auto_remediate`) flags or automatically corrects any divergence.
- **Remote Supervisor Upgrades**: Fleet-wide Supervisor self-upgrade orchestration with self-healing rollback protection.
- **PostgreSQL Enterprise Store**: Dual-storage engine — SQLite for development, PostgreSQL for production (10,000+ concurrent agents) with zero-downtime auto-migrations.
- **OIDC Single Sign-On**: Microsoft Entra ID (Azure AD), Okta, Auth0 — with JIT provisioning and group-to-role mapping (Admin, Editor, Viewer, and custom RBAC roles).
- **SIEM OTLP Audit Streaming**: Every administrator action streamed in real time as structured OTLP log events to Splunk, Elastic, Datadog, or any OTLP-compatible backend.
- **Kubernetes Fleet Management**: Manage collectors running in Kubernetes clusters (Helm charts provided).

---

## Port Allocations & Network Requirements

| Port | Protocol | Direction | Component / Purpose |
| :--- | :--- | :--- | :--- |
| **4320** | TCP / WS (WSS with TLS) | Inbound to Server | **OpAMP Gateway** (control plane communications) |
| **4321** | TCP / HTTP (HTTPS with TLS) | Inbound to Server | **Dashboard Console** & REST API |
| **13133** | TCP | Localhost only | **OTel Health Check** (local agent monitoring) |
| **5432** | TCP | Localhost / Outbound | **PostgreSQL Store** (database connection) |

> Supervisors connect **outbound** to the server on port 4320 — no inbound ports are required on agent machines.

---

## Upgrade Guide

### Upgrading the Server

1. Stop the active service:
   - **Windows**: `Stop-Service -Name "CollectorCtrl"`
   - **Linux**: `sudo systemctl stop collectorctrl`
2. Apply the new executable or extraction package.
3. Start the service — database auto-migrations apply automatically:
   - **Windows**: `Start-Service -Name "CollectorCtrl"`
   - **Linux**: `sudo systemctl start collectorctrl`

### Upgrading the Supervisor Agent

Supervisor upgrades can be pushed **remotely from the Admin UI** (Package Management → Fleet Upgrade), with automatic rollback on failure.

For manual upgrades on client nodes:

```powershell
# Windows (Admin PowerShell)
New-Service -Name "CollectorCtrlSupervisor" `
            -BinaryPathName '"C:\Program Files\CollectorCtrl Supervisor\supervisor.exe" --config "C:\Program Files\CollectorCtrl Supervisor\supervisor.yaml"' `
            -DisplayName "CollectorCtrl Supervisor" `
            -StartupType Automatic
Start-Service -Name "CollectorCtrlSupervisor"
```

```bash
# Linux
sudo systemctl restart collectorctrl-supervisor
```

---

## Looking Ahead

- Expanded package management and custom collector builder capabilities.
- Deeper Kubernetes operator integration.
- Continued hardening toward the next production milestone.

---
*© 2026 CollectorCtrl. All rights reserved. For issues or questions, contact us at connect@collectorctrl.com.*
