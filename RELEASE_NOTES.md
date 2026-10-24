# Release notes

## v0.6.3-beta (23 October 2026)

- **Downloads:** [GitHub release v0.6.3-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.6.3-beta) · every file has a `.sig`, see [Verifying downloads](docs/verifying-downloads.md)
- **All releases, tags and signed files:** [Releases](https://github.com/CollectorCtrl/CollectorCtrl/releases)
- **Upgrading from an earlier version?** Read [docs/upgrading.md](docs/upgrading.md) first.
- **Older releases:** [CHANGELOG.md](CHANGELOG.md)
- **License:** CollectorCtrl is free to use under the [CollectorCtrl Free-to-Use Software License](LICENSE). It is proprietary freeware, not open source.

This release makes environments work the same way everywhere in CollectorCtrl, from the Notification Center to API tokens and alert channels. It also adds safer canary promotions and simpler, verified agent onboarding.

### Highlights

- **Filter notifications by environment.** The Notification Center, the bell count and "Mark read" follow the environment you are working in.
- **Route alerts by environment.** Send Production alerts to PagerDuty and Development alerts to Slack.
- **Environment-scoped API tokens.** Choose an environment when you create a token; the token can only see and act on that environment.
- **Safer canary promotions.** A canary can only be promoted once every collector in the canary group has run the new version and is healthy.
- **Fewer, clearer alerts during outages.** A network blip that disconnects hundreds of collectors produces one alert per environment instead of hundreds.
- **Automatic TLS setup and verified agent onboarding.** Get Started detects the server's address and checks the server's certificate authority before anything is downloaded.

### Notification Center

- **Environment filter.** Pick an environment in the Notification Center. It follows the environment selected on the Fleet page, and you can change it in the panel.
- **Environment on every notification.** Each notification shows the environment it came from. Notifications that apply to the whole installation, such as license, Git sync or rollouts spanning environments, are shown as **Fleet-wide** and appear under every filter.
- **Actions that respect your filter.** With an environment selected, the bell counts that environment, **Mark Read** marks only that environment, and **Clear** keeps fleet-wide history.
- **History kept per environment.** Each environment keeps its latest 250 notifications, so a busy environment can't push another environment's alerts out.
- **New "Other" category** for upgrade, security, Git and AI notifications, which were previously only visible under "All".

### Alert channels

- **Limit a channel to environments.** Each Slack, Microsoft Teams, PagerDuty or webhook channel can receive all environments or only the ones you select. Fleet-wide notifications reach every channel.
- **Environment in every alert.** Slack, Teams, PagerDuty and webhook messages include the environment, and webhooks also include the collector ID.

### Fewer alerts during outages

- When many collectors disconnect or reject a configuration at the same time, CollectorCtrl groups the events for a few seconds. Up to 5 in an environment are reported individually. More than that become one summary, such as "42 collectors disconnected in production", which links to the affected collectors.

### Environment-scoped access

- **Environment field on API tokens.** Create a token for a single environment and see each token's environment in the token list. CollectorCtrl warns you if no collector or rule uses that environment yet.
- **Scope is enforced everywhere.** A token limited to one environment only sees that environment's collectors, notifications, search results and Copilot answers, and can only create tokens for its own environment.
- **Consistent environment names.** `prod`, `Prod` and ` PROD ` are treated as the same environment on every page, filter, policy, token and Copilot tool.

### Fleet Classification Rules

- **Reserved names.** Rules can no longer set the environment to `All`, `unknown` or `default`. Existing rules with these names keep working until you next edit them.
- **One spelling per environment.** If a rule already uses `Production`, a new rule entered as `production` uses `Production` too.
- **Better impact preview.** When a change would leave an environment with no collectors, the preview lists everything that still uses it: API tokens, policies, Governor sources, instrumented applications, agent version overrides and alert channels.
- **"Unclassified" collectors and hosts.** Collectors, discovered hosts and applications without an environment are shown as **Unclassified**.
- The settings page is now called **Fleet Classification Rules**.

### Canary rollouts and policies

- **Every canary collector must check out.** Before a canary can be promoted, every collector in the canary group must be connected, assigned to the policy and running its current version. Otherwise CollectorCtrl explains what is missing, for example "1 have not received this policy". You can still force a promotion, and every forced promotion is recorded in the audit log.
- **Up-to-date acknowledgements only.** A collector that confirmed an older version of the policy no longer counts as up to date, during canaries or waved rollouts.
- **Resuming a paused rollout.** Offline collectors don't block resuming a halted rollout; they receive the new version when they reconnect.
- **Accurate policy preview.** The policy wizard lists exactly the collectors the policy will apply to, including policies that target an environment or role.
- **Agent version overrides follow classification.** Overrides that target an environment now use the environment assigned by your Fleet Classification Rules.

### Automatic TLS setup and agent onboarding

CollectorCtrl now uses the server's detected address automatically and verifies certificate trust before downloading the installer.

- **Automatic server address detection.** Direct VM and EC2 installations need no manual address entry, even when the console is opened through `localhost`. Custom address overrides remain available for load balancers and other network setups.
- **Automatic certificate migration.** Older CollectorCtrl-generated console certificates are replaced with the managed server certificate at startup, so the console and agents trust the same certificate authority. Your existing CA and any custom certificates are preserved.
- **Verified installer downloads.** Linux, macOS and Windows onboarding commands verify the server's CA fingerprint before downloading and running the installation script.
- **Clear installation failures.** Download errors and certificate mismatches stop the installation with a visible error instead of exiting silently.
- **Automation support.** Linux Terraform and cloud-init snippets use the same verified download flow.
- **IPv6 support.** Onboarding commands work with IPv6 server addresses.

### Fixes

- Linux onboarding failed when the HTTPS certificate did not include the server's private IP address.
- Generated onboarding commands hid download errors and could pass an empty response to Bash.
- The CA fingerprint was checked only after the installer had already been downloaded.
- A canary could be promoted while a collector in the canary group was disconnected or had never received the new version.
- The policy wizard could list different collectors than the ones the policy actually applied to.
- Environment filters treated differently capitalized names (`Prod` and `prod`) as different environments on some pages.

### API changes

- `GET /api/notifications` accepts `env` and returns `environment` and `instance_id` for each notification.
- `POST` and `DELETE /api/notifications` accept `env` to mark or clear one environment.
- New `GET /api/notifications/environments` lists the environments that have notifications.
- Alert channels accept `environments` (comma-separated; empty means all).
- Creating an API token returns the token's `environment` and, when relevant, a `warning`.
- The Copilot/MCP `notifications_list` tool accepts an `environment` argument.

### Upgrade notes

- **Deploy and restart.** Deploy the updated server and frontend, then restart the server. Database changes are applied automatically.
- **Generate fresh onboarding commands.** Commands copied from Get Started before this release do not use the verified download flow. Generate a new one. The OpenTelemetry Collector binary and configuration must already exist at the paths you specify. Include an enrollment token to enable agent authentication. Windows hosts need `curl.exe`, which is included in current Windows versions.
- **Older notifications** have no environment and appear as Fleet-wide.
- **Disconnect alerts may arrive a few seconds later** and may be grouped into a summary. Alert rules that match the exact title "Collector Disconnected: …" or "Config Rejection: …" will not match a summary.
- **Environment names are no longer case-sensitive.** A token limited to `prod` now also sees collectors classified as `Prod`. Review your scoped tokens if you used capitalization to separate environments.
- **Unclassified hosts and applications** now report `unknown` instead of `default`. Telemetry Governor S3 archive paths still use `environment=default`.

### Documentation

- **Automatic server addresses and agent onboarding:** address detection, certificate migration, verified installation and optional overrides (`COLLECTORCTRL_ADVERTISE_HOST`, `COLLECTORCTRL_OPAMP_ENDPOINT`, `COLLECTORCTRL_TLS_*`, `COLLECTORCTRL_UI_*`).
- **Uninstall CollectorCtrl on Linux:** removing the server, supervisor and the optional PostgreSQL database.

