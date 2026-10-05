# Installation

This guide installs the **CollectorCtrl Server**. To connect hosts afterwards, see [Connecting collectors](agent-onboarding.md).

- [Before you start](#before-you-start)
- [Docker](#docker)
- [Docker Compose with PostgreSQL](#docker-compose-with-postgresql)
- [Windows](#windows)
- [Linux](#linux)
- [macOS](#macos)
- [Kubernetes](#kubernetes)
- [First sign-in](#first-sign-in)
- [Troubleshooting](#troubleshooting)

---

## Before you start

### Release files

Download from the [latest release](https://github.com/CollectorCtrl/CollectorCtrl/releases). Replace `<version>` below with the release version, for example `0.5.5-beta`.

| Platform | Server | Supervisor (for managed hosts) |
| :--- | :--- | :--- |
| Windows | `collectorctrl-server_<version>_windows_<arch>.exe`: installer, SQLite edition<br>`collectorctrl-server-postgres_<version>_windows_<arch>.exe`: installer, PostgreSQL edition | `collectorctrl-supervisor-setup_<version>_windows_<arch>.exe`: installer<br>`collectorctrl-supervisor_<version>_windows_<arch>.exe`: binary only |
| Linux | `collectorctrl-server_<version>_linux_<arch>.tar.gz`<br>`collectorctrl-server-postgres_<version>_linux_<arch>.tar.gz` | `collectorctrl-supervisor_<version>_linux_<arch>.tar.gz` |
| macOS | `collectorctrl-server_<version>_darwin_<arch>.tar.gz`<br>`collectorctrl-server-postgres_<version>_darwin_<arch>.tar.gz` | `collectorctrl-supervisor_<version>_darwin_<arch>.tar.gz` |

`<arch>` is `amd64` or `arm64`. Each file has a `.sig` next to it: [verify it](verifying-downloads.md) before installing.

> You rarely need to download the Supervisor by hand. The **Get Started** page in the UI generates a command that fetches and installs it for you.

### Ports

| Port | Direction | Purpose |
| :--- | :--- | :--- |
| **4320/tcp** | Inbound to the server | OpAMP gateway. Supervisors connect here over **WSS** (TLS). |
| **4321/tcp** | Inbound to the server | Web UI, REST API, MCP endpoint, onboarding scripts and package downloads, over **HTTPS**. Supervisors also download packages from this port. |
| 5432/tcp | Server to PostgreSQL | Only with the PostgreSQL edition. |

Supervisors only make **outbound** connections. No inbound ports are needed on managed hosts.

### Sizing

| Fleet | CPU | Memory | Database |
| :--- | :--- | :--- | :--- |
| Evaluation, up to ~250 collectors | 2 vCPU | 2–4 GB | SQLite |
| Up to 1,000 collectors | 4 vCPU | 4–8 GB | SQLite or PostgreSQL |

In our load tests (August 2026) the server used under 135 MB of memory with 1,000 connected collectors on both SQLite and PostgreSQL. Larger fleets are not benchmarked yet. Run a **single server instance**: multi-replica high availability isn't supported yet.

### Where the server keeps its state

On first start the server creates a **certificate authority**, a server certificate, an encryption key, a session-signing secret, an OpAMP secret and a package-signing key in its **data directory**. Agents trust that CA. **Back it up and keep it persistent:** if it's lost, every agent has to be re-enrolled.

| Install type | Data directory |
| :--- | :--- |
| Docker image | `/var/lib/collectorctrl` (declare it as a volume) |
| Windows | `%PROGRAMDATA%\CollectorCtrl` |
| Linux / macOS archive | The server's working directory (`/opt/collectorctrl-server` with the bundled systemd unit), unless you set `COLLECTORCTRL_DATA_DIR` |

Set `COLLECTORCTRL_DATA_DIR` to put it somewhere specific. See [Configuration](configuration.md#data-directory).

---

## Docker

```bash
docker run -d --name collectorctrl --restart unless-stopped \
  -p 4320:4320 -p 4321:4321 \
  -v collectorctrl-data:/var/lib/collectorctrl \
  -v collectorctrl-logs:/var/log/collectorctrl \
  ghcr.io/collectorctrl/collectorctrl-server:latest
```

- Image: `ghcr.io/collectorctrl/collectorctrl-server`. `latest` tracks the newest build; immutable `main-<commit>` tags are also published.
- Runs as a non-root user (UID 1000).
- The database (SQLite), CA, secrets, uploaded packages and agent assets live under `/var/lib/collectorctrl`. **Do not mount a volume over `/opt/collectorctrl`**: that hides the application binaries.
- Logs: `docker logs -f collectorctrl`.

For anything beyond a quick evaluation, run in production mode with your own secrets (next section).

## Docker Compose with PostgreSQL

[`examples/docker-compose.yml`](../examples/docker-compose.yml) runs the server in production mode with PostgreSQL.

```bash
curl -fsSLO https://raw.githubusercontent.com/CollectorCtrl/CollectorCtrl/main/examples/docker-compose.yml

cat > .env <<EOF
COLLECTORCTRL_JWT_SECRET=$(openssl rand -hex 32)
COLLECTORCTRL_ENCRYPTION_KEY=$(openssl rand -hex 32)
POSTGRES_PASSWORD=$(openssl rand -hex 24)
EOF
chmod 600 .env

docker compose up -d
```

- `docker compose up` refuses to start while any of the three secrets is missing.
- PostgreSQL is reachable only from the server container. It isn't published on the host.
- Back up **both** volumes: `collectorctrl_data` (CA, keys, secrets) and `postgres_data` (database). Keep `.env` in your secret manager: the secrets in it aren't stored anywhere else.

## Windows

Windows Server or Windows 10/11, on amd64 or arm64.

1. Download one of the server installers:
   - `collectorctrl-server_<version>_windows_<arch>.exe`: **SQLite edition**, no external database.
   - `collectorctrl-server-postgres_<version>_windows_<arch>.exe`: **PostgreSQL edition**. The installer asks for the PostgreSQL host, port, user and password.
2. Run it as Administrator. It installs to `C:\Program Files\CollectorCtrl`, registers and starts the **CollectorCtrl** Windows service, and offers to open the console at `https://localhost:4321`.
3. Restrict the data directory, which holds private keys and secrets, to SYSTEM and Administrators:

   ```powershell
   icacls "$env:ProgramData\CollectorCtrl" /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F"
   ```

Manage the service from PowerShell (as Administrator):

```powershell
Get-Service CollectorCtrl
Restart-Service CollectorCtrl
```

To set environment variables (for example a TLS mode or your own certificate) for the service, write them to its registry `Environment` value and restart it. Upgrades keep this value.

```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CollectorCtrl" -Name Environment -Type MultiString `
  -Value "COLLECTORCTRL_UI_CERT=C:\ProgramData\CollectorCtrl\certs\server.crt","COLLECTORCTRL_UI_KEY=C:\ProgramData\CollectorCtrl\certs\server.key"
Restart-Service CollectorCtrl
```

## Linux

Any systemd-based distribution on amd64 or arm64. The PostgreSQL edition's installer supports `apt` (Ubuntu, Debian) and `yum`/`dnf` (RHEL family, Amazon Linux 2023).

```bash
tar -xzf collectorctrl-server_<version>_linux_amd64.tar.gz
sudo ./install.sh
```

The installer copies the server and web assets to `/opt/collectorctrl-server`, installs the **`collectorctrl`** systemd service, and starts it. The installer in the `-postgres` archive also installs PostgreSQL with your package manager and creates the `collectorctrl` database and user.

```bash
sudo systemctl status collectorctrl
sudo journalctl -u collectorctrl -f
```

### Recommended: production settings

Keep settings in an environment file that only root and the service can read:

```bash
sudo mkdir -p /etc/collectorctrl /var/lib/collectorctrl
sudo tee /etc/collectorctrl/server.env >/dev/null <<EOF
COLLECTORCTRL_MODE=production
COLLECTORCTRL_DATA_DIR=/var/lib/collectorctrl
COLLECTORCTRL_JWT_SECRET=$(openssl rand -hex 32)
COLLECTORCTRL_ENCRYPTION_KEY=$(openssl rand -hex 32)
# PostgreSQL instead of SQLite:
# COLLECTORCTRL_DB_TYPE=postgres
# COLLECTORCTRL_DB_DSN=host=localhost port=5432 user=collectorctrl password=... dbname=collectorctrl sslmode=require
EOF
sudo chmod 600 /etc/collectorctrl/server.env

sudo systemctl edit collectorctrl
#   [Service]
#   EnvironmentFile=/etc/collectorctrl/server.env

sudo systemctl daemon-reload && sudo systemctl restart collectorctrl
```

In production mode the server refuses to start without `COLLECTORCTRL_JWT_SECRET` and `COLLECTORCTRL_ENCRYPTION_KEY`, and refuses plaintext listeners on non-loopback addresses. All settings: [Configuration reference](configuration.md).

Open the firewall:

```bash
sudo ufw allow 4320/tcp && sudo ufw allow 4321/tcp                    # Ubuntu / Debian
sudo firewall-cmd --permanent --add-port={4320,4321}/tcp && sudo firewall-cmd --reload   # RHEL family
```

## macOS

Intel (amd64) or Apple silicon (arm64). macOS is best suited to evaluation and development.

```bash
mkdir collectorctrl-server && cd collectorctrl-server
tar -xzf ../collectorctrl-server_<version>_darwin_arm64.tar.gz
./collectorctrl-server
```

The data directory is the directory you start the server from, unless `COLLECTORCTRL_DATA_DIR` is set.

## Kubernetes

The server runs in Kubernetes as a **single replica** with a persistent volume mounted at `/var/lib/collectorctrl`, the container image above, ports 4320 and 4321, and HTTPS health probes on `/api/health`. Don't scale beyond one replica until high availability ships.

Collectors running in Kubernetes are managed through the [CollectorCtrl Kubernetes Operator](https://github.com/CollectorCtrl/CollectorCtrl-K8s-Operator). The operator doesn't support per-agent enrollment yet, so a server that manages Kubernetes collectors needs `OPAMP_LEGACY_MODE=true` (shared-secret authentication). See [Security](security.md#agent-identity).

---

## First sign-in

1. Open `https://<server>:4321`. Your browser warns about the certificate until you trust the server's CA. You can download it from `https://<server>:4321/api/onboard/ca.pem`; its SHA-256 fingerprint is printed in the server's start-up log.
2. Sign in as **`admin` / `admin`** and choose a new password when prompted. To set the initial password instead, start the server for the first time with `COLLECTORCTRL_ADMIN_PASSWORD`.
3. Go to **Get Started**, create an enrollment token, and [connect your first collector](agent-onboarding.md).
4. Recommended next steps: configure [SSO](security.md#single-sign-on), create roles, set up [backups](upgrading.md#backup-and-restore), and connect the [Copilot](ai-copilot-and-mcp.md) to your model provider.

---

## Troubleshooting

| Symptom | What to check |
| :--- | :--- |
| Browser can't connect | Use **`https://`**, not `http://`. The UI is HTTPS by default. |
| Server won't start: certificate / TLS error | The server refuses to start rather than fall back to plain HTTP. Check `COLLECTORCTRL_UI_CERT` / `COLLECTORCTRL_UI_KEY`, or that the data directory is writable so the server can create its CA. |
| Server won't start in production mode | Set `COLLECTORCTRL_JWT_SECRET` and `COLLECTORCTRL_ENCRYPTION_KEY`. `COLLECTORCTRL_UI_TLS=plain` is refused on non-loopback addresses. |
| Agents locked out after a container restart | The data volume wasn't persisted, so a new CA was created. Mount `/var/lib/collectorctrl` and re-enroll. |
| Agent doesn't appear in Fleet | Port 4320 reachable from the host? Agent enrolled with a valid, unexpired token? Check **Notifications** for rejected or impersonation events. |

Logs:

| Platform | Server | Supervisor |
| :--- | :--- | :--- |
| Docker | `docker logs collectorctrl` | — |
| Linux | `journalctl -u collectorctrl` | `journalctl -u collectorctrl-supervisor` |
| Windows | Run `C:\Program Files\CollectorCtrl\server.exe` from an elevated prompt to see start-up errors | `%PROGRAMDATA%\CollectorCtrlSupervisor\supervisor.log` |
