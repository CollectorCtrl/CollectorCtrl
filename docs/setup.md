# Setup & Installation Guide

This guide details the prerequisites, deployment procedures, service configuration, and troubleshooting steps required to install and run the **CollectorCtrl** Management Server and the **Supervisor Agent** in production environments.

---

## Network & Firewalls: Port Allocation

Ensure your network security groups and firewall policies allow traffic on the following ports:

| Port | Type | Direction | Description |
| :--- | :--- | :--- | :--- |
| **4320** | TCP / WSS | Inbound to Server | **OpAMP Gateway**: Core WebSocket control channel for active Supervisors |
| **4321** | TCP / HTTPS | Inbound to Server | **Dashboard Console**: Exposes the Admin UI and REST API |
| **13133** | TCP | Localhost only | **OTel Health Check**: Used by Supervisor to check collector health |
| **5432** | TCP | Outbound from Server | **PostgreSQL Store**: Database server connection (if using Postgres) |

> *Note: The Supervisor Agent connects **outbound** to the Server on port 4320. No inbound ports need to be opened on the agent machines themselves.*

---

## Prerequisites: Target Host Requirements

Before executing the Supervisor installation, prepare the target system:

1. **OTel Collector Binary**: Ensure a pre-compiled OpenTelemetry Collector binary is present on the system.
   - **Windows default path**: `C:\Program Files\otelcol\otelcol.exe`
   - **Linux default path**: `/usr/local/bin/otelcol`
2. **Local Administrator Privileges**: The installer must register background system services/daemons.
3. **Outbound Connectivity**: The host must resolve and reach the Management Server over the network via Port `4320` and Port `4321`.

---

## 1. Management Server Installation

### Windows Installation

