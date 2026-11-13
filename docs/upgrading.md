# Upgrading, backup and restore

- [Before every upgrade](#before-every-upgrade)
- [Upgrading the server](#upgrading-the-server)
- [Upgrading supervisors and collectors](#upgrading-supervisors-and-collectors)
- [Upgrading from 0.5.0 or earlier](#upgrading-from-050-or-earlier)
- [Changes to check in 0.5.2 – 0.5.5](#changes-to-check-in-052--055)
- [Changes to check in 0.6.x](#changes-to-check-in-06x)
- [Changes to check in 0.7.x](#changes-to-check-in-07x)
- [Changes to check in 0.8.x](#changes-to-check-in-08x)
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
| **Windows** | Run the new installer over the existing installation. It keeps the data directory, the accounts and the service's `Environment` registry value. The PostgreSQL edition offers "Keep the current database configuration". |
| **Linux** | `sudo systemctl stop collectorctrl`, extract the new archive, run `sudo ./install.sh`. The service restarts on the new version and the existing accounts are kept. |

## Upgrading supervisors and collectors

- **Supervisors:** upload the new supervisor package together with its `.sig` under **Settings → Supervisors**, then roll it out from there. Since v0.8.0-beta an upgrade of two or more supervisors starts with a canary cohort (10%, at least one, one per operating system); the rest wait until every canary reports the new version and has stayed connected for 2 minutes, and a canary that fails halts the queue with no other supervisor touched. The queue advances on the server without the page being open, but it is kept in memory: after a server restart during a rollout, start the upgrade again. A supervisor that can't reconnect after upgrading rolls itself back. Supervisors accept **only release-signed** supervisor packages.
- **Collectors and sidecars:** upload the package under **Catalog → Packages**, click **Sign** (after checking the SHA-256 against the vendor's published checksum), and roll it out through a policy or per collector. A collector you stopped on purpose stays stopped after an upgrade.
- **Re-running the Add collector command** on a host also upgrades its supervisor in place.

> **Supervisors from 0.5.2 or earlier:** release signing keys changed in 0.5.2 and again in 0.5.3, so those supervisors can't verify newer supervisor packages. Upgrade them **once by hand** by re-running the Add collector command (called Get Started before v0.8.0-beta) on each host. Remote supervisor upgrades work again from there on. Collector package upgrades are not affected.

## Upgrading from 0.5.0 or earlier

v0.5.1 made a default install secure and contains **breaking changes**. For an evaluation install, a clean reinstall is the simplest route. For an install with connected agents:

1. **Back up** the database and the data directory.
2. Start the upgraded server with `OPAMP_LEGACY_MODE=true` for a migration window. If your agents still use the old built-in default secret, also set `OPAMP_SHARED_SECRET` to the secret they actually use.
3. On first start the server creates its CA, server certificate and secrets in the data directory.
4. **Upgrade every supervisor by hand once** by re-running the Get Started command (with a new enrollment token). Upgraded supervisors that connect in legacy mode are migrated to their own per-agent credential automatically.
5. Watch the banner in the UI (“N of M agents have their own credential”). When every agent is enrolled, remove `OPAMP_LEGACY_MODE` and restart the server.
6. **Re-save** the OIDC, SMTP, S3, AI, Git and license settings once, so they're re-encrypted with the new key.
7. **Sign** previously uploaded collector packages under **Catalog → Packages**. Unsigned packages are no longer installed.

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

## Changes to check in 0.6.x

- **Kubernetes observer (0.6.0).** The observer now enrolls with an **Agent Enrollment** token stored in a Secret (`opamp.enrollmentSecret`), needs retained credential storage, and runs as **one** replica. Upgrade the server and the observer together. Installations that used the shared secret follow the legacy migration path before you turn `OPAMP_LEGACY_MODE` off. See [Kubernetes](setup.md#kubernetes).
- **Telemetry Governor sampling (0.6.2).** Taps now sample every severity at one rate, including warnings and errors, and the default rate for new taps is **10%**. Existing taps keep their rate. Hosts switch over when their supervisor is upgraded, so until the whole fleet is upgraded, older hosts still send all errors and their errors look inflated in Insights. The S3 archive and OTLP destinations now receive a sample of errors, not every error.
- **Governor API (0.6.2).** `GET /api/governor/insights/overview` returns received counts only; the `estimated*`, `sampling_rate` and error/byte total fields are gone. Pattern endpoints no longer return estimated counts. A scope with more than 10,000 distinct patterns returns `422`.
- **Onboarding commands (0.6.3).** Generate new commands in **Get Started**: commands copied before 0.6.3 don't verify the server's CA before downloading. Windows hosts need `curl.exe`, which current Windows versions include.
- **Alerts (0.6.3).** Disconnect and config-rejection alerts may arrive a few seconds later and, above 5 in an environment, are grouped into one summary. Alert rules that match the exact title "Collector Disconnected: …" or "Config Rejection: …" won't match a summary.
- **Environments (0.6.3).** Environment names are no longer case-sensitive: a token limited to `prod` also sees collectors classified as `Prod`. Review scoped tokens if you used capitalization to separate environments. Unclassified hosts and applications report `unknown` instead of `default`; Telemetry Governor S3 archive paths still use `environment=default`.
- **Older notifications (0.6.3)** have no environment and show as Fleet-wide.

## Changes to check in 0.7.x

- **Browser sessions (0.7.0).** Sessions move from page storage to an HttpOnly cookie, so every user signs in again once. An integration that read the session token from the browser must switch to an API token.
- **Reverse proxies (0.7.0).** If a proxy terminates TLS, set `COLLECTORCTRL_TRUST_PROXY_HEADERS=true` so the cookie's `Secure` flag and sign-in throttling see the real scheme and client address. If the UI is served from a different origin, set `COLLECTORCTRL_ALLOWED_ORIGIN`; CORS grants nothing unless it is set.
- **Content-Security-Policy (0.7.0).** Installations that embed CollectorCtrl in a frame or load it alongside other scripts should test with `COLLECTORCTRL_CSP=report-only` first.
- **Administrator password in production mode (0.7.0).** A new production-mode install no longer starts with `admin` / `admin`. Set `COLLECTORCTRL_ADMIN_PASSWORD`, or read the one-time password from the server log on first start.
- **Database migrations (0.7.0).** The first start records the migration baseline. Back up before upgrading. `collectorctrl-server -migrate-status` lists applied and pending versions.
- **Collector health check address (0.7.0).** The `health_check` extension the Supervisor adds listens on `127.0.0.1:13133` instead of `0.0.0.0:13133`. External monitors that polled it need `distro.health_check.endpoint` set in `supervisor.yaml`.
- **MCP settings (0.7.0).** Editors lose access to MCP governance settings; an admin must change them. Four-eyes approval stays as configured on existing installs and defaults to on for new ones.
- **Instrumentation (0.7.0).** Instrumenting a standalone process no longer restarts it unless explicitly confirmed (`confirm_restart: true` in the API).
- **Governor drop rules (0.7.0).** A policy that adds or changes an optimizer drop, sample or trace filter rule must go through a canary rollout or be saved with `force: true`.
- **Environment-scoped tokens (0.7.0).** A scoped token is refused on every action outside its environment, not only on reads.
- **Kubernetes operator (0.7.1).** Auto-instrumentation rollout state needs operator 0.9, and the OpenTelemetry settings table needs operator 0.9.1. Instrumentation readiness moved from the Fleet page to ZeroTouch Instrumentation → Kubernetes (**Instrumentation → Kubernetes** from 0.8.0).
- **Custom builds (0.7.3).** Builds need Go 1.25 or newer on the server, or the `server-ocb` image target, and access to the Go module proxy or a `GOPROXY` mirror. On a Windows service, set `GOMODCACHE` and `COLLECTORCTRL_OCB_CACHE_DIR` to move the caches out of the service account's profile.
- **Package order (0.7.3).** `/api/packages` returns newest first.

## Changes to check in 0.8.x

- **Unattended supervisor installs take over an existing collector (0.8.0).** `--non-interactive`, the Add collector commands and the Ansible role stop and disable a collector service that runs the same binary, without asking. Pass `--keep-existing-collector` / `/EXISTING_COLLECTOR=keep` to prevent it. After a takeover the collector runs as the Supervisor's user (root or LocalSystem by default). See [Enterprise deployment scenarios](enterprise-deployment.md#hosts-that-already-run-a-collector).
- **Supervisor upgrades take longer (0.8.0).** A rollout to two or more supervisors waits at least two minutes for the canary stage and stops if a canary fails. `skip_canary` on `POST /api/governor/supervisors/upgrade` upgrades every supervisor at once.
- **The mirror refuses unsigned packages (0.8.0).** The server no longer mirrors a supervisor package whose release signature is missing or invalid. On an air-gapped server, copy each package's `.sig` next to it, or the install commands print a warning (and stop with `--require-signature`).
- **Per-collector sampling rates are gone (0.8.0).** Every tapped collector moves to the global rate (10% unless you change it under **Governance → Configuration**) the next time its configuration is generated. If you ran collectors at different rates, Insights counts change at the upgrade.
- **External sources keep their old rate until you update them (0.8.0).** Copy the configuration from the source's Details into its collector again. Until then the source shows as "Not reported" or with its own rate.
- **MCP (0.8.0).** The `governor_set_sampling` tool is removed. A proposal for it created before the upgrade fails when approved.
- **Governor API (0.8.0).** `sampling_rate` on `POST /api/governor/taps/toggle` and `POST /api/templates/tap`, and the `sampling` parameter of `GET /api/governor/source-config`, are ignored. The global rate is `sampling_percentage` on `GET` / `POST /api/governor/tap-config`.
- **Labels become attributes (0.8.0).** A `supervisor.yaml` that already has a `labels:` section reports those labels as collector attributes after the supervisor is upgraded. An attribute the supervisor or the collector already reports keeps its value.
- **Collectors installed from Add collector report an environment (0.8.0).** The Linux and Windows commands pass the environment chosen on the page as the `deployment.environment` label. Classification rules still take precedence.
- **Host names may change (0.8.0).** Linux and macOS hosts that reported the placeholder `linux-node-01` or `macos-node-01` now report their real host name.
- **Linux server with PostgreSQL (0.8.0).** A database from an earlier install is transferred to the new `collectorctrl` role. A connection you configured yourself is kept.
- **MSI and setup program do not mix (0.8.0).** The MSI refuses to install while the setup program's installation is present. Moving from one to the other keeps the identity but not `supervisor.yaml`.
- **Web console (0.8.0).** The Telemetry section is now **Governance**, with **Instrumentation** as a separate section; old links (`?view=telemetry`, `data_wizard`, `zerotouch`) open the matching section. Links that used `view=patterns` inside Insights now use `panel=patterns`. Get Started is now **Add collector**, and Copilot and MCP proposals are approved under **Rollouts → Approvals**. In the Notification Center, clicking a notification opens its detail and marks it read.

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
