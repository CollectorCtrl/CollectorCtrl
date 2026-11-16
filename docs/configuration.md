# Configuration reference

The server is configured with environment variables. Most settings (SSO, SMTP, alert channels, AI providers, Git, S3, licensing) are managed in the UI under **Settings** and stored encrypted in the database.

How to set environment variables: systemd `EnvironmentFile` or `systemctl edit` (Linux), the service's registry `Environment` value (Windows), or `environment:` (Docker / Compose). Restart the server after changing them.

- [Core](#core)
- [Data directory](#data-directory)
- [Database](#database)
- [TLS](#tls)
- [Network and URLs](#network-and-urls)
- [Secrets](#secrets)
- [Agent authentication](#agent-authentication)
- [Single sign-on bootstrap](#single-sign-on-bootstrap)
- [AI and MCP](#ai-and-mcp)
- [Governance](#governance)
- [Logging and metrics](#logging-and-metrics)
- [Packages and Custom builds](#packages-and-custom-builds)
- [Other settings](#other-settings)
- [Supervisor-side variables](#supervisor-side-variables)
- [Development-only switches](#development-only-switches)

---

## Core

| Variable | Default | Description |
| :--- | :--- | :--- |
| `COLLECTORCTRL_MODE` | (unset) | Set to `production` for production deployments. The server then refuses to start without `COLLECTORCTRL_JWT_SECRET` and `COLLECTORCTRL_ENCRYPTION_KEY`, and refuses plaintext UI or OpAMP listeners on non-loopback addresses. |
| `COLLECTORCTRL_ADMIN_PASSWORD` | (unset) | Password for the built-in `admin` account, used only when the server creates it on first start. If unset in production mode, the server generates a one-time password, prints it once in its log and requires a change at first sign-in. If unset outside production mode, `admin` / `admin` is used and must be changed at first sign-in. The Windows and Linux server installers set the password you choose, or a generated one, for the first start. |

## Data directory

The data directory holds the per-install CA and server certificate (`tls/`), the encryption key, session secret, OpAMP secret, tap-token secret and package-signing key, plus (when `COLLECTORCTRL_DATA_DIR` is set) the SQLite database, uploaded packages, agent assets, instrumentation state and local backups.

| Variable | Description |
| :--- | :--- |
| `COLLECTORCTRL_DATA_DIR` | Where state is stored. Strongly recommended for every non-Windows install. |
| `COLLECTORCTRL_PACKAGES_DIR` | Directory of uploaded and mirrored packages, served at `/packages/`. Default: `packages` under the data directory, when `COLLECTORCTRL_DATA_DIR` is set. |
| `COLLECTORCTRL_AGENT_ASSETS_DIR` | Directory of instrumentation agent assets. Default: `agent-assets` under the data directory, when `COLLECTORCTRL_DATA_DIR` is set. |
| `COLLECTORCTRL_BACKUP_DIR` | Directory for backups made from the UI. Default: `backups` under the data directory when `COLLECTORCTRL_DATA_DIR` is set. |

If unset, the server uses, in order: the directory of the SQLite file given in `COLLECTORCTRL_DB_DSN`; `%PROGRAMDATA%\CollectorCtrl` on Windows; otherwise its working directory. The Docker image sets `/var/lib/collectorctrl`.

Files are created with mode `0600`. On Windows, restrict the folder to SYSTEM and Administrators (see [Installation](setup.md#windows)).

## Database

| Variable | Default | Description |
| :--- | :--- | :--- |
| `COLLECTORCTRL_DB_TYPE` | SQLite | `postgres` to use PostgreSQL. |
| `COLLECTORCTRL_DB_DSN` | `<data dir>/collectorctrl.db` | SQLite file path, or a PostgreSQL DSN such as `host=db port=5432 user=collectorctrl password=… dbname=collectorctrl sslmode=require`. |

Schema migrations run automatically at start-up.

## TLS

The UI/API (port 4321) and the OpAMP gateway (port 4320) use TLS by default, with certificates from the server's own CA. That CA is created on first start: ECDSA P-256, valid for 10 years. The server certificate is valid for 825 days and is renewed automatically within 30 days of expiry, or when the server's host names change. It covers `localhost`, the host name, local interface IPs, and the hosts in `COLLECTORCTRL_URL`, `COLLECTORCTRL_OPAMP_ENDPOINT` and `COLLECTORCTRL_ADVERTISE_HOST`.

| Variable | Default | Description |
| :--- | :--- | :--- |
| `COLLECTORCTRL_UI_TLS` | `tls` | `tls`: serve HTTPS directly. If no certificate can be loaded, the server **refuses to start**; it never falls back to HTTP.<br>`proxy`: plain HTTP behind a TLS-terminating reverse proxy. Requires `COLLECTORCTRL_URL=https://…`.<br>`plain`: development only. In production mode it's allowed only on a loopback `COLLECTORCTRL_UI_ADDR`. |
| `COLLECTORCTRL_UI_HTTPS` | — | Legacy switch (`true` / `false`), honoured only when `COLLECTORCTRL_UI_TLS` is unset. |
| `COLLECTORCTRL_UI_CERT`, `COLLECTORCTRL_UI_KEY` | — | Your own certificate and key for the UI/API listener. |
| `COLLECTORCTRL_TLS_CERT`, `COLLECTORCTRL_TLS_KEY`, `COLLECTORCTRL_TLS_CA` | — | Use your own PKI for the server certificate and CA instead of the generated ones. Server-issued agent client certificates are then disabled, because the CA key isn't available. |
| `COLLECTORCTRL_OPAMP_TLS` | on | `off` disables TLS on the OpAMP gateway. Development only; in production it also needs a loopback `COLLECTORCTRL_OPAMP_ADDR` or `COLLECTORCTRL_OPAMP_BEHIND_PROXY=true`. |
| `COLLECTORCTRL_OPAMP_BEHIND_PROXY` | `false` | Set to `true` when a TLS proxy terminates OpAMP in front of the server. |

The CA is published at `GET /api/onboard/ca.pem`. Its SHA-256 fingerprint is in the server's start-up log and in `GET /api/onboard/serverinfo` (`ca_sha256`).

### Example: reverse proxy (Nginx)

```nginx
server {
    listen 443 ssl;
    server_name collectorctrl.example.com;
    ssl_certificate     /etc/ssl/collectorctrl/fullchain.pem;
    ssl_certificate_key /etc/ssl/collectorctrl/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:4321;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

with `COLLECTORCTRL_UI_TLS=proxy`, `COLLECTORCTRL_URL=https://collectorctrl.example.com`, `COLLECTORCTRL_UI_ADDR=127.0.0.1:4321` and, to record real client IPs in the audit log, `COLLECTORCTRL_TRUST_PROXY_HEADERS=true`.

## Network and URLs

| Variable | Default | Description |
| :--- | :--- | :--- |
| `COLLECTORCTRL_UI_ADDR` | `0.0.0.0:4321` | Listen address for the UI, REST API and MCP endpoint. |
| `COLLECTORCTRL_OPAMP_ADDR` | port 4320 on all interfaces | Listen address for the OpAMP gateway. |
| `COLLECTORCTRL_URL` | `https://<primary IP>:4321` | External base URL of the UI. Used for package download links, onboarding commands and the server certificate. |
| `COLLECTORCTRL_UI_URL` | — | Base URL of the UI for links in notifications and the redirect after SSO sign-in, when it differs from `COLLECTORCTRL_URL`. |
| `COLLECTORCTRL_ADVERTISE_HOST` | auto-detected | Host name or IP that agents should use (load balancer, public DNS name, Kubernetes Service). |
| `COLLECTORCTRL_OPAMP_ENDPOINT` | derived | Full OpAMP endpoint to put in onboarding commands, e.g. `wss://cc.example.com:4320/v1/opamp`. |
| `COLLECTORCTRL_ALLOWED_ORIGIN` | — | Allowed CORS origins for the API (comma-separated, or `*` without credentials), if the UI is served from another origin. CORS grants nothing unless this is set. |
| `COLLECTORCTRL_CSP` | built-in policy | Content-Security-Policy sent with every response: `off`, `report-only`, or a custom policy. `COLLECTORCTRL_CSP_REPORT_ONLY=true` sends the policy as report-only. |
| `COLLECTORCTRL_TRUST_PROXY_HEADERS` | `false` | Take the client IP and scheme from the proxy's forwarding headers (only behind a trusted proxy). Needed behind a TLS-terminating proxy so the session cookie's `Secure` flag and sign-in throttling work correctly. |

## Secrets

If these aren't set, the server generates random values and keeps them in the data directory. Set them explicitly when you run in production mode, or when secrets must come from a secret manager.

| Variable | Description |
| :--- | :--- |
| `COLLECTORCTRL_JWT_SECRET` | Signs UI sessions. Required in production mode. |
| `COLLECTORCTRL_ENCRYPTION_KEY` | Encrypts settings at rest (SSO, SMTP, S3, AI keys, Git tokens, license). Required in production mode. **If you lose it, those settings can't be decrypted.** |
| `COLLECTORCTRL_TAP_TOKEN_SECRET` | Keys the Governance (Telemetry Governor) tap tokens. |
| `OPAMP_SHARED_SECRET` | Legacy fleet-wide agent secret (see below). `OPAMP_SHARED_SECRET_PREVIOUS` is also accepted during a rotation. |

Generate values with `openssl rand -hex 32`.

## Agent authentication

| Variable | Default | Description |
| :--- | :--- | :--- |
| `OPAMP_LEGACY_MODE` | `false` | Also accept agents that authenticate with the shared secret instead of a per-agent credential. Use it only as a migration window when upgrading from 0.5.0 or earlier, or for a Kubernetes observer installed before v0.6.0 that hasn't moved to enrollment yet. Upgraded supervisors that connect this way are migrated to their own credential automatically. |

## Single sign-on bootstrap

SSO is normally configured in **Settings → Single sign-on**, which has provider presets and a test sign-in. These variables pre-seed an OIDC configuration, for example for automated installs:

`COLLECTORCTRL_OIDC_ISSUER`, `COLLECTORCTRL_OIDC_CLIENT_ID`, `COLLECTORCTRL_OIDC_CLIENT_SECRET`, `COLLECTORCTRL_OIDC_REDIRECT_URL`, `COLLECTORCTRL_OIDC_ROLES_ADMIN`, `COLLECTORCTRL_OIDC_ROLES_EDITOR`, `COLLECTORCTRL_OIDC_ROLES_VIEWER`.

## AI and MCP

AI providers, models and guardrails are configured in **Settings → Model & provider**. See [AI Copilot and MCP](ai-copilot-and-mcp.md).

| Variable | Default | Description |
| :--- | :--- | :--- |
| `COLLECTORCTRL_MCP_AUTO_APPROVE` | `false` | Allow MCP proposals to be approved automatically, for unattended automation. It only takes effect for callers that also hold the `mcp:auto-approve` permission, which no role has by default. |

## Governance

The global sampling rate (default 10%) is not an environment variable: set it under **Governance → Configuration**. These variables bound the Telemetry Governor's ingest and queries. Effective values and counters are returned by `GET /api/governor/engine-status`.

| Variable | Default | Description |
| :--- | :--- | :--- |
| `COLLECTORCTRL_GOVERNOR_QUERY_SCAN_LIMIT` | `100000` | Newest records an Insights pattern or overview query reads. The response says when the range holds more. |
| `COLLECTORCTRL_GOVERNOR_RETENTION_DAYS` | `7` | Days sampled tap records are kept. |
| `COLLECTORCTRL_GOVERNOR_MAX_PAYLOAD_BYTES` | 10 MiB | Maximum request body for tap ingest, as sent. Larger requests get HTTP 413. |
| `COLLECTORCTRL_GOVERNOR_MAX_DECODED_BYTES` | 16 MiB | Maximum payload after decompression. |
| `COLLECTORCTRL_GOVERNOR_MAX_CONCURRENT_INGEST` | `8` | Concurrent tap uploads. When saturated, the server answers `429` with `Retry-After`. |
| `COLLECTORCTRL_GOVERNOR_RATE_LIMIT_PER_MIN` | `600` | Ingest requests per minute before the server answers `429`. |
| `COLLECTORCTRL_GOVERNOR_DAILY_QUOTA_BYTES` | 10 GiB | Daily ingest quota. Above it the server answers `429` with `Retry-After`. |
| `COLLECTORCTRL_GOVERNOR_INGEST_WORKERS` | `2` | Workers that write queued records to the database. |
| `COLLECTORCTRL_GOVERNOR_INGEST_QUEUE_BATCHES` | `64` | Batches the ingest queue holds. |
| `COLLECTORCTRL_GOVERNOR_INGEST_QUEUE_RECORDS` | `200000` | Records the ingest queue holds. |
| `COLLECTORCTRL_GOVERNOR_WORKERS` | `50` | Workers that forward telemetry to destinations. |
| `COLLECTORCTRL_GOVERNOR_QUEUE_SIZE` | `50000` | Jobs the forwarding queue holds. |
| `COLLECTORCTRL_GOVERNOR_QUEUE_MAX_BYTES` | 256 MiB | Decoded bytes the forwarding queue holds. |

Identical Insights queries within 30 seconds are answered from memory; this is not configurable.

## Logging and metrics

| Variable | Default | Description |
| :--- | :--- | :--- |
| `COLLECTORCTRL_LOG_FORMAT` | `text` | `json` emits JSON log lines with request, user and collector IDs. |
| `COLLECTORCTRL_LOG_LEVEL` | `info` | `debug`, `info`, `warn` or `error`. |
| `COLLECTORCTRL_HTTP_ACCESS_LOG` | `false` | `true` logs every HTTP request at info level. |
| `COLLECTORCTRL_DEBUG` | `false` | `true` adds verbose per-request debug logging. |
| `COLLECTORCTRL_METRICS_TOKEN` | — | Bearer token that lets a scraper read `/metrics` without a user session or API token. |

`/metrics` serves Prometheus metrics, including the Governor's ingest and forwarding counters as `collectorctrl_governor_*` gauges. It is reachable with a session, an API token, `COLLECTORCTRL_METRICS_TOKEN`, or unauthenticated from loopback. `/readyz` returns `200`, or `503` with the failing check (database, OpAMP listener). `/api/health` is the liveness probe.

## Packages and Custom builds

| Variable | Default | Description |
| :--- | :--- | :--- |
| `COLLECTORCTRL_PACKAGE_SYNC` | on | `false` stops the server mirroring supervisor packages from GitHub (at start and every 6 hours). Use it on air-gapped servers. |
| `COLLECTORCTRL_PACKAGE_SYNC_REPO` | `CollectorCtrl/CollectorCtrl` | GitHub repository the mirror syncs from. |
| `COLLECTORCTRL_COLLECTOR_PACKAGE_KEY` | `otelcol-contrib` | Package key under which the server offers main collector packages. It must match `distro.package_key` in the supervisors' `supervisor.yaml`. |
| `COLLECTORCTRL_MAX_PARALLEL_UPGRADES` | `10` | Collector upgrades a policy runs in parallel. |
| `COLLECTORCTRL_WAVE_BAKE_SECONDS` | `120` | Seconds a rollout wave must stay healthy before the next wave. |
| `COLLECTORCTRL_OCB_TIMEOUT` | `60m` | Time limit of one Custom build, as a duration. |
| `COLLECTORCTRL_OCB_CACHE_DIR` | the service account's cache directory | Where the builder caches `ocb` binaries, one directory per version. |

## Other settings

| Variable | Description |
| :--- | :--- |
| `COLLECTORCTRL_OTLP_AUDIT_ENDPOINT` | OTLP endpoint the audit stream is sent to. Streaming is off when unset. |
| `COLLECTORCTRL_OTLP_AUDIT_INSECURE` | `true` allows the OTLP audit stream to a SIEM endpoint without TLS (e.g. a local collector). |
| `COLLECTORCTRL_AUDIT_RETENTION_DAYS` | Days audit entries are kept. Default `30`; `0` disables pruning. |
| `COLLECTORCTRL_ASSET_ALLOWED_HOSTS` | Hosts that instrumentation agent assets may be downloaded from, besides the built-in catalog. URLs must be `https` and carry a checksum. Supervisors read it too. |
| `COLLECTORCTRL_FRONTEND_DIR` | Location of the web UI assets, if not next to the binary. |

## Supervisor-side variables

Set these on managed hosts, for the Supervisor service:

| Variable | Description |
| :--- | :--- |
| `COLLECTORCTRL_ENROLL_TOKEN` | Enrollment token for the first connection. The installers instead write it to the `enroll_token` file in the Supervisor's storage directory, which the Supervisor deletes after the server has issued its credential. |
| `COLLECTORCTRL_PACKAGE_MAX_DOWNLOAD_BYTES` | Cap for one package download. Default 1 GiB. Also `packages.max_download_bytes` in `supervisor.yaml`. |
| `COLLECTORCTRL_PACKAGE_DOWNLOAD_TIMEOUT` | Time limit for one package download, as a duration. Default `15m`. Also `packages.download_timeout`. |
| `COLLECTORCTRL_ASSET_MAX_DOWNLOAD_BYTES` | Cap for one instrumentation agent download. Default 512 MiB. |
| `COLLECTORCTRL_ASSET_DOWNLOAD_TIMEOUT` | Time limit for one instrumentation agent download. Default 10 minutes. |
| `COLLECTORCTRL_SYSTEMD_UNIT` | Name of the systemd unit the Supervisor runs as. Default `collectorctrl-supervisor.service`. Also `packages.systemd_unit`. |
| `HTTPS_PROXY`, `NO_PROXY` | Proxy for hosts that reach the server through one. |
| `OPAMP_SHARED_SECRET` | Legacy shared secret, only for servers in legacy mode. `COLLECTORCTRL_OPAMP_SECRET` is read first when both are set. |

Don't copy `COLLECTORCTRL_JWT_SECRET` or `COLLECTORCTRL_TAP_TOKEN_SECRET` to agent hosts: supervisors don't read them, and a copy on a node could be used to forge sessions.

## Development-only switches

These weaken security. Never use them outside a test environment.

| Variable | Effect |
| :--- | :--- |
| `OPAMP_AUTH_DISABLED=true` | Disables all agent authentication. |
| `COLLECTORCTRL_UI_TLS=plain`, `COLLECTORCTRL_OPAMP_TLS=off` | Plaintext listeners. |
| `COLLECTORCTRL_ALLOW_UNSIGNED_PACKAGES=true` (on a host) | The Supervisor installs unsigned packages. A content hash is still required. |
| `COLLECTORCTRL_ALLOW_INSECURE_GOVERNOR_INGEST=true` | Tap ingest accepts requests without a tap token. |
| `COLLECTORCTRL_GIT_ALLOW_LOOPBACK=1` | Git integration may connect to a GitHub Enterprise instance on the server's own host. |

## Ports

| Port | Purpose |
| :--- | :--- |
| 4320 | OpAMP gateway (WSS) |
| 4321 | UI, REST API, MCP, onboarding and package downloads, `/readyz` and `/metrics` (HTTPS) |
| 13133 | Collector health check on each host (`127.0.0.1` by default) |
