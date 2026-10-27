# AGENTS.md

Short guide for AI assistants and new contributors. Full context: [CONTEXT.md](CONTEXT.md).

## What this is

The public CollectorCtrl repository: documentation, release notes, changelog, OpenAPI spec, examples and the
release-signature verification script for a self-hosted, OpAMP-based control plane for OpenTelemetry Collector
fleets. **There is no product source code here** (it is private), and no build or CI.

## Commands

```sh
python3 -c "import json; json.load(open('docs/api/openapi.json'))"   # spec still parses
pip install cryptography && python3 scripts/verify-release.py <file>  # verify a release file and its .sig
docker compose -f examples/docker-compose.yml config                  # example compose is valid (needs .env)
```

## Conventions

- Plain, short sentences; tables over prose; UI paths as **Settings → X**; `example.com` hosts and `<version>` placeholders.
- Say "collectors" in user-facing text. Keep fixed UI/API names exactly as they are (Agent Enrollment, `fleet_*_agent`).
- Name the version for anything version-specific. On a release, update together: README banner, `docs/features.md`, `SECURITY.md`, `RELEASE_NOTES.md`, `CHANGELOG.md`, and `docs/upgrading.md` for breaking changes (⚠️ in CHANGELOG).
- Label maturity: Beta, Alpha, Pilot, Not yet available.
- Weakening switches are always marked "development only" or "testing only".
- Work on a `docs/<topic>` branch and merge via PR.

## Don't change without asking

- `LICENSE`, `NOTICE`, `third_party/licenses/`, and any wording about licensing ("free to use", "not open source").
- Release public keys or the signing domain in `docs/verifying-downloads.md` and `scripts/verify-release.py` (they must stay in sync).
- `docs/api/openapi.json`: it is generated from the server; don't hand-edit.
- Security claims and defaults in `docs/security.md`, `SECURITY.md` and the hardening checklist.
- Feature-maturity labels, performance/load-test figures and release dates.
- `examples/docker-compose.yml` secret handling (required `.env` values, unpublished PostgreSQL port).
- Links to GitHub Releases, GHCR image names and the K8s operator repo.

Never commit tokens (`cce_…`, `cca_…`, `cc_…`), keys, real hostnames, customer names or business/ownership details.
