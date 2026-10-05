# Upgrading, backup and restore

- [Before every upgrade](#before-every-upgrade)
- [Upgrading the server](#upgrading-the-server)
- [Upgrading supervisors and collectors](#upgrading-supervisors-and-collectors)
- [Upgrading from 0.5.0 or earlier](#upgrading-from-050-or-earlier)
- [Changes to check in 0.5.2 – 0.5.5](#changes-to-check-in-052--055)
- [Backup and restore](#backup-and-restore)

CollectorCtrl is in public beta, and betas can contain breaking changes. Read the [release notes](../RELEASE_NOTES.md) for every version you skip.

---

## Before every upgrade

1. Take a backup (see [below](#backup-and-restore)).
2. Read the release notes between your version and the target version.
3. Upgrade the **server first**, then the supervisors. Unless the notes say otherwise, a newer server works with the previous supervisor release.

## Upgrading the server

Database migrations run automatically at start-up.

| Install | Steps |
| :--- | :--- |
| **Docker** | `docker pull ghcr.io/collectorctrl/collectorctrl-server:latest`, then recreate the container with the **same** `/var/lib/collectorctrl` volume. |
| **Compose** | `docker compose pull && docker compose up -d` |
| **Windows** | Run the new installer over the existing installation. It keeps the data directory and the service's `Environment` registry value. |
| **Linux** | `sudo systemctl stop collectorctrl`, extract the new archive, run `sudo ./install.sh`. The service restarts on the new version. |

## Upgrading supervisors and collectors

- **Supervisors:** upload the new supervisor package together with its `.sig` under **Settings → Supervisor Lifecycle Management → Package Repository**, then roll it out from the UI. Upgrades are throttled and queued, a bulk upgrade halts if too many fail, and a supervisor that can't reconnect after upgrading rolls itself back. Supervisors accept **only release-signed** supervisor packages.
- **Collectors and sidecars:** upload the package on **Packages**, click **Sign** (after checking the SHA-256 against the vendor's published checksum), and roll it out through a policy or per collector. A collector you stopped on purpose stays stopped after an upgrade.
- **Re-running the Get Started command** on a host also upgrades its supervisor in place.

> **Supervisors from 0.5.2 or earlier:** release signing keys changed in 0.5.2 and again in 0.5.3, so those supervisors can't verify newer supervisor packages. Upgrade them **once by hand** by re-running the Get Started command on each host. Remote supervisor upgrades work again from there on. Collector package upgrades are not affected.

## Upgrading from 0.5.0 or earlier

v0.5.1 made a default install secure and contains **breaking changes**. For an evaluation install, a clean reinstall is the simplest route. For an install with connected agents:

1. **Back up** the database and the data directory.
2. Start the upgraded server with `OPAMP_LEGACY_MODE=true` for a migration window. If your agents still use the old built-in default secret, also set `OPAMP_SHARED_SECRET` to the secret they actually use.
3. On first start the server creates its CA, server certificate and secrets in the data directory.
4. **Upgrade every supervisor by hand once** by re-running the Get Started command (with a new enrollment token). Upgraded supervisors that connect in legacy mode are migrated to their own per-agent credential automatically.
5. Watch the banner in the UI (“N of M agents have their own credential”). When every agent is enrolled, remove `OPAMP_LEGACY_MODE` and restart the server.
6. **Re-save** the OIDC, SMTP, S3, AI, Git and license settings once, so they're re-encrypted with the new key.
7. **Sign** previously uploaded collector packages on the **Packages** page. Unsigned packages are no longer installed.

What changed:

| Area | Before | Now |
| :--- | :--- | :--- |
| Agent authentication | One fleet-wide shared secret | Per-agent credentials issued at enrollment. The shared secret is accepted only in legacy mode. |
| Transport | `ws://` and HTTP by default, one CA shared by every install | `wss://` and HTTPS by default, with a per-install CA. Agents that trusted the old built-in CA must be re-onboarded. |
| Packages | Installed if the hash matched | Must be signed. Supervisor updates need the release signature; collector packages need a release signature or a **Sign** approval in the UI. |
| Licenses | — | Licenses from earlier builds must be re-issued. |
| AI approvals | MCP clients could confirm actions | Only a signed-in person can approve Copilot or MCP proposals. |
| Sessions | Lost on restart | Survive restarts. Everyone signs in again once after the upgrade. |

## Changes to check in 0.5.2 – 0.5.5

- **HTTPS by default (0.5.2).** Update bookmarks, health checks and scripts from `http://` to `https://`. Supervisors download packages over HTTPS and must trust the server CA; supervisors enrolled with a CA fingerprint already do. Older supervisors: keep `COLLECTORCTRL_UI_HTTPS=false` during the migration window and re-run Get Started on each host.
- **State follows `COLLECTORCTRL_DATA_DIR` (0.5.2).** When it's set, the SQLite database, packages, agent assets and state files live there. Files in the old location keep being used (the log says so) until you stop the server and move them.
- **Docker Compose (0.5.2).** `COLLECTORCTRL_JWT_SECRET`, `COLLECTORCTRL_ENCRYPTION_KEY` and `POSTGRES_PASSWORD` are required. The PostgreSQL user changed from `postgres` to `collectorctrl`: keep your old values if you have data.
- **Kubernetes (0.5.2).** Mount the data volume at `/var/lib/collectorctrl`, serve the UI on 4321, use HTTPS probes, and keep `replicas: 1`.
- **ZeroTouch hardening (0.5.2).** Only `OTEL_*` variables are accepted from callers. Service targets default to "restart required". Auto-reattach is opt-in (`agent.zerotouch_auto_reattach: true`).
- **Roles (0.5.3).** The built-in Viewer no longer includes the user directory or the audit log. Database restore is admin-only. Viewing the OpAMP secret needs the new `system:opamp` permission.
- **SSO (0.5.3).** Existing group-to-role mappings become ordered rules (admin, editor, viewer, then custom roles). Review the order after upgrading.
- **Git integration (0.5.3).** Webhooks now need a secret: set the webhook up again from **Settings → Git Integration**. GitHub and GitHub Enterprise are supported.
- **Sidecar (0.5.3).** Deploy the matching supervisor with the server. The sidecar needs its own executable.
- **API (0.5.5).** `POST /api/governor/supervisors/configure` returns per-instance results and non-200 codes when nothing was applied. Hosts without a sidecar report `SidecarStatusLabel: "Disabled"`. `memory_usage_mb` was removed from discovery reports. Alert rules that matched the old health text "Collectors are not healthy: …" need updating.

The full list is in each release's notes on the [Releases](https://github.com/CollectorCtrl/CollectorCtrl/releases) page.

---

## Backup and restore

A usable backup contains more than the database file. Without the encryption key and CA, a restored server can't decrypt its saved settings, and its agents don't trust it. Use the built-in command. It takes a consistent online snapshot of SQLite and archives the secrets, the TLS PKI and file-based state (packages, agent assets, instrumentation state), with a checksum manifest.

**Back up** (safe while the server is running; use the **same environment** as the service):

```bash
# Linux: load the service's environment file first, if you use one
sudo bash -c 'set -a; [ -f /etc/collectorctrl/server.env ] && . /etc/collectorctrl/server.env; cd /opt/collectorctrl-server && \
  ./collectorctrl-server -backup /backups/cc-$(date +%F-%H%M).tar.gz'
```

```powershell
# Windows (elevated)
& "C:\Program Files\CollectorCtrl\server.exe" -backup "D:\backups\cc-$(Get-Date -Format yyyy-MM-dd-HHmm).tar.gz"
```

```bash
# Docker
docker exec collectorctrl ./collectorctrl-server -backup /tmp/cc-backup.tar.gz
docker cp collectorctrl:/tmp/cc-backup.tar.gz ./cc-$(date +%F).tar.gz
```

- The archive contains private keys and secrets. Store it encrypted and access-controlled.
- Secrets you supplied as environment variables (`COLLECTORCTRL_ENCRYPTION_KEY`, `COLLECTORCTRL_JWT_SECRET`, `OPAMP_SHARED_SECRET`, your own TLS files) are **not** in the archive. Keep them in your secret manager.
- **PostgreSQL:** the archive holds everything except the database. Take a `pg_dump` at the same time.

**Restore** (server stopped, same version):

```bash
sudo systemctl stop collectorctrl
sudo bash -c 'set -a; [ -f /etc/collectorctrl/server.env ] && . /etc/collectorctrl/server.env; cd /opt/collectorctrl-server && \
  ./collectorctrl-server -restore /backups/cc-2026-10-01-0200.tar.gz'   # add -force to overwrite existing data
sudo systemctl start collectorctrl
```

After a restore: sign in, check that agents reconnect without re-enrolling (same CA), and that saved integrations (SSO, SMTP, S3, AI keys) still work (same encryption key).
