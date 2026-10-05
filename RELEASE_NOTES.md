# Release notes

## v0.5.5-beta (1 October 2026)

- **Downloads:** [GitHub release v0.5.5-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.5.5-beta) · every file has a `.sig`, see [Verifying downloads](docs/verifying-downloads.md)
- **Upgrading from an earlier version?** Read [docs/upgrading.md](docs/upgrading.md) first. Upgrades from 0.5.0 or earlier contain breaking changes.
- **Older releases:** [CHANGELOG.md](CHANGELOG.md)

### Highlights

- **Sidecar collectors are visible across the fleet.** The table, honeycomb and topology views now show sidecar status at a glance. Fleets that don't use sidecars see no change.
- **Starting or restarting a sidecar no longer affects the main collector.** The main collector stays healthy throughout; only the sidecar's own status changes.
- **An operations toolkit for AI agents.** 32 new MCP tools and 4 runbook prompts. Agents can follow their proposals to a result, discover configuration templates, read config history with diffs, and change many collectors through policies or GitOps pull requests.
- **App discovery is tighter.** Turning discovery off now really stops the inventory, every toggle is audited, and bulk changes report exactly what was applied.
- **The collector page remembers the Sidecar tab** when you refresh the browser or share a link.

### Fleet views: sidecar collectors

- **Table:** a **Sidecar** column appears automatically once any collector in view has a sidecar, and you can hide it from the column picker. Each cell shows Running, Starting, Stopped, Error or Unknown. Hover for the version and error reason; click to open that collector on its Sidecar tab.
- **Fleet summary:** a **Sidecars** row shows enabled, running, stopped, error and unknown counts. It is separate from the collector health tiles, which still describe the main collector only.
- **Quick filters:** **Sidecar issues** and **Has sidecar**. They are filtered on the server, so they work with paging.
- **Honeycomb:** hosts with a sidecar get a badge on the corner of their hexagon, in the standard status colours and with a symbol, so it doesn't rely on colour alone:
  - green ✓: running
  - grey ■: stopped
  - red !: error
  - dashed grey ?: unknown or starting

  A dark ring keeps it visible on any hexagon, including a green one. A small key explains the badges, and the tooltip includes a sidecar line. Kubernetes cards get a "Sidecar: <status>" badge.
- **Consistent colours everywhere:** the table, summary, topology badges, the topology side panel and the collector page's Sidecar tab all use the same status colours: green for running, red for error, grey otherwise.
- **Topology:**
  - Collector and gateway nodes show a "+ sidecar" badge. Grouped nodes show counts, for example "5 with sidecar · 1 error".
  - The side panel shows the sidecar's status, version and error, with an **Open sidecar** button.
  - The **Issues** filter now includes healthy hosts whose sidecar is failing.
- **Clearer naming:** the classification role for collectors running as a Kubernetes sidecar container is now shown as **K8s sidecar**, so it isn't confused with CollectorCtrl's sidecar collector.

### Collector lifecycle isolation

- **Sidecar start and restart are fully isolated.** Previously the main collector briefly showed as unhealthy, so it looked as if both collectors had restarted. The main collector process was never actually restarted; this was a status-reporting problem.
- **The sidecar shows "Starting"** for up to 20 seconds after it launches, while its health endpoint comes up. If it is still failing after that, it reports an error as before.
- **A failing sidecar never marks the main collector unhealthy.** This applies to:
  - fleet status
  - Copilot and MCP answers
  - the saved health state
  - upgrade verification

  It also applies to supervisors already deployed, once the server is updated.

### Collector detail page

- **The Main/Sidecar tab is kept in the URL** (`?tab=sidecar`), so a refresh or a shared link opens the same tab.
- If a link points to a sidecar that no longer exists, the page falls back to the Main tab.
- Switching tabs doesn't add browser history entries, so **Back** still returns to the fleet.

### AI operations over MCP

New tools, all following the same permissions as the matching API routes:

- **Follow proposals:** `actions_get_status` and `actions_list_mine`. Agents check whether a change was approved, executed, rejected or expired instead of assuming it ran. Each agent sees only its own proposals; approvers see all.
- **Template discovery:** `templates_list`, `templates_get_agents` and `templates_drift` show the distinct configurations running in the fleet, who uses each, and recent drift.
- **Config history:** `config_history_list` and `config_history_get`. The latter includes a diff to the current configuration.
- **Policies:**
  - Read-only: `policies_list`, `policy_get_history`, `policy_effective`, `policy_rollout_status`, `policy_preview_matches` and `policy_validate`.
  - Need approval: `policy_save`, `policy_canary_promote` and `policy_canary_abort`.
