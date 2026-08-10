# Setup & Installation Guide

This guide details the prerequisites, deployment procedures, service configuration, and troubleshooting steps required to install and run the **CollectorCtrl** Management Server and the **Supervisor Agent** in production environments.

---

## Network & Firewalls: Port Allocation

Ensure your network security groups and firewall policies allow traffic on the following ports:

| Port | Type | Direction | Description |
| :--- | :--- | :--- | :--- |
| **4320** | TCP / WS (WSS with TLS) | Inbound to Server | **OpAMP Gateway**: WebSocket control channel for active Supervisors |
| **4321** | TCP / HTTP (HTTPS with TLS) | Inbound to Server | **Dashboard Console**: Exposes the Admin UI and REST API |
| **13133** | TCP | Localhost only | **OTel Health Check**: Used by Supervisor to check collector health |
| **5432** | TCP | Localhost / Outbound | **PostgreSQL Store**: Database connection (if using Postgres) |

> *Note: The Supervisor Agent connects **outbound** to the Server on port 4320. No inbound ports need to be opened on the agent machines themselves.*

> ⚠️ **HTTP by default**: The console is served over plain **HTTP** (`http://<server>:4321`) and agents connect over **`ws://`** unless TLS is configured. See [Production HTTPS](#4-production-https) before exposing the UI to a network.

---

## Prerequisites: Target Host Requirements

Before executing the Supervisor installation, prepare the target system:

1. **OTel Collector Binary**: Ensure a pre-compiled OpenTelemetry Collector binary is present on the system.
   - **Windows default path**: `C:\Program Files\otelcol\otelcol.exe`
   - **Linux default path**: `/usr/local/bin/otelcol`
2. **Local Administrator Privileges**: The installer must register background system services/daemons.
3. **Outbound Connectivity**: The host must resolve and reach the Management Server over the network via Port `4320`.

---

## 1. Management Server Installation

### Option A: Docker (fastest evaluation)

```bash
docker run -d \
  --name collectorctrl \
  --restart always \
  -p 4320:4320 \
  -p 4321:4321 \
  -v collectorctrl-data:/opt/collectorctrl \
  ghcr.io/collectorctrl/collectorctrl-server:latest
```

Open 👉 **`http://localhost:4321`** and log in with `admin` / `admin`.

### Option B: Windows Installation

1. Download the installer from the [releases page](https://github.com/CollectorCtrl/CollectorCtrl/releases):
   - **Standard Edition (SQLite)**: `CollectorCtrl_Setup.exe`
   - **PostgreSQL Edition**: `CollectorCtrl-PostgreSQL-Setup.exe`
2. Right-click and select **Run as Administrator**.
3. Choose the installation directory (defaults to `C:\Program Files\CollectorCtrl`).
4. **PostgreSQL Edition only**: enter your PostgreSQL host (`127.0.0.1`), port (`5432`), user, and password.
5. Finish the wizard and leave **"Launch CollectorCtrl Web Console"** checked — the installer registers and starts the **`CollectorCtrl`** Windows Service, then opens your browser at **`http://localhost:4321`**.
6. Authenticate using the default credentials:
   - **Username**: `admin`
   - **Password**: `admin`
   - *⚠️ Change your password immediately after first login.*

Manage the service with `services.msc` or PowerShell (as Administrator):

```powershell
Get-Service CollectorCtrl
Restart-Service CollectorCtrl
Stop-Service CollectorCtrl
```

### Option C: Linux Installation (systemd)

Supported: Ubuntu 18.04+, Debian 10+, RHEL 8+, CentOS 8+, Amazon Linux 2023.

1. Download and extract the release package for your architecture (`amd64` or `arm64`):
   ```bash
   tar -xzf collectorctrl-server-postgres_1.1.x_linux_amd64.tar.gz
   cd collectorctrl-server_linux_amd64
   ```
2. Run the automated installer:
   ```bash
   sudo ./install.sh
   ```
   The script automatically:
   - Detects your package manager (`apt-get` or `yum`/`dnf`)
   - Installs PostgreSQL (PostgreSQL edition) and creates the `collectorctrl` database and user
   - Auto-configures `pg_hba.conf` for local authentication (`scram-sha-256`)
   - Writes the connection string into the systemd unit at `/etc/systemd/system/collectorctrl.service`
   - Installs to `/opt/collectorctrl-server` and starts the server on port `4321`
3. Verify the service:
   ```bash
   sudo systemctl status collectorctrl
   sudo journalctl -u collectorctrl -f
   ```
4. Access the web console at **`http://YOUR_SERVER_IP:4321`** and log in with `admin` / `admin` *(⚠️ change the password immediately)*.

---

## 2. Supervisor Agent Installation

### A. Windows Installation (Windows Service)

The Windows installer handles service registration with the local Service Control Manager (SCM).

1. Run `CollectorCtrl_Supervisor_Setup.exe` as an **Administrator**.
2. **Server Connection Page**:
   - **Server OpAMP Endpoint**: `ws://YOUR_SERVER_IP:4320/v1/opamp` (use `wss://` when TLS is configured)
   - **API Token**: Enter the client registration key (generated in *Settings → API Tokens*).
3. **Collector Configuration Page**:
   - **OTel Executable Path**: `C:\Program Files\otelcol\otelcol.exe`
   - **Initial Config (optional)**: Select an initial YAML config if you have one
4. Finish the wizard. The installer writes `supervisor.yaml` to `C:\Program Files\CollectorCtrl Supervisor\` and starts the `CollectorCtrlSupervisor` service.

#### Manual PowerShell Registration (Alternative)

If installing via Configuration Management (Ansible, SCCM, Group Policy):

```powershell
# Create the service entry pointing to the supervisor binary and configuration file
New-Service -Name "CollectorCtrlSupervisor" `
            -BinaryPathName '"C:\Program Files\CollectorCtrl Supervisor\supervisor.exe" --config "C:\Program Files\CollectorCtrl Supervisor\supervisor.yaml"' `
            -DisplayName "CollectorCtrl Supervisor" `
            -StartupType Automatic

# Start the service
Start-Service -Name "CollectorCtrlSupervisor"
```

---

### B. Linux Installation (systemd Daemon)

1. Extract the supervisor package and run the interactive installer:
   ```bash
   tar -xzf collectorctrl-supervisor_1.1.x_linux_amd64.tar.gz
   cd collectorctrl-supervisor_linux_amd64
   sudo ./install.sh
   ```
2. When prompted, enter your Management Server's OpAMP endpoint:
   ```text
   Management Server Endpoint [ws://localhost:4320/v1/opamp]: ws://YOUR_SERVER_IP:4320/v1/opamp
   ```
   The installer writes `supervisor.yaml`, registers the `collectorctrl-supervisor` systemd service, and starts it.
3. Verify:
   ```bash
   sudo systemctl status collectorctrl-supervisor
   ```

#### Manual Configuration (Reference)

The configuration file `/etc/collectorctrl/supervisor.yaml`:

```yaml
server:
  endpoint: 'ws://YOUR_SERVER_IP:4320/v1/opamp'
  token: 'your_secret_api_token'
  tls:
    insecure_skip_verify: true

capabilities:
  reports_effective_config: true
  reports_own_metrics: true
  reports_own_logs: true
  reports_own_traces: true
  reports_health: true
  accepts_remote_config: true
  reports_remote_config: true
  accepts_restart_command: true
  accepts_packages: true

agent:
  executable: '/usr/local/bin/otelcol'
  passthrough_logs: true
  config_files:
    - '/etc/otelcol/config.yaml'

storage:
  directory: '/var/lib/collectorctrl/storage'

telemetry:
  logs:
    level: info
    output_paths:
      - '/var/log/collectorctrl/supervisor.log'
```

> **Note:** Use `wss://` instead of `ws://` when your server terminates TLS for OpAMP, and set `tls.ca_file` to your CA certificate (e.g., `/etc/collectorctrl/certs/ca.pem`) with `insecure_skip_verify: false`.

The systemd unit `/etc/systemd/system/collectorctrl-supervisor.service`:

```ini
[Unit]
Description=CollectorCtrl Supervisor Agent
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/collectorctrl-supervisor --config /etc/collectorctrl/supervisor.yaml
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now collectorctrl-supervisor
```

---

## 3. Initial Configuration

1. **Login**: Access the dashboard and authenticate with the default credentials:
   - **Username**: `admin`
   - **Password**: `admin`
   - *⚠️ Change your password immediately after first login.*
2. **Generate an API Token**: Navigate to **Settings → API Tokens** and generate a registration key for your Supervisor agents.
3. **Verify Fleet**: Open the **Fleet Overview**. Your newly installed Supervisor should appear within 30 seconds.
4. **Deploy Config**: Create a Fleet Policy to push your first OTel pipeline to the agent.

---

## 4. Production HTTPS

By default, CollectorCtrl listens on `http://localhost:4321`. For production HTTPS you have two options:

### Option A: Reverse Proxy (Recommended)

Terminate TLS on port 443 using **IIS**, **Nginx**, or **Caddy**, and forward traffic to `http://localhost:4321`. Example Nginx block:

```nginx
server {
    listen 443 ssl;
    server_name collectorctrl.company.com;

    ssl_certificate     /etc/letsencrypt/live/collectorctrl.company.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/collectorctrl.company.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:4321;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Option B: Native TLS

Set the following environment variables on the CollectorCtrl service:

| Variable | Purpose | Example |
| :--- | :--- | :--- |
| `COLLECTORCTRL_UI_HTTPS` | Enable native HTTPS | `true` |
| `COLLECTORCTRL_UI_ADDR` | Bind address | `0.0.0.0:443` |
| `COLLECTORCTRL_UI_CERT` | Certificate file path | `C:\ProgramData\CollectorCtrl\certs\server.crt` or `/etc/collectorctrl/certs/server.crt` |
| `COLLECTORCTRL_UI_KEY` | Private key file path | `...\server.key` |

**Windows** (registry, then restart the service):

```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CollectorCtrl" -Name Environment -Value "COLLECTORCTRL_UI_HTTPS=true","COLLECTORCTRL_UI_ADDR=0.0.0.0:443","COLLECTORCTRL_UI_CERT=C:\ProgramData\CollectorCtrl\certs\server.crt","COLLECTORCTRL_UI_KEY=C:\ProgramData\CollectorCtrl\certs\server.key" -Type MultiString
Restart-Service CollectorCtrl
```

**Linux** (systemd override):

```bash
sudo systemctl edit collectorctrl
# Add:
# [Service]
# Environment="COLLECTORCTRL_UI_HTTPS=true"
# Environment="COLLECTORCTRL_UI_ADDR=0.0.0.0:443"
# Environment="COLLECTORCTRL_UI_CERT=/etc/collectorctrl/certs/server.crt"
# Environment="COLLECTORCTRL_UI_KEY=/etc/collectorctrl/certs/server.key"
sudo systemctl daemon-reload
sudo systemctl restart collectorctrl
```

---

## Dynamic Configuration Apply Mechanics

When an administrator edits a configuration in the UI console and publishes the policy update, the following apply flow occurs:

1. **Validation Check**: The server compiles the final YAML (resolving targets and merge rules) and executes a validation pass.
2. **OpAMP Delivery**: The Supervisor receives the YAML payload over the OpAMP channel, merges it with any local configuration sources, and writes the effective config to disk.
3. **Fast Supervised Restart**: When the effective configuration changes, the Supervisor signals and performs a fast restart of the collector process — with built-in self-healing that detects crash loops and automatically falls back to a known-good state.
4. **Confirmation**: The Supervisor reports the applied configuration hash back to the server via OpAMP, closing the reconciliation loop.

---

## Log Directories & Troubleshooting Reference

### 🏢 On Windows Server

| Log | Path |
| :--- | :--- |
| Server Application Logs | `C:\ProgramData\CollectorCtrl\logs\server.log` |
| Supervisor Service Logs | `C:\ProgramData\CollectorCtrlSupervisor\supervisor.log` |
| OTel Collector Observations | `C:\ProgramData\CollectorCtrl\logs\otelcol-observations.log` |

### 🐧 On Linux Hosts

| Log | Path / Command |
| :--- | :--- |
| Server Logs | `journalctl -u collectorctrl -f` |
| Supervisor Logs | `/var/log/collectorctrl/supervisor.log` or `journalctl -u collectorctrl-supervisor -n 100 --no-pager` |
| OTel Collector Observations | `/var/log/collectorctrl/otelcol-observations.log` |

### Common Issues

| Problem | Solution |
| :--- | :--- |
| Browser fails via `https://` | The console is plain HTTP by default — use `http://<server>:4321`, or enable TLS (see above) |
| Agent not appearing | Verify the endpoint is `ws://<server>:4320/v1/opamp` and port 4320 is reachable |
| TLS errors | If using self-signed certs, set `insecure_skip_verify: true` in `supervisor.yaml` |
| Config not applying | Ensure the `otelcol` binary path in `supervisor.yaml` is correct |

---

*For advanced troubleshooting, refer to the [Architecture Guide](architecture.md) or visit [collectorctrl.com/docs](https://collectorctrl.com/docs) for the full documentation suite.*
