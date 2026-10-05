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
- Onboarding scripts **pin the server CA by fingerprint** and abort on a mismatch.
- **Legacy mode** (`OPAMP_LEGACY_MODE=true`) also accepts a fleet-wide shared secret. It's off by default and meant only as a migration window, and it's currently needed for collectors managed by the Kubernetes operator. Upgraded supervisors that connect in legacy mode are migrated to their own credential automatically.

## User authentication

- Local accounts with **bcrypt**-hashed passwords. The built-in `admin` account must change its default password at first sign-in.
- Signed session tokens. Sessions survive server restarts and are revoked when a user's role, sign-in method or status changes.
- **API tokens** (`cc_…`) for automation and MCP clients, assigned a role and optionally an environment scope. They're shown once and stored as SHA-256 hashes.
- Client-supplied identity headers are discarded.

## Single sign-on

- **OIDC** with presets for Okta, Microsoft Entra ID (Azure AD), Google Workspace, Keycloak and Auth0, or any OIDC-compliant provider.
- **Test sign-in** shows the identity, groups and resulting role before you enforce SSO. Password sign-in can be turned off only after a successful test.
- **Just-in-time provisioning**, ordered **group-to-role rules** (first match wins), a default role or deny, custom claims and scopes, and SSO session lifetime.
- Named **break-glass** admin accounts always keep local access, and local sign-in keeps working if the identity provider is unreachable.

## Roles and permissions

- Built-in **Admin**, **Editor** and **Viewer** roles, plus custom roles built from granular permissions (fleet, configuration, policies, packages, builder, governor, ZeroTouch, audit, system settings…).
- Permissions are enforced on every API route and MCP tool, with optional **environment scoping**.
- **Grant ceiling:** you can grant only permissions you hold, and only admins can grant admin. High-privilege capabilities (SSO configuration, API tokens, database maintenance, the OpAMP secret) are flagged in the role editor.
- Roles in use can't be deleted, and every role change is audited with the exact permissions added or removed.

## AI and automation guardrails

- The Copilot and MCP clients can **read and propose**. Every change becomes a pending action that a signed-in person approves in **Settings → Pending AI Actions**.
- The approver needs `mcp:approve` plus the permission and environment scope of the action itself. **Four-Eyes Approval** can stop people approving their own proposals.
- Proposals show their blast radius, are capped by a configurable collector limit, are re-validated at approval time, execute at most once and expire after 15 minutes.
- API tokens can't approve. Auto-approval requires an explicit server setting **and** a permission no built-in role has.
- Every AI tool call is audited with its actor, tool, arguments and duration. Prompts go only to the model provider you configure, and PII redaction is available.

## Package and release signing

- **Release artifacts:** every file on the [Releases](https://github.com/CollectorCtrl/CollectorCtrl/releases) page has a detached Ed25519 `.sig`. See [Verifying downloads](verifying-downloads.md).
- **Supervisor updates** install only with a vendor release signature built into the supervisor. A CollectorCtrl server can never approve a supervisor, so a compromised server can't push a new one.
- **Collector and sidecar packages** install only with a release signature or an explicit **Sign** approval in the UI, made with the server's per-install key and recorded in the audit log.
- A package without a content hash is always refused.

## Audit trail

- Every administrative action, configuration change, lifecycle command, sign-in, token and role change, package signature, AI action and Git sync is recorded. Refused requests are recorded too.
- Entries are **hash-chained**. **Verify integrity** confirms the trail is intact or pinpoints the altered entry.
- Each entry includes actor type, source IP, user agent, request ID and outcome. Full-history search and CSV export are available.
- **SIEM streaming:** events are sent in real time as OTLP logs, over TLS for HTTPS endpoints.

## Secrets at rest

- Integration secrets (OIDC, SMTP, S3, AI provider keys, Git tokens, license) are **encrypted** with the server's encryption key.
- Key material in the data directory is created with mode `0600`, and on Windows is restricted to SYSTEM and Administrators.
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
- [ ] Change the `admin` password, enable SSO, and keep at least one break-glass admin.
- [ ] Use least-privilege custom roles and environment-scoped API tokens.
- [ ] Keep `OPAMP_LEGACY_MODE`, `OPAMP_AUTH_DISABLED` and `COLLECTORCTRL_ALLOW_UNSIGNED_PACKAGES` off.
- [ ] Enable **Four-Eyes Approval** for AI actions, and keep the blast-radius limit low.
- [ ] Stream the audit trail to your SIEM.
- [ ] Restrict access to the data directory, and take regular [backups](upgrading.md#backup-and-restore).
- [ ] [Verify release signatures](verifying-downloads.md) before installing or uploading packages.
