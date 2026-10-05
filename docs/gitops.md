# GitOps: managing fleet policies in Git

*Available since v0.5.3-beta.*

CollectorCtrl can keep fleet policies and per-collector overrides in a GitHub
(or GitHub Enterprise Server) repository. The repository becomes the reviewed
source of change; CollectorCtrl syncs it and applies valid changes to the
fleet.

Settings > **Git Integration** is where you connect the repository, see sync
status and drift, and propose changes.

## How it works

1. **Connect** a repository with an access token (Settings > Git Integration >
   Add repository). Only one repository can sync at a time.
2. **Export** writes the current fleet policies and collector overrides into
   the repository as one commit.
3. **Change** files through pull requests, either in GitHub directly or with
   **Propose a change** in CollectorCtrl.
4. **Sync.** CollectorCtrl reads the branch on its interval (default 60 s)
   and, when the webhook is set up, within seconds of a push or merged pull
   request. Valid files are applied through the same validated path as edits
   in the UI (policy history, canary gate, config history, audit log).
   Invalid files are reported and leave the current configuration unchanged.

## Repository layout

| Directory | Contents |
|-----------|----------|
| `base/` | Fleet policies for every collector |
| `templates/` | Fleet policies selected by labels |
| `clusters/` | Fleet policies for a cluster or environment |
| `overrides/` | Settings for one collector (`metadata.instanceId`) |

Only `.yaml`/`.yml` files in these directories are read. Everything else in
the repository is ignored, and changes submitted from CollectorCtrl can only
write to these directories.

## File format

```yaml
apiVersion: collectorctrl.io/v1alpha1
kind: TelemetryPolicy
metadata:
  name: linux-hosts          # policy name (matched case-insensitively)
  policyId: 6f1c…            # written by Export; keeps renames matched
  description: Linux hosts in production
  priority: 10
  target:                    # omit, or allAgents: true, for every collector
    matchLabels:
      os: linux
    matchExpressions:
      - key: deployment.environment.name
        operator: In
        values: [production]
spec:
  collectorConfig:           # main collector config
    processors:
      batch: {}
  sidecarConfig: {}          # optional
```

Overrides use the same format with `metadata.instanceId` set to the
collector's instance ID and no `target`.

Rules applied during sync:

- A key that is absent leaves the stored value unchanged (for example, a
  policy file without `sidecarConfig` keeps the sidecar config set in the UI).
- Rollout settings (canary, packages) are managed in CollectorCtrl. A policy
  with an active canary is skipped until the canary is promoted or aborted.
- Two files for the same policy or the same collector are both rejected.
- Deleting a file does not delete the policy; the sync summary lists policies
  that exist only in CollectorCtrl.

## Access token

Use a fine-grained personal access token (or a GitHub App token) scoped to the
one repository:

- **Contents: read and write**: sync, export and emergency commits
- **Pull requests: read and write**: proposed changes and status tracking

A read-only token is enough for syncing only. The token is encrypted at rest,
never returned by the API, and bound to the repository and API host it was
saved for: changing either requires entering the token again.

For GitHub Enterprise Server, set the API URL (for example
`https://github.example.com/api/v3`). Loopback, link-local and cloud metadata
addresses are refused.

## Webhook

In the integration editor, enable the webhook and generate a secret. In
GitHub, go to the repository's **Settings > Webhooks > Add webhook**:

- Payload URL: `https://<collectorctrl>/api/git/webhook`
- Content type: `application/json`
- Secret: the generated secret
- Events: **Pushes** and **Pull requests**

Deliveries are accepted only with a valid `X-Hub-Signature-256` for the
repository's secret; others are rejected with 401 and audited. Repeated
delivery IDs are ignored. GitHub needs to reach the server over HTTPS.

## Drift

Drift is any difference between the last synced Git commit and CollectorCtrl,
for example a policy edited in the UI. The **Drift** tab shows each
difference with a diff. The drift policy decides what happens:

- **Report drift** (default): the edit stays until the file changes in Git.
- **Restore Git**: every check re-applies the repository and undoes edits
  made in CollectorCtrl.

## Proposed changes and emergency commits

**Propose a change** (requires fleet configure permission) edits one file and
opens a pull request from a new `collectorctrl/…` branch. CollectorCtrl tracks
the pull request and applies the change after it is merged.

**Emergency commit** (requires fleet control permission) commits one file
directly to the synced branch without review and syncs immediately. A reason
is required and recorded in the commit message and the audit log. Protect the
branch in GitHub if direct commits must never happen; the commit then fails
and nothing changes.

## Status and troubleshooting

The integration shows the last sync time, commit, per-file results and
errors. A sync that starts failing, or recovers, creates a notification. The
audit log records configuration changes, syncs that applied changes, exports,
proposed changes, emergency commits and webhook deliveries.

| Symptom | Cause |
|---------|-------|
| `GitHub rejected the access token (401)` | Token expired or revoked |
| `not found (404)` | Wrong repository name, or the token cannot access it |
| `branch "…" not found` | The branch does not exist yet |
| `the repository is empty` | Create an initial commit first |
| File listed under *Not applied* | Invalid YAML, wrong `kind`/`apiVersion`, missing `metadata.name`, or an invalid target |
| Export or pull request fails with 403 | Token has read-only access |

## API

| Endpoint | Permission |
|----------|-----------|
| `GET/POST /api/system/git/configs`, `DELETE /api/system/git/configs/{id}` | system:git |
| `POST /api/system/git/test`, `/sync`, `/init` (export, `dry_run`) | system:git |
| `GET /api/git/drift`, `/api/git/files`, `/api/git/prs` | fleet:view |
| `GET /api/git/file`, `POST /api/git/propose_change` | fleet:configure |
| `POST /api/git/emergency_sync` | fleet:control |
| `POST /api/git/webhook` | public, signature-verified |

Request and response details are in the [OpenAPI specification](api/openapi.json).