1. Download the unified executable installer: `CollectorCtrl_Setup.exe`.
2. Right-click and select **Run as Administrator**.
3. Choose the installation directory (defaults to `C:\Program Files\CollectorCtrl`).
4. Select the Database engine: **SQLite** (standard) or **PostgreSQL** (enter connection DSN).
5. The wizard registers a background Windows Service named `CollectorCtrlServer`.
6. Open your web browser and navigate to `https://localhost:4321` (or the server's static IP/hostname).
7. Authenticate using the default credentials:
   - **Username**: `admin`
   - **Password**: `admin`
   - *⚠️ Change your password immediately after first login.*

### Linux Installation

1. Download the target architecture release package (e.g., `collectorctrl-server_1.1.0_linux_amd64.tar.gz`).
2. Extract the archive:
   ```bash
   tar -xzf collectorctrl-server_1.1.0_linux_amd64.tar.gz
   ```
3. Run the automated installer script as root:
   ```bash
   sudo ./install.sh
   ```
   - **Automated Setup**: The install script automatically detects your package manager (`apt-get` or `yum`/`dnf`), downloads and configures **PostgreSQL**, sets default credentials (`postgres`/`postgres`), provisions the `collectorctrl` database schema, and registers the server as a systemd service (`collectorctrl.service`).
4. Access the web console at `https://YOUR_SERVER_IP:4321`.
5. Authenticate with the default login credentials (`admin` / `admin`).

---

## 2. Supervisor Agent Installation

### A. Windows Installation (Windows Service)

Our Windows installer handles service registration with the local Service Control Manager (SCM).

1. Execute the agent installer: `CollectorCtrl_Supervisor_Setup.exe` as an **Administrator**.
2. **Server Configuration Page**:
   - **OpAMP Server endpoint**: `wss://YOUR_SERVER_IP:4320/v1/opamp`
   - **API Token**: Enter the client registration key (generated in *System Settings > SSO & API Tokens*).
3. **Collector Pathing Page**:
   - **OTel Executable Path**: `C:\Program Files\otelcol\otelcol.exe`
   - **Active Configuration Path**: `C:\Program Files\otelcol\config.yaml` *(The Supervisor writes configurations to this location)*
4. Finish the wizard. The installer writes these values to `C:\Program Files\CollectorCtrl\supervisor.conf` and starts the `CollectorCtrlSupervisor` service.

#### Manual PowerShell Registration (Alternative)

If installing via Configuration Management (Ansible, SCCM, Group Policy), you can register the service manually:

```powershell
# Create the service entry pointing to the supervisor binary and configuration file
New-Service -Name "CollectorCtrlSupervisor" `
            -BinaryPathName '"C:\Program Files\CollectorCtrl\CollectorCtrlSupervisor.exe" -config "C:\Program Files\CollectorCtrl\supervisor.conf"' `
            -DisplayName "CollectorCtrl Supervisor" `
            -StartupType Automatic

# Start the service
Start-Service -Name "CollectorCtrlSupervisor"
```

---

### B. Linux Installation (systemd Daemon)

For Linux systems, the agent configuration is defined in a standard YAML file, and process isolation is handled via systemd.

1. Create the system configuration directory and copy the binary:
   ```bash
   sudo mkdir -p /etc/collectorctrl /var/log/collectorctrl
   sudo cp ./collectorctrl-supervisor /usr/local/bin/
   sudo chmod +x /usr/local/bin/collectorctrl-supervisor
   ```

2. Create the configuration file `/etc/collectorctrl/supervisor.yaml`:
   ```yaml
   server:
     endpoint: "wss://YOUR_SERVER_IP:4320/v1/opamp"
     token: "your_secret_api_token"
     tls:
       insecure_skip_verify: false
       ca_file: "/etc/collectorctrl/certs/ca.pem"
   collector:
     path: "/usr/local/bin/otelcol"
     config_path: "/etc/otelcol/config.yaml"
     reload_mechanism: "sighup"
   ```

3. Create the systemd unit file `/etc/systemd/system/collectorctrl-supervisor.service`:
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

4. Reload systemd, enable, and start the daemon:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now collectorctrl-supervisor.service
   ```

---

## 3. Initial Configuration

1. **Login**: Access the dashboard and authenticate with the default credentials:
   - **Username**: `admin`
   - **Password**: `admin`
   - *⚠️ Change your password immediately after first login.*
2. **Generate an API Token**: Navigate to *System Settings > SSO & API Tokens* and generate a **Client Registration Key** for your Supervisor agents.
3. **Verify Fleet**: Navigate to the **Agents** page. Your newly installed Supervisor should appear in the fleet list.
4. **Deploy Config**: Use the **Configuration Editor** to push your first OTel pipeline to the agent.

---

## Dynamic Configuration Trigger Mechanics

When an administrator edits a configuration in the UI console and publishes the policy update, the following hot-reload flow occurs:

1. **Validation Check**: The server compiles the final YAML (resolving targets and merge rules) and executes a dry-run check.
2. **File Writing**: The Supervisor receives the YAML payload over the OpAMP channel and writes it to the designated `config_path`.
3. **Triggering the Reload**:
   - **Linux Hosts**: The Supervisor sends a `SIGHUP` signal directly to the OTel Collector process ID, prompting it to hot-reload without tearing down sockets.
   - **Windows Hosts**: If the OTel Collector binary doesn't support SIGHUP, the Supervisor calls the collector's local administration API reload hook:
     `POST http://localhost:13133/schema/reload`
     If the reload endpoint fails or is disabled, the Supervisor executes a fast process restart (`StopProcess` then `StartProcess`) within 150 milliseconds.

---

## Log Directories & Troubleshooting Reference

When debugging pipeline problems, refer to the following log locations:

### 🏢 On Windows Server

| Log | Path |
| :--- | :--- |
| Server Application Logs | `C:\ProgramData\CollectorCtrl\logs\server.log` |
| Supervisor Service Logs | `C:\ProgramData\CollectorCtrl\logs\supervisor.log` |
| OTel Collector Observations | `C:\ProgramData\CollectorCtrl\logs\otelcol-observations.log` |

### 🐧 On Linux Hosts

| Log | Path / Command |
| :--- | :--- |
| Supervisor Logs | `/var/log/collectorctrl/supervisor.log` or `journalctl -u collectorctrl-supervisor -n 100 --no-pager` |
| OTel Collector Observations | `/var/log/collectorctrl/otelcol-observations.log` |

---

*For advanced troubleshooting, refer to the [Architecture Guide](architecture.md) or visit [collectorctrl.com/docs](https://collectorctrl.com/docs) for the full documentation suite.*