- **GitOps:** `git_drift`, `git_list_prs`, and `git_propose_change`, which needs approval and then opens a pull request.
- **Triage and scoping:** `notifications_list`, `environments_list`, `env_rules_list`, `env_rules_preview` and `inventory_facets`.
- **Sidecar:** `sidecar_get_config`, and `sidecar_save_config`, which needs approval. Settings you leave out keep their current value.
- **Upgrades:** `upgrades_status` and `supervisors_check_updates`.
- **Destinations and discovery:**
  - `destinations_list` and `destination_test`. The test is a dry run and saves nothing.
  - `supervisor_set_discovery`, which needs approval.
- **Runbook prompts** (new MCP prompts capability): `triage_unhealthy_collector`, `standardize_config_drift`, `safe_fleet_config_change` and `sidecar_troubleshoot`.

Safety:

- Every change is still a proposal that a person approves in the UI.
- Policy, canary and GitOps proposals are refused for environment-scoped tokens, because a policy can match collectors in any environment.
- The approval limit counts the collectors actually affected: the collectors a policy matches, only the first batch for a canary rollout, and zero for a pull request.
- At approval time the proposal is checked again, so a policy edited in the meantime is never overwritten.
- `fleet_push_config` now points agents to policies or pull requests for changes meant for more than one collector.
- The approvals panel and the Copilot show clear names for the new actions.

### Supervisor management and app discovery

- **Discovery is off by default** (confirmed) and is controlled per supervisor from **Settings → Supervisor Management**.
- **Turning discovery off really stops it.** Reports from a supervisor whose discovery is off are now ignored, so a scan that was already running can't bring the inventory back.
- **Every sidecar or discovery toggle is recorded** in the audit log.
- **Bulk changes report their result.** You now see "Updated discovery for 3 of 5; 2 not found" instead of a blanket success. Requests that change nothing are rejected.
- **The API reference** now describes this endpoint correctly.

### Discovered applications

- **Memory usage has been removed** from discovery, the inventory API and the UI. Resource metrics belong to the collector (`hostmetrics` / `process`), not the control plane, and the scanned value was out of date immediately.

### Notable fixes

- **Notification "View Details" goes to the right place.** Git sync alerts used to land on Fleet Overview; they now open **Settings → Git Integration**. Every notification now links to its details:
  - Collector events (disconnected, config rejected, upgrade failed or rolled back, impersonation attempt) open that collector.
  - Agent baseline, ring override, node pin, catalog upload/delete and reconcile notifications open **Instrumentation → Agent Baselines & Central Catalog**. Most of these had no link before.
  - Instrumentation dispatch notifications open the discovered inventory.

  Notifications already stored with the old link format also open the right page.
- Refreshing the collector page no longer resets the Sidecar tab to Main.
- Opening a different collector no longer carries over a Sidecar tab left in the URL from the previous one.
- Hosts without a sidecar now show **Disabled** instead of **Stopped**, which was indistinguishable from an enabled sidecar that had been stopped.
- The Stop button for a disabled sidecar stays disabled correctly.

### Upgrade notes

- **Deploy the updated supervisor** together with the server for the sidecar "Starting" state.
  - The server-side health fix works with supervisors already in the field.
  - The top-level health error now describes the main collector only. Alert rules that matched the old text "Collectors are not healthy: …" need updating.
- **API changes:**
  - `POST /api/governor/supervisors/configure` returns per-instance results (`updated`, `not_found`, `invalid`, `failed`). It responds 400, 404 or 500 when nothing was applied, and 400 for an empty request. Scripts that assumed it always returns 200 should check the response.
  - Fleet rows (`/api/agents`) include `SidecarEnabled`, and the fleet summary includes `Sidecars` counts. Hosts without a sidecar report `SidecarStatusLabel: "Disabled"` (previously `"Stopped"`).
  - New fleet presets: `preset=sidecar` and `preset=sidecar_issues`.
  - `memory_usage_mb` is no longer included in discovery reports or the inventory API.
- **New audit actions:** `CONFIGURE_SUPERVISORS` and `CONFIGURE_SUPERVISORS_FAILED`.
- **MCP:**
  - The server now advertises prompts in its capabilities.
  - With the default approval limit of 10 collectors, policy saves and canary promotions that match more collectors are refused until an admin raises the limit. GitOps pull requests are not affected.
- **Role label:** only the display name changed to "K8s sidecar". The stored and API value is still `sidecar`.
