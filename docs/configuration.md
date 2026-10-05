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
- [Other settings](#other-settings)
- [Supervisor-side variables](#supervisor-side-variables)
- [Development-only switches](#development-only-switches)

---

## Core

| Variable | Default | Description |
| :--- | :--- | :--- |
| `COLLECTORCTRL_MODE` | (unset) | Set to `production` for production deployments. The server then refuses to start without `COLLECTORCTRL_JWT_SECRET` and `COLLECTORCTRL_ENCRYPTION_KEY`, and refuses plaintext UI or OpAMP listeners on non-loopback addresses. |
| `COLLECTORCTRL_ADMIN_PASSWORD` | `admin` | Password for the built-in `admin` account, used only when the server creates it on first start. If unset, `admin` / `admin` is used and must be changed at first sign-in. |

## Data directory

The data directory holds the per-install CA and server certificate (`tls/`), the encryption key, session secret, OpAMP secret, tap-token secret and package-signing key, plus (when `COLLECTORCTRL_DATA_DIR` is set) the SQLite database, uploaded packages, agent assets, instrumentation state and local backups.

| Variable | Description |
| :--- | :--- |
| `COLLECTORCTRL_DATA_DIR` | Where state is stored. Strongly recommended for every non-Windows install. |

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
| `COLLECTORCTRL_ADVERTISE_HOST` | auto-detected | Host name or IP that agents should use (load balancer, public DNS name, Kubernetes Service). |
| `COLLECTORCTRL_OPAMP_ENDPOINT` | derived | Full OpAMP endpoint to put in onboarding commands, e.g. `wss://cc.example.com:4320/v1/opamp`. |
| `COLLECTORCTRL_ALLOWED_ORIGIN` | — | Allowed CORS origin for the API, if the UI is served from another origin. |
| `COLLECTORCTRL_TRUST_PROXY_HEADERS` | `false` | Take the client IP from `X-Forwarded-For` (only behind a trusted proxy). |

## Secrets

If these aren't set, the server generates random values and keeps them in the data directory. Set them explicitly when you run in production mode, or when secrets must come from a secret manager.

| Variable | Description |
| :--- | :--- |
| `COLLECTORCTRL_JWT_SECRET` | Signs UI sessions. Required in production mode. |
| `COLLECTORCTRL_ENCRYPTION_KEY` | Encrypts settings at rest (SSO, SMTP, S3, AI keys, Git tokens, license). Required in production mode. **If you lose it, those settings can't be decrypted.** |
| `COLLECTORCTRL_TAP_TOKEN_SECRET` | Keys the Telemetry Governor tap tokens. |
| `OPAMP_SHARED_SECRET` | Legacy fleet-wide agent secret (see below). `OPAMP_SHARED_SECRET_PREVIOUS` is also accepted during a rotation. |

Generate values with `openssl rand -hex 32`.

## Agent authentication

| Variable | Default | Description |
| :--- | :--- | :--- |
| `OPAMP_LEGACY_MODE` | `false` | Also accept agents that authenticate with the shared secret instead of a per-agent credential. Use it only as a migration window when upgrading from 0.5.0 or earlier, or for Kubernetes operator-managed collectors. Upgraded supervisors that connect this way are migrated to their own credential automatically. |

## Single sign-on bootstrap

SSO is normally configured in **Settings → SSO**, which has provider presets and a test sign-in. These variables pre-seed an OIDC configuration, for example for automated installs:

`COLLECTORCTRL_OIDC_ISSUER`, `COLLECTORCTRL_OIDC_CLIENT_ID`, `COLLECTORCTRL_OIDC_CLIENT_SECRET`, `COLLECTORCTRL_OIDC_REDIRECT_URL`, `COLLECTORCTRL_OIDC_ROLES_ADMIN`, `COLLECTORCTRL_OIDC_ROLES_EDITOR`, `COLLECTORCTRL_OIDC_ROLES_VIEWER`.

## AI and MCP

AI providers, models and guardrails are configured in **Settings → AI**. See [AI Copilot and MCP](ai-copilot-and-mcp.md).

| Variable | Default | Description |
| :--- | :--- | :--- |
| `COLLECTORCTRL_MCP_AUTO_APPROVE` | `false` | Allow MCP proposals to be approved automatically, for unattended automation. It only takes effect for callers that also hold the `mcp:auto-approve` permission, which no role has by default. |

## Other settings

| Variable | Description |
| :--- | :--- |
| `COLLECTORCTRL_OTLP_AUDIT_INSECURE` | `true` allows the OTLP audit stream to a SIEM endpoint without TLS (e.g. a local collector). |
| `COLLECTORCTRL_ASSET_ALLOWED_HOSTS` | Hosts that ZeroTouch agent assets may be downloaded from, besides the built-in catalog. URLs must be `https` and carry a checksum. |
| `COLLECTORCTRL_GOVERNOR_MAX_PAYLOAD_BYTES` | Maximum request body for Telemetry Governor shadow ingest. Larger requests get HTTP 413. |
| `COLLECTORCTRL_FRONTEND_DIR` | Location of the web UI assets, if not next to the binary. |

## Supervisor-side variables

Set these on managed hosts, for the Supervisor service:

| Variable | Description |
| :--- | :--- |
| `COLLECTORCTRL_ENROLL_TOKEN` | Enrollment token for the first connection. The onboarding scripts set it. |
| `OPAMP_SHARED_SECRET` | Legacy shared secret, only for servers in legacy mode. |

Don't copy `COLLECTORCTRL_JWT_SECRET` or `COLLECTORCTRL_TAP_TOKEN_SECRET` to agent hosts: supervisors don't read them, and a copy on a node could be used to forge sessions.

## Development-only switches

These weaken security. Never use them outside a test environment.

| Variable | Effect |
| :--- | :--- |
| `OPAMP_AUTH_DISABLED=true` | Disables all agent authentication. |
| `COLLECTORCTRL_UI_TLS=plain`, `COLLECTORCTRL_OPAMP_TLS=off` | Plaintext listeners. |
| `COLLECTORCTRL_ALLOW_UNSIGNED_PACKAGES=true` (on a host) | The Supervisor installs unsigned packages. A content hash is still required. |

## Ports

| Port | Purpose |
| :--- | :--- |
| 4320 | OpAMP gateway (WSS) |
| 4321 | UI, REST API, MCP, onboarding and package downloads (HTTPS) |
| 13133 | Collector health check on each host (local only) |
