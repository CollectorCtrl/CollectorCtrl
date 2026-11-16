# Release notes

## v0.8.3-beta (16 November 2026)

- **Downloads:** [GitHub release v0.8.3-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.8.3-beta) · every file has a `.sig`, see [Verifying downloads](docs/verifying-downloads.md)
- **All releases, tags and signed files:** [Releases](https://github.com/CollectorCtrl/CollectorCtrl/releases)
- **Upgrading from an earlier version?** Read [docs/upgrading.md](docs/upgrading.md) first. If you come from 0.7.x or earlier, also read the [v0.8.0-beta notes](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.8.0-beta): that release changed the installers, supervisor upgrades, the web console and Governance sampling.
- **Older releases:** [CHANGELOG.md](CHANGELOG.md)
- **License:** CollectorCtrl is free to use under the [CollectorCtrl Free-to-Use Software License](LICENSE). It is proprietary freeware, not open source.
- **Published files:** server and supervisor archives and installers for Windows, Linux and macOS (amd64 and arm64), and the supervisor MSI for amd64 and arm64. The release page does not list supervisor `.deb` or `.rpm` packages; use the `.tar.gz` on Linux.

This release shows **where your telemetry ends up**, puts **hosts and Kubernetes in one Fleet list**, and makes **instrumentation safer**.

### Topology: see where your data ends up

- A new summary at the top of the **Topology** view shows the path from applications, through collectors, to each destination as flow bands.
- Destinations are grouped by vendor and region, so the same exporter sending to two regions shows as two destinations instead of a tangle of lines.
- Collectors that forward to a gateway are linked to that gateway by its address.
- Kubernetes collectors and instrumented workloads appear in the topology.
- A new warning flags a collector that sends data nowhere outside the host.

### Fleet: one list for hosts and Kubernetes

- "Fleet inventory" is merged into **Fleet**. Kubernetes collectors sit in the same list, with cluster and namespace filters.
- The Kubernetes collector detail is a single, shorter page.
- Columns have a default set and a **Reset to default** option.

### Kubernetes: pods with several containers (operator)

These changes are in the [Kubernetes operator](https://github.com/CollectorCtrl/CollectorCtrl-K8s-Operator).

- Every Java container in a pod is instrumented, not only the first. Each gets its own service name.
- The container annotation accepts a comma-separated list to target specific containers.
- Readiness changes reach the console as they happen, instead of every five minutes.

### Safer instrumentation *(alpha)*

- **Environment limits are enforced.** A user limited to one environment can no longer instrument, remove, deliver agents, pin versions or reconcile on hosts in another. This applies to the console and the MCP tools. Fleet-wide settings need access to all environments.
- **Crash protection covers startup failures.** If a Linux service fails to start after being instrumented, the agent is removed at the next scan. The service is not restarted; the console says why and what to do.
- **Honest removal reports.** If crash protection cannot remove the agent, the console says so instead of reporting it removed.
- **Remove always works,** including while the crash lock is on.
- **Windows folders are locked down.** The Supervisor's storage folder is limited to SYSTEM and Administrators; the agent folder is read-only for other users.
- **No secrets in conflict details.** Only the variable name is sent, never its value.

### Fixed

- A rejected agent delivery showed as "Restart needed"; it now shows as failed.
- An IIS application keeps a stable identity across pool recycles.
- First-time **Instrument** now delivers the agent automatically.

### Changed

- macOS support is labelled experimental in the console and the guide.

### Upgrade notes

- **Environment-limited users and tokens.** Instrumentation actions on hosts outside the caller's environment are refused, in the console and through MCP. Fleet-wide instrumentation settings need access to all environments. Review roles and tokens that relied on the old behaviour.
- **Fleet inventory.** The separate inventory page is gone; use **Fleet** with the Hosts / Kubernetes switch and the cluster and namespace filters.

### Known limits

- Checks for another vendor's agent can report "clean" wrongly in some cases (unreadable process environment, Node and Python variables, Windows service accounts).
- Crash protection does not yet cover a Windows service that fails at startup, or a standalone process that dies within seconds of a restart.
- Workload-to-collector links in the Kubernetes topology depend on the operator reporting each collector's Services.
- These notes do not withdraw any known issue listed for [v0.8.0-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.8.0-beta); read that list too.
