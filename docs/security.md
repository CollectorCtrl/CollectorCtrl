# Security

CollectorCtrl controls what runs on every host in your fleet, so a default install is meant to be secure, and every shortcut has to be enabled on purpose. This page describes the controls. To report a vulnerability, see [SECURITY.md](../SECURITY.md).

- [Transport security](#transport-security)
- [Agent identity](#agent-identity)
- [User authentication](#user-authentication)
- [Single sign-on](#single-sign-on)
- [Roles and permissions](#roles-and-permissions)
- [AI and automation guardrails](#ai-and-automation-guardrails)
- [Package and release signing](#package-and-release-signing)
- [Audit trail](#audit-trail)
- [Secrets at rest](#secrets-at-rest)
- [ZeroTouch safeguards](#zerotouch-safeguards)
- [Hardening checklist](#hardening-checklist)

---

## Transport security

- **TLS by default** on both the UI/API (4321) and the OpAMP gateway (4320).
- On first start the server creates a **per-install CA** (ECDSA P-256) and a server certificate that renews itself. No two installs share keys.
- If TLS can't be set up, the server **refuses to start**; it never falls back to plaintext. Plaintext modes exist for development and are refused on non-loopback addresses in production mode.
- You can use your own certificates, your own PKI or a TLS-terminating reverse proxy. See [Configuration → TLS](configuration.md#tls).
- OpAMP WebSocket frames are limited to 16 MB, and a failure in one agent's message handling closes only that agent's connection.

## Agent identity

- **Enrollment tokens** (`cce_…`) are created by an admin, expire (24 hours by default), can be limited to a number of uses, and can't authenticate UI or API calls.
- On first connect the server issues a **per-agent credential** (`cca_…`), bound to the instance UID. Only its hash is stored.
- After enrollment the identity is **locked**: a wrong credential, a second enrollment or a shared-secret login for that UID is refused and raises a **Possible agent impersonation** notification.
- **Revoke** disconnects an agent and permanently blocks its UID. **Allow re-enroll** brings back a rebuilt host with its history.
- Onboarding scripts **pin the server CA by fingerprint** and abort on a mismatch. The supervisor installers take the server's CA certificate (`--ca-file`, `/CA_FILE=`, `CA_FILE=`), so a directly installed supervisor verifies the server certificate instead of skipping verification.
- An enrollment token given to an installer is used once and removed from the host after the server has issued the credential.
- **Machine images** must not contain an identity: install with `--no-start` / `NOSTART=1`, or run `-reset-identity` before capturing. See [Machine images](enterprise-deployment.md#machine-images).
- **Legacy mode** (`OPAMP_LEGACY_MODE=true`) also accepts a fleet-wide shared secret. It's off by default and meant only as a migration window, for example for a Kubernetes observer installed before v0.6.0 that hasn't moved to enrollment yet. Upgraded supervisors that connect in legacy mode are migrated to their own credential automatically.

## User authentication

- Local accounts with **bcrypt**-hashed passwords.
- **No well-known administrator password in an installer or production-mode install.** The Windows and Linux server installers ask for the `admin` password or generate one. In production mode without `COLLECTORCTRL_ADMIN_PASSWORD`, the server generates a one-time password and prints it once in its log. Only outside production mode, without that variable (for example a plain `docker run`), does the account start as `admin` / `admin`. A password the operator did not choose must be changed at first sign-in, and until then the account can do nothing else.
- The bundled PostgreSQL gets generated passwords: the Windows installer saves the superuser password in a file readable by Administrators and SYSTEM only, and the Linux installer creates a `collectorctrl` role without altering the `postgres` superuser.
- **Browser sessions** use an HttpOnly, SameSite=Strict cookie (Secure over TLS), and every change from the UI carries a CSRF token. Scripts and MCP clients use API tokens.
- **Sign-in throttling** per source address. Unknown user, wrong password, disabled and locked accounts all answer the same `401`.
- **Security headers** on every response, including a Content-Security-Policy (`COLLECTORCTRL_CSP`), `X-Content-Type-Options: nosniff` and `X-Frame-Options: DENY`. CORS grants nothing unless `COLLECTORCTRL_ALLOWED_ORIGIN` is set.
- Sessions survive server restarts and are revoked when a user's role, sign-in method or status changes.
- **API tokens** (`cc_…`) for automation and MCP clients, assigned a role and optionally an environment scope. The scope is enforced on every action, not only on reads, and a refused attempt is written to the audit log. Tokens are shown once and stored as SHA-256 hashes.
- Client-supplied identity headers are discarded.

## Single sign-on

- **OIDC** with presets for Okta, Microsoft Entra ID (Azure AD), Google Workspace, Keycloak and Auth0, or any OIDC-compliant provider.
- **Test sign-in** shows the identity, groups and resulting role before you enforce SSO. Password sign-in can be turned off only after a successful test.
- **Just-in-time provisioning**, ordered **group-to-role rules** (first match wins), a default role or deny, custom claims and scopes, and SSO session lifetime.
- Named **break-glass** admin accounts always keep local access, and local sign-in keeps working if the identity provider is unreachable.

## Roles and permissions

- Built-in **Admin**, **Editor** and **Viewer** roles, plus custom roles built from granular permissions (fleet, configuration, policies, packages, builder, governor, ZeroTouch, audit, system settings…). The Governance section is shown to users with the Governor view permission.
- Permissions are enforced on every API route and MCP tool, with optional **environment scoping**.
- **Grant ceiling:** you can grant only permissions you hold, and only admins can grant admin. High-privilege capabilities (SSO configuration, API tokens, database maintenance, the OpAMP secret) are flagged in the role editor.
- Roles in use can't be deleted, and every role change is audited with the exact permissions added or removed.

## AI and automation guardrails

- The Copilot and MCP clients can **read and propose**. Every change becomes a pending action that a signed-in person approves under **Rollouts → Approvals**.
- The approver needs `mcp:approve` plus the permission and environment scope of the action itself. **Four-eyes approval** stops people approving their own proposals; it is on by default for new installs since v0.7.0-beta. MCP governance settings are admin-only.
- Proposals show their blast radius, are capped by a configurable collector limit, are re-validated at approval time, execute at most once and expire after 15 minutes.
- API tokens can't approve. Auto-approval requires an explicit server setting **and** a permission no built-in role has.
- Every AI tool call is audited with its actor, tool, arguments and duration. Prompts go only to the model provider you configure, and PII redaction is available.

## Package and release signing

- **Release artifacts:** every file on the [Releases](https://github.com/CollectorCtrl/CollectorCtrl/releases) page has a detached Ed25519 `.sig`. See [Verifying downloads](verifying-downloads.md).
- **Supervisor updates** install only with a vendor release signature built into the supervisor. A CollectorCtrl server can never approve a supervisor, so a compromised server can't push a new one.
- **Collector and sidecar packages** install only with a release signature or an explicit **Sign** approval in the UI, made with the server's per-install key and recorded in the audit log.
- A package without a content hash is always refused.
- **Package mirror:** the server is built with the same release keys as the supervisor. For every supervisor package it mirrors from GitHub it verifies the `.sig` and keeps the package only if it passes. `/packages/<package>.sig` is answered only when it is a valid release signature of that package.
- **Install commands:** the Linux, macOS and Windows one-line commands compare the package's SHA-256 with that signature and stop on a mismatch. `--require-signature` (`-RequireSignature` on Windows) also stops when the server has no signature for the package.
- **Not covered:** the Package, Ansible and Installer snippets, the MSI and a hand-run `install.sh` do not check the signature, and a package a host downloads directly from GitHub is not checked. The Windows setup programs and MSI are not Authenticode-signed.
- **Supervisor upgrades start with a canary cohort** and halt if a canary fails.
- **Container images** are signed with cosign and carry an SPDX SBOM and SLSA provenance (since v0.6.4-beta).

## Audit trail

- Every administrative action, configuration change, lifecycle command, sign-in, token and role change, package signature, AI action and Git sync is recorded. Refused requests are recorded too.
- Entries are **hash-chained**. **Verify integrity** confirms the trail is intact or pinpoints the altered entry.
- Each entry includes actor type, source IP, user agent, request ID and outcome. Full-history search and CSV export are available.
- **SIEM streaming:** events are sent in real time as OTLP logs, over TLS for HTTPS endpoints.

## Secrets at rest

- Integration secrets (OIDC, SMTP, S3, AI provider keys, Git tokens, license) are **encrypted** with the server's encryption key.
- Key material in the data directory is created with mode `0600`, and on Windows is restricted to SYSTEM and Administrators.
- **Running without root (Linux, opt-in):** `--run-as-user` runs the Supervisor and its collector as an unprivileged user in a systemd sandbox. Root stays the default, and some features need it. See [Running without root](agent-onboarding.md#running-without-root-linux).
- After the Supervisor takes over an existing collector, that collector runs as the Supervisor's user (root or LocalSystem by default), not as its former service account.
- Supervisors store their credential with restricted permissions, and redact secret-looking command-line arguments from discovery reports.
- Configurations are stored as pushed, so prefer environment-variable references (for example `${env:API_KEY}`) over inline credentials in collector configs.

## ZeroTouch safeguards

- Nodes act only on applications they discovered themselves; caller-supplied process data is ignored.
- Only `OTEL_*` variables are accepted from callers. Loader variables (`JAVA_TOOL_OPTIONS`, `NODE_OPTIONS`, …) are always generated on the node.
- Services are never restarted without consent ("restart required" by default). Standalone apps are relaunched as the same user, and processes under the Windows system directory are refused.
- Agent assets are checksum-pinned and downloaded only over HTTPS from allowed hosts.

## Hardening checklist

- [ ] Run with `COLLECTORCTRL_MODE=production` and explicit `COLLECTORCTRL_JWT_SECRET` and `COLLECTORCTRL_ENCRYPTION_KEY` held in your secret manager.
- [ ] Serve the UI with a certificate your users trust (your PKI or a reverse proxy).
- [ ] Choose the `admin` password at install time (or set `COLLECTORCTRL_ADMIN_PASSWORD`), enable SSO, and keep at least one break-glass admin.
- [ ] Use least-privilege custom roles and environment-scoped API tokens.
- [ ] Keep `OPAMP_LEGACY_MODE`, `OPAMP_AUTH_DISABLED` and `COLLECTORCTRL_ALLOW_UNSIGNED_PACKAGES` off.
- [ ] Keep **four-eyes approval** on for AI actions, and keep the blast-radius limit low.
- [ ] Install supervisors with the server's CA (`--ca-file` or the Add collector command), and use `--require-signature` on the install commands once the mirror holds signatures.
- [ ] Stream the audit trail to your SIEM, and set `COLLECTORCTRL_AUDIT_RETENTION_DAYS` to what your policy requires (default 30 days).
- [ ] Restrict access to the data directory, and take regular [backups](upgrading.md#backup-and-restore).
- [ ] [Verify release signatures](verifying-downloads.md) before installing or uploading packages.
