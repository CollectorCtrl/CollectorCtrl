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

Download from the [latest release](https://github.com/CollectorCtrl/CollectorCtrl/releases). Replace `<version>` below with the release version, for example `0.8.0-beta`.

| Platform | Server | Supervisor (for managed hosts) |
| :--- | :--- | :--- |
| Windows | `collectorctrl-server_<version>_windows_<arch>.exe`: installer, SQLite edition<br>`collectorctrl-server-postgres_<version>_windows_<arch>.exe`: installer, PostgreSQL edition | `collectorctrl-supervisor-setup_<version>_windows_<arch>.exe`: setup program<br>`collectorctrl-supervisor_<version>_windows_<arch>.msi`: MSI for deployment tools<br>`collectorctrl-supervisor_<version>_windows_<arch>.exe`: binary only, for upgrades pushed by the server |
| Linux | `collectorctrl-server_<version>_linux_<arch>.tar.gz`<br>`collectorctrl-server-postgres_<version>_linux_<arch>.tar.gz` | `collectorctrl-supervisor_<version>_linux_<arch>.tar.gz` |
| macOS | `collectorctrl-server_<version>_darwin_<arch>.tar.gz`<br>`collectorctrl-server-postgres_<version>_darwin_<arch>.tar.gz` | `collectorctrl-supervisor_<version>_darwin_<arch>.tar.gz` |

`<arch>` is `amd64` or `arm64`. Each file has a `.sig` next to it: [verify it](verifying-downloads.md) before installing. The Windows setup programs and the MSI are not Authenticode-signed. The v0.8.0-beta release notes describe supervisor `.deb` and `.rpm` packages, but the v0.8.0-beta release page does not list any.

> You rarely need to download the Supervisor by hand. **Add collector** in the UI generates a command that fetches and installs it for you.

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

In our load tests (August 2026) the server used under 135 MB of memory with 1,000 connected collectors on both SQLite and PostgreSQL. Larger fleets are not benchmarked yet, and Governance (the Telemetry Governor) has not been load-tested: its samples are stored one row per record in the server's database. Run a **single server instance**: multi-replica high availability isn't supported yet.

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

- Image: `ghcr.io/collectorctrl/collectorctrl-server`. Since v0.6.4-beta, releases publish versioned tags such as `0.6.4-beta`, and `latest` moves only on releases. The images are signed with cosign and carry an SPDX SBOM.
- This command does not set production mode or an administrator password, so the first sign-in is `admin` / `admin` with a forced password change. See [First sign-in](#first-sign-in).
- The standard image has no Go toolchain, so it cannot run Custom builds.
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
- The server runs in production mode. Add `COLLECTORCTRL_ADMIN_PASSWORD` to the server's environment before the first start, or read the one-time administrator password from `docker compose logs` after it.
- PostgreSQL is reachable only from the server container. It isn't published on the host.
- Back up **both** volumes: `collectorctrl_data` (CA, keys, secrets) and `postgres_data` (database). Keep `.env` in your secret manager: the secrets in it aren't stored anywhere else.

## Windows

Windows Server or Windows 10/11, on amd64 or arm64.

1. Download one of the server installers:
   - `collectorctrl-server_<version>_windows_<arch>.exe`: **SQLite edition**, no external database.
   - `collectorctrl-server-postgres_<version>_windows_<arch>.exe`: **PostgreSQL edition**. It installs the bundled PostgreSQL locally, or connects to an existing PostgreSQL database that you name (host, user, password, database, SSL mode). For the bundled instance the superuser password is generated and saved in `C:\ProgramData\CollectorCtrl\postgres-superuser-password.txt` (Administrators and SYSTEM only), and a reinstall reuses that instance. Setup refuses to touch a PostgreSQL it did not install.
2. Run it as Administrator. On a first install, the **Administrator Account** page asks for the password of the `admin` account. For a silent install pass `/ADMIN_PASSWORD=`. An upgrade keeps the existing accounts.
3. Setup installs to `C:\Program Files\CollectorCtrl`, registers and starts the **CollectorCtrl** Windows service, confirms that the service is running before it reports success, writes a setup log, and offers to open the console at `https://localhost:4321`.
4. Restrict the data directory, which holds private keys and secrets, to SYSTEM and Administrators:

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

The installer copies the server and web assets to `/opt/collectorctrl-server`, installs the **`collectorctrl`** systemd service, and starts it.

On a first install it sets the password of the `admin` account. It takes the password from `--admin-password-file FILE` (the first line of the file) or `COLLECTORCTRL_ADMIN_PASSWORD`, asks for it on a terminal, or otherwise generates one and prints it once at the end. Upgrades keep the existing accounts.

The installer in the `-postgres` archive also installs PostgreSQL with your package manager and creates a `collectorctrl` role, with a generated password, that owns the `collectorctrl` database. It does not alter the `postgres` superuser. A database connection you configured yourself is kept.

```bash
sudo systemctl status collectorctrl
sudo journalctl -u collectorctrl -f
```

### Recommended: production settings

The service unit reads optional settings from `/etc/collectorctrl/server.env`. Keep that file readable by root only:

```bash
sudo mkdir -p /etc/collectorctrl /var/lib/collectorctrl
sudo tee -a /etc/collectorctrl/server.env >/dev/null <<EOF
COLLECTORCTRL_MODE=production
COLLECTORCTRL_DATA_DIR=/var/lib/collectorctrl
COLLECTORCTRL_JWT_SECRET=$(openssl rand -hex 32)
COLLECTORCTRL_ENCRYPTION_KEY=$(openssl rand -hex 32)
# PostgreSQL instead of SQLite:
# COLLECTORCTRL_DB_TYPE=postgres
# COLLECTORCTRL_DB_DSN=host=localhost port=5432 user=collectorctrl password=... dbname=collectorctrl sslmode=require
EOF
sudo chmod 600 /etc/collectorctrl/server.env

sudo systemctl restart collectorctrl
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

The server runs in Kubernetes as a **single replica** with a persistent volume mounted at `/var/lib/collectorctrl`, the container image above, ports 4320 and 4321, and HTTPS probes on `/api/health` (liveness) and `/readyz` (readiness). Run it with `COLLECTORCTRL_MODE=production`: the first administrator password is then generated and printed once in the server log, unless you set `COLLECTORCTRL_ADMIN_PASSWORD`. Don't scale beyond one replica: running two active servers against one database is not supported.

Collectors that run in Kubernetes can be **observed** (pilot, since v0.6.0) with the [CollectorCtrl Kubernetes observer](https://github.com/CollectorCtrl/CollectorCtrl-K8s-Operator). It shows collector Deployments, DaemonSets and StatefulSets deployed by your own Helm charts or GitOps next to host collectors. Changes to those workloads stay with your deployment system.

The observer enrolls like a supervisor:

1. Create an enrollment token under **Settings → Tokens**, store it in a Secret in the observer's namespace under `enrollment-token`, and reference it with `opamp.enrollmentSecret`.
2. Give it persistent credential storage (the chart creates a retained PVC, or set `credentialStorage.existingClaim`) and keep that storage across upgrades.
3. Run **one** observer replica.
4. Set the server's WSS endpoint with `opamp.server`, and `opampCAConfigMap` if the server uses a private CA.

Installations that still use the shared secret need `OPAMP_LEGACY_MODE=true` only until they move to enrollment. See [Security](security.md#agent-identity) and [Upgrading](upgrading.md#changes-to-check-in-06x).

---

## First sign-in

1. Open `https://<server>:4321`. Your browser warns about the certificate until you trust the server's CA. You can download it from `https://<server>:4321/api/onboard/ca.pem`; its SHA-256 fingerprint is printed in the server's start-up log.
2. Sign in as **`admin`**. The password depends on how the server was installed:

   | Install | First password |
   | :--- | :--- |
   | Windows or Linux installer | The one you chose during installation, or the generated one the installer showed once. |
   | `COLLECTORCTRL_ADMIN_PASSWORD` set at the first start | That value. |
   | Production mode (`COLLECTORCTRL_MODE=production`) without it: Compose example, Kubernetes | A one-time password printed once in the server log. It must be changed at first sign-in. |
   | Anything else, such as the evaluation `docker run` or a binary started by hand | `admin`. It must be changed at first sign-in, and until then the account can do nothing else. Don't expose the server to a network in this state. |

3. Click **Add collector**, create an enrollment token, and [connect your first collector](agent-onboarding.md).
4. Recommended next steps: configure [SSO](security.md#single-sign-on), create roles, set up [backups](upgrading.md#backup-and-restore), and connect the [Copilot](ai-copilot-and-mcp.md) to your model provider.

---

## Troubleshooting

| Symptom | What to check |
| :--- | :--- |
| Browser can't connect | Use **`https://`**, not `http://`. The UI is HTTPS by default. |
| Server won't start: certificate / TLS error | The server refuses to start rather than fall back to plain HTTP. Check `COLLECTORCTRL_UI_CERT` / `COLLECTORCTRL_UI_KEY`, or that the data directory is writable so the server can create its CA. |
| Server won't start in production mode | Set `COLLECTORCTRL_JWT_SECRET` and `COLLECTORCTRL_ENCRYPTION_KEY`. `COLLECTORCTRL_UI_TLS=plain` is refused on non-loopback addresses. |
| Agents locked out after a container restart | The data volume wasn't persisted, so a new CA was created. Mount `/var/lib/collectorctrl` and re-enroll. |
| Supervisor log shows `401 Unauthorized` | The supervisor was installed without an enrollment token. Run the installer again with a token from **Add collector**. |
| Agent doesn't appear in Fleet | Port 4320 reachable from the host? Agent enrolled with a valid, unexpired token? Check **Notifications** for rejected or impersonation events. |

Logs:

| Platform | Server | Supervisor |
| :--- | :--- | :--- |
| Docker | `docker logs collectorctrl` | — |
| Linux | `journalctl -u collectorctrl` | `journalctl -u collectorctrl-supervisor` |
| Windows | Run `C:\Program Files\CollectorCtrl\server.exe` from an elevated prompt to see start-up errors | `supervisor.log` in the Supervisor's installation folder; installer steps in `C:\ProgramData\CollectorCtrlSupervisor\setup.log` (MSI) |
