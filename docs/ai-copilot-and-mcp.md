# AI Copilot and MCP

CollectorCtrl is built to be operated by people **and** AI agents, with the same guardrails for both. There are two ways in:

- the **Copilot**, a chat assistant inside the CollectorCtrl UI;
- the **MCP server**, so external assistants (Claude Desktop, Cursor, your own agents) can work with your fleet.

Both follow one rule: **AI can read and propose; only a person can approve a change.**

---

## The approval model

1. Any tool that would change state (push a config, restart a collector, save a policy, promote a canary, open a pull request…) creates a **pending action** instead of running.
2. The proposal records the exact change, a diff where relevant, and its **blast radius**: how many collectors it would affect.
3. A signed-in person reviews it in **Settings → Pending AI Actions** and approves or rejects it.
4. The approver needs the `mcp:approve` permission **and** the permission and environment scope of the underlying action. With **Four-Eyes Approval** enabled, the proposer can't approve their own action.
5. At approval time the proposal is checked again (a policy edited in the meantime isn't overwritten), and the action runs at most once. Proposals expire after 15 minutes.

There is no MCP tool for approving, and the approval endpoint rejects API tokens, so an AI client can never approve its own proposal. Proposals that would affect more collectors than the configured limit (10 by default) are refused until an administrator raises it.

Unattended automation can be allowed explicitly: it needs `COLLECTORCTRL_MCP_AUTO_APPROVE=true` (or the runtime setting) **and** the `mcp:auto-approve` permission, which no built-in role has.

---

## Copilot

Open the Copilot from anywhere in the UI, or from the configuration editor with a collector's config already attached.

- **Answers from live data:** fleet health, collector details and logs, configurations and history, templates and drift, policies and rollouts, audit, and Telemetry Governor analytics.
- **Shows its work:** answers stream in live, and each tool call appears as a step.
- **Fast to drive:** `/` slash commands, `@` mentions of collectors, policies and pipelines, edit-and-regenerate, and a panel you can dock beside your work.
- **Proposes changes** with diffs and blast radius, for approval as described above.

### Model providers

Configure the model in **Settings → AI**:

| Provider | Notes |
| :--- | :--- |
| OpenAI | API key and model name |
| Anthropic | API key and model name |
| Google Gemini | API key and model name |
| **Custom (OpenAI-compatible)** | Any endpoint that speaks the OpenAI chat API: self-hosted models, internal gateways, or your organization's approved provider. Set the base URL, key and model. |

Settings include **PII redaction** and optional web search. API keys are encrypted at rest. Because CollectorCtrl is self-hosted, prompts go only to the provider you configure.

---

## MCP server

- **Endpoint:** `POST https://<server>:4321/api/mcp` (JSON-RPC 2.0 over HTTPS)
- **Auth:** `Authorization: Bearer <API token>`. Create a token under **Settings → SSO & Tokens → API Tokens** and give it the least-privileged role that works.
- **Audit:** every call is logged with actor `mcp:<username>`, the tool, its arguments and its duration.
- **Capabilities:** tools and prompts.

### Connect Claude Desktop or Cursor

Desktop clients that only speak stdio use the `collectorctrl-mcp` adapter, which forwards each request to the server's `/api/mcp` endpoint.

> The adapter isn't included in the release downloads yet. Until it is, email [connect@collectorctrl.com](mailto:connect@collectorctrl.com) for a build, or use a client that can call the HTTP endpoint directly (below).

```json
{
  "mcpServers": {
    "collectorctrl": {
      "command": "/path/to/collectorctrl-mcp",
      "args": ["--server-url", "https://cc.example.com:4321", "--api-token", "cc_your_token"]
    }
  }
}
```

The adapter uses the operating system's certificate store. Either serve the UI with a certificate your machines already trust, or add the CollectorCtrl CA (`/api/onboard/ca.pem`) to the trust store. On Linux and macOS you can instead point `SSL_CERT_FILE` at a bundle that contains it.

Restart the client and ask: *"List my CollectorCtrl tools."*

### Direct HTTP

```bash
curl -s -X POST https://cc.example.com:4321/api/mcp \
  --cacert collectorctrl-ca.pem \
  -H "Authorization: Bearer cc_your_token" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

### Tools

Read tools need the same permission as the matching API route. Tools marked **approval** create a pending action.

| Area | Tools |
| :--- | :--- |
| Fleet | `fleet_list_agents`, `fleet_get_agent`, `fleet_health_summary`, `fleet_get_logs`, `fleet_get_samples`, `environments_list`, `inventory_facets`, `notifications_list` |
| Lifecycle (**approval**) | `fleet_start_agent`, `fleet_stop_agent`, `fleet_restart_agent`, `fleet_start_sidecar`, `fleet_stop_sidecar`, `fleet_restart_sidecar` |
| Configuration | `fleet_preview_config`, `fleet_validate_ottl`, `config_history_list`, `config_history_get`; **approval:** `fleet_push_config`, `fleet_rollback_config`, `fleet_canary_rollout` |
| Policies | `policies_list`, `policy_get_history`, `policy_effective`, `policy_rollout_status`, `policy_preview_matches`, `policy_validate`; **approval:** `policy_save`, `policy_canary_promote`, `policy_canary_abort` |
| Templates and drift | `templates_list`, `templates_get_agents`, `templates_drift` |
| GitOps | `git_drift`, `git_list_prs`; **approval:** `git_propose_change` |
| Sidecar | `sidecar_get_config`; **approval:** `sidecar_save_config` |
| Upgrades and packages | `fleet_list_packages`, `fleet_get_build_status`, `upgrades_status`, `supervisors_list`, `supervisors_check_updates` |
| Telemetry Governor | `governor_volume`, `governor_cardinality`, `governor_templates`, `governor_engine_status`, `destinations_list`, `destination_test`; **approval:** `governor_set_sampling`, `governor_toggle_tap` |
| Discovery and instrumentation | `discovery_reports`, `instrumentation_list_apps`, `instrumentation_get_rollout_status`, `instrumentation_get_version_policy`; **approval:** `supervisor_set_discovery` and the instrumentation version and pinning tools |
| Classification | `env_rules_list`, `env_rules_preview` |
| Proposals | `actions_get_status`, `actions_list_mine` |
| Audit | `audit_query` |

Run `tools/list` against your server for the authoritative list, with input schemas.

### Runbook prompts

| Prompt | Purpose |
| :--- | :--- |
| `triage_unhealthy_collector` | Find why a collector is unhealthy and propose the smallest safe fix |
| `standardize_config_drift` | Find collectors off the standard template and bring them back through a policy |
| `safe_fleet_config_change` | Roll out a change with validation, a canary and verification |
| `sidecar_troubleshoot` | Diagnose a failing sidecar without touching the main collector |

**Recommended agent workflow:** read state → validate → propose through a policy or pull request (canary for risky changes) → poll `actions_get_status` until it resolves → verify → report.

### Safety notes

- Policy, canary and GitOps proposals need an **unscoped** token, because a policy can match collectors in any environment.
- For changes meant for more than one collector, prefer `policy_save` or `git_propose_change` over per-collector `fleet_push_config`.
- Responses are capped at 120 KB. Narrow the query if a response says it was truncated.

### Troubleshooting

| Symptom | Fix |
| :--- | :--- |
| HTTP 401 | Check the `Authorization: Bearer cc_…` header, or regenerate the token. |
| JSON-RPC `-32003 Forbidden` | The token's role lacks the tool's permission. |
| JSON-RPC `-32601` | Unknown tool name. Run `tools/list`. |
| Client can't connect | The path is `/api/mcp`, and the client must trust the server's CA. |
