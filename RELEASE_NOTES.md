# Release notes

## v0.8.0-beta (12 November 2026)

- **Downloads:** [GitHub release v0.8.0-beta](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.8.0-beta) · every file has a `.sig`, see [Verifying downloads](docs/verifying-downloads.md)
- **All releases, tags and signed files:** [Releases](https://github.com/CollectorCtrl/CollectorCtrl/releases)
- **Upgrading from an earlier version?** Read [docs/upgrading.md](docs/upgrading.md) first.
- **Older releases:** [CHANGELOG.md](CHANGELOG.md)
- **License:** CollectorCtrl is free to use under the [CollectorCtrl Free-to-Use Software License](LICENSE). It is proprietary freeware, not open source.
- **Published files:** the release page carries the supervisor MSI for amd64 and arm64. It does not list the supervisor `.deb` and `.rpm` packages described below; use the `.tar.gz` on Linux.

This release is about **putting CollectorCtrl into an enterprise that already runs collectors**: installers that take over an existing collector, packages for the usual deployment tools, machine images, air-gapped sites, and safer defaults from the first sign-in to supervisor upgrades. It also carries the **redesigned web console**.

### Highlights

- **Adopts hosts that already run a collector.** The Linux, Windows and macOS supervisor installers find a collector that runs as its own service, stop and disable it, and start it under the Supervisor with the same binary and configuration. Before, both collectors ran and competed for the same ports.
- **Packages for deployment tools.** The supervisor now ships as an MSI for SCCM, Intune and Group Policy, next to the tarballs and the Windows setup program, and can be built as `.deb` and `.rpm` (not attached to this release; see Known issues). An Ansible role and Packer, cloud-init and Terraform examples are available; see the [documentation](https://collectorctrl.com/docs).
- **No well-known passwords.** Server installers on Windows and Linux ask for the administrator password (or generate one) on a first install; `admin` / `admin` is gone. The bundled PostgreSQL gets a generated password on both platforms.
- **Enrollment built into the installers.** The supervisor installers ask for the enrollment token and confirm that the server accepted the host, so a directly installed supervisor no longer sits at `401 Unauthorized`.
- **Verified packages and canary upgrades.** The server checks the release signature of every supervisor package it mirrors, the install commands check the package against it, and a supervisor upgrade now starts with a canary cohort and halts if a canary fails.
- **A redesigned web console.** One design system, job-based navigation, an Overview page, and rebuilt Fleet, Rollouts, Approvals, Templates, Custom builds and Add collector screens.
- **Governance is its own section, with one sampling rate.** "Telemetry" is now **Governance**, and **Instrumentation** is a separate section. The Governor samples every tapped collector and every external source at one global rate, so Insights compares like with like.

### Installing the server

- **Administrator password at install time.** The Windows installers have an Administrator Account page (`/ADMIN_PASSWORD=` for silent installs). The Linux scripts take `--admin-password-file` or `COLLECTORCTRL_ADMIN_PASSWORD`, prompt on a terminal, or generate a password and print it once. Upgrades keep the existing accounts.
- **Bundled PostgreSQL.** Windows: the superuser password is generated and saved in `C:\ProgramData\CollectorCtrl\postgres-superuser-password.txt` (Administrators and SYSTEM only); a reinstall reuses that instance. Setup refuses to touch a PostgreSQL it did not install, and stops on a data directory left behind by an earlier installation, with a message saying what to do. Linux: the script creates a `collectorctrl` role with a generated password that owns the database, and no longer alters the `postgres` superuser.
- **Windows installers.** No console windows during install or uninstall, the service is confirmed running before setup reports success, an upgrade offers "Keep the current database configuration", and a setup log is written.
- **Kubernetes.** The server manifest runs in production mode, so the first administrator password is generated.

### Installing supervisors

- **Existing collectors.** See Highlights. Linux carries the service's `Environment=` / `EnvironmentFile=` settings over; macOS carries `EnvironmentVariables` over and covers LaunchDaemons, LaunchAgents and Homebrew services. `--keep-existing-collector` (Linux, macOS) and `/EXISTING_COLLECTOR=keep` (Windows) leave the service alone. See [Hosts that already run a collector](docs/enterprise-deployment.md#hosts-that-already-run-a-collector).
- **Enrollment token.** `--enroll-token` (Linux), an Enrollment page and `/ENROLL_TOKEN=` (Windows), `ENROLL_TOKEN=` (MSI). The token is used once and removed from the host after the server has issued its credential.
- **Server certificate.** `--ca-file` (Linux), `/CA_FILE=` (Windows) and `CA_FILE=` (MSI) make the supervisor verify the server certificate instead of skipping verification.
- **Machine images.** `--no-start` / `/NOSTART=1` / `NOSTART=1` install the service without starting it, so the image holds no identity. `collectorctrl-supervisor -reset-identity` removes the identity from a machine that already ran. See [Machine images](docs/enterprise-deployment.md#machine-images).
- **Labels.** `--label KEY=VALUE` (Linux), `/LABELS=` (Windows), `LABELS=` (MSI) and `collectorctrl_labels` (Ansible) set labels that the supervisor reports as collector attributes. A `deployment.environment` label is the collector's environment; classification rules can match any label with `attribute.<key>`. See [Labels](docs/agent-onboarding.md#labels).
- **Add collector uses the chosen environment.** The Linux and Windows one-line commands and the Windows "Installer" steps install the collector with the environment selected on that page as its `deployment.environment` label.
- **Running without root (Linux, opt-in).** `--run-as-user NAME` runs the supervisor and its collector as an unprivileged user in a systemd sandbox. Root stays the default, because instrumenting other services, relaunching other users' processes and upgrading a collector binary in a system directory need it. See [Running without root](docs/agent-onboarding.md#running-without-root-linux).
- **Add collector snippets.** Every install method now carries the enrollment token; the Ansible playbooks and the Compose file parse again; the Windows snippets download the setup program (not the bare binary) and use the real service name.

### Packages

- **`.deb` and `.rpm`** of the supervisor (amd64 and arm64). They deliver the files; `collectorctrl-supervisor-setup` configures and starts the supervisor with the installer's options. A package upgrade replaces the binary and keeps the configuration and identity. The `.rpm` payload is gzip so that RHEL 7 and Amazon Linux 2 can install it.
- **MSI** of the supervisor (amd64) with the setup program's options as properties: `SERVER_ENDPOINT`, `OTEL_BINARY`, `OTEL_CONFIG`, `OTEL_ARGS`, `LABELS`, `ENROLL_TOKEN` (kept out of the MSI log), `CA_FILE`, `NOSTART`, `EXISTING_COLLECTOR`. See [Packages for deployment tools](docs/agent-onboarding.md#packages-for-deployment-tools).
- **Ansible role** `collectorctrl_supervisor`: installs from the server mirror or a local file, with token, CA, takeover, labels, image-build and unprivileged options. A second run changes nothing.

### Air-gapped sites

- **The mirror also carries the Windows setup program**, which is what the Windows install command runs.
- **Uploads fill the mirror.** A Linux or macOS release archive uploaded under Supervisors is also served to the install commands, and the Windows setup program can be uploaded for them. Before, the packages directory had to be filled by hand.
- **Proxy settings** are honoured by the discovery report and agent asset downloads.
- See [Air-gapped sites](docs/enterprise-deployment.md#air-gapped-sites).

### Release signatures at install time

- The server is built with the same release keys as the supervisor. For every supervisor package it mirrors from GitHub it verifies the `.sig` and keeps the package only if it passes.
- `/packages/<package>.sig` is answered only when it is a valid release signature of that package, also for a mirror filled by hand or through an upload.
- The Linux, macOS and Windows install commands compare the package's SHA-256 with that signature and stop on a mismatch before anything is installed. `--require-signature` (`-RequireSignature` on Windows) also stops when the server has no signature for the package.
- See [Checks at install time](docs/verifying-downloads.md#checks-at-install-time).

### Supervisor

- **Upgrades start with canaries.** An upgrade of two or more supervisors goes to a small cohort first (10%, at least one, one per operating system). The rest wait until every canary reports the new version and has stayed connected for 2 minutes. A canary that fails, falls back or stays disconnected halts the queue with no other supervisor touched, and the Supervisors page says why.
- **Upgrades run unattended.** The upgrade queue advances on the server; it no longer depends on the Supervisors page being open.
- **Pushed configuration survives a restart.** The last remote configuration is saved and restored at start, so a restart while the server is unreachable keeps it.
- **Real host names.** The packaged `supervisor.yaml` no longer sets `linux-node-01` / `macos-node-01`, and those two placeholder values are ignored on existing installs.
- **Telemetry tap samples logs without a trace ID.** Logs from `filelog`, `windowseventlog`, `syslog` and similar receivers carry none and were dropped by the sampler, so Telemetry Insights received nothing from them. On otelcol-contrib 0.88 and newer they are now sampled.

### Web console

- **Design system and navigation.** One visual system across the app and navigation organised by job. The legacy stylesheets are gone.
- **Overview.** A first-run page with the server's address, Add collector and a setup checklist; a summary page afterwards.
- **Fleet.** One filter bar, an attention line that links to what needs a person, compact one-line rows, fifty rows per page. The honeycomb view is replaced by Map.
- **Rollouts and Approvals.** One table in priority order with an attention strip, a page per rollout with promote, resume and abort, and "Create policy from pattern".
- **Catalog.** Templates and Custom builds are rebuilt around one list each, with a guided "New build" dialog.
- **Add collector.** Three steps: platform, connect, install. Environments come only from the server.
- **Environment scope.** The scope in the top bar now applies on every page.
- **Notification Center.** A timeline grouped by day with the clock time of each event, a severity dot, and filters for Critical, Warning, Info and Unread. Back-to-back repeats of one event fold into one row with a count. Opening a row shows the full message in place and marks it read. Toast and desktop-alert preferences moved into a settings menu.
- **Catalog · Packages.** Rebuilt to match Custom builds: search, filters for type, OS and trust, and a full-width table that shows the signer, signing date and SHA-256 (click to copy). Upload is a dialog. Deleting a package now asks for confirmation, and a failed delete or a failed load is reported instead of looking like an empty repository. Versions sort numerically.

### Governance

- **Governance and Instrumentation in the side menu.** The former Telemetry section is split in two. Old links (`?view=telemetry`, `data_wizard`, `zerotouch`) open the matching section. Governance is shown to users with the Governor view permission.
- **One global sampling rate.** Governance · Configuration has a single "Sampling rate" (default 10%). It replaces the per-collector rate inputs, the bulk rate, and the rate choice in "Add source". Changing it asks for confirmation and re-configures every tapped collector. A custom tap template can no longer override it.
- **External sources report their rate.** The configuration generated for an external source uses the global rate and reports it with every request. The Sources list shows each source's rate and flags one that differs, for example "25% (global is 10%)", or "Not reported" for a source still on an older configuration. The server cannot change a configuration you deployed: copy the current one from the source's Details to bring it in line.
- **Insights shows when counts are not comparable.** A notice appears when the global rate changed inside the selected range, and when sources in scope report different rates.
- **Log sampling for external sources.** The generated configuration now samples logs per record, as managed taps do, when every collector behind the source is known to be OpenTelemetry Collector Contrib 0.88.0 or newer. Before, logs without a trace ID (filelog, journald, syslog) were dropped or kept wholesale. For an older or unknown collector the configuration is unchanged and the page says so.
- **Bounded Insights queries.** A pattern or overview query reads at most the newest 100,000 records in scope (`COLLECTORCTRL_GOVERNOR_QUERY_SCAN_LIMIT`) and says when the range holds more. Identical queries within 30 seconds are answered from memory.
- **Ingest under load.** The tenant daily quota is decided by one atomic database update instead of a lock and a sum on every request, and its `429` carries `Retry-After`. A saturated ingest gate answers `429` before any accounting is written. Record timestamps outside the retention window or more than five minutes ahead are clamped. Stored log bodies are truncated to a fixed size.
- **Ingest metrics.** The Governor's ingest and forwarding counters are exported as Prometheus gauges named `collectorctrl_governor_*`.
- **Chart colours.** Trend charts in Insights use a dedicated set of series colours in both themes; green, amber and red are no longer used to tell sources apart.

### Fixes

- The Add collector PowerShell command failed to download the installer from a server with its own CA (Windows curl could not check revocation).
- The Windows install script's release lookup always failed once the CA was pinned, so only the version-less mirror name was tried.
- `collectorctrl-supervisor -reset-identity` only worked when run from the install directory.
- The Linux and macOS supervisor installers overwrote `sidecar.health_endpoint` with the OpAMP address.
- A first Windows supervisor install got one service restart action where an upgrade got three.
- Windows installer messages pointed to a supervisor log file that does not exist.
- A relaunch of another user's process could stop it and then refuse to start it again.
- The supervisor reported a correct systemd unit as `Restart=loaded` at every start.
- An identity file the service user cannot read silently gave the host a new identity on every start; it is now logged as an error.
- Refreshing a Governance Insights page opened a different page, because the page was dropped from the address.
- Rule simulation, AI pattern rules, the tap list and the tap toggle ignored the caller's environment scope.
- A request body that failed to decode was written to the server log in full.
- An `error`-level notification was not shown as critical, and any notification with "timeout" in its title was.
- Catalog · Packages sorted versions as text, so 0.99.0 ranked above 0.116.0.

### API changes

- `GET /api/governor/supervisors`: new field `upgrade_note` (waiting for the canaries, or why the queue halted).
- `POST /api/governor/supervisors/upgrade`: new field `skip_canary` (boolean) to upgrade every supervisor at once.
- `POST /api/governor/supervisors/packages/upload`: accepts the Windows setup program (stored for the install commands only) and returns `install_names`, and `install_only` for the setup program.
- `GET /packages/<package>.sig` returns 404 unless the signature verifies with the release keys.
- `/api/onboard/linux` and `/api/onboard/windows.ps1`: new script options `--environment` / `-Environment` and `--require-signature` / `-RequireSignature`; `/api/onboard/mac` gains `--require-signature`.
- Supervisor command line: `-reset-identity`, and `supervisor.exe setup` (what the MSI runs).
- `GET` / `POST /api/governor/tap-config`: new field `sampling_percentage` (the global rate; `POST` accepts it alone or with `custom_yaml`), and read-only `previous_sampling_percentage` and `sampling_changed_at`.
- `POST /api/governor/taps/toggle` and `POST /api/templates/tap`: `sampling_rate` is ignored. `GET /api/governor/taps` returns the global rate as `sampling_rate` on every row.
- `GET /api/governor/source-config`: the `sampling` parameter is ignored; the response gains `sampling_percentage` and `log_record_sampling`.
- `GET /api/governor/sources`: new field `sampling_percentage` (the rate the source reports; 0 until it reports one).
- `GET /api/governor/insights/overview`: new fields `sampling_percentage`, `previous_sampling_percentage`, `sampling_changed_at`, `truncated` and `scan_limit`. Pattern responses carry `X-Analysis-Truncated`.
- MCP: the `governor_set_sampling` tool is removed. A proposal for it created before the upgrade fails when approved.

### Upgrade notes

- **Unattended installs take over an existing collector.** `--non-interactive`, the Add collector commands and the Ansible role stop and disable a collector service that runs the same binary, without asking. Pass `--keep-existing-collector` / `/EXISTING_COLLECTOR=keep` to prevent it. After a takeover the collector runs as the Supervisor's user (root or LocalSystem by default), not as the service's own account.
- **Supervisor upgrades take longer.** A rollout to two or more supervisors waits at least two minutes for the canary stage, and stops if a canary fails. Use `skip_canary` to get the old behaviour.
- **Labels become attributes.** A `supervisor.yaml` that already has a `labels:` section reports those labels as collector attributes after the supervisor is upgraded. An attribute the supervisor or the collector already reports keeps its value.
- **Collectors installed from Add collector report an environment.** The page preselects an environment, and the Linux and Windows commands now pass it on. Classification rules still take precedence.
- **The mirror refuses unsigned packages.** A server from this release no longer mirrors a supervisor package whose release signature is missing or invalid. On an air-gapped server, copy each package's `.sig` next to it, or the install commands print a warning (and stop with `--require-signature`).
- **Host names may change.** Linux and macOS hosts that reported `linux-node-01` or `macos-node-01` now report their real host name.
- **Linux server with PostgreSQL.** A database from an earlier install is transferred to the new `collectorctrl` role. A connection you configured yourself is kept.
- **MSI and setup program do not mix.** The MSI installs to `C:\Program Files\CollectorCtrl Supervisor` and refuses to install while the setup program's installation is present. Moving from one to the other keeps the identity but not `supervisor.yaml`.

- **Per-collector sampling rates are gone.** Every tapped collector moves to the global rate (10% unless you change it) the next time its configuration is generated. If you ran collectors at different rates, Insights counts change at the upgrade.
- **External sources keep their old rate until you update them.** Copy the configuration from the source's Details into its collector again. Until then the source shows as "Not reported" or with its own rate.
- **Bookmarks to Governance.** Links that used `view=patterns` inside Insights now use `panel=patterns`.
- **Notification Center.** Clicking a notification opens its detail; "View details" inside it goes to the page. Opening a notification marks it read.

### Verified

- Windows Server 2025: the SQLite and PostgreSQL server installers (fresh install, upgrade, reinstall, uninstall), the supervisor setup program (wizard and silent options) and the MSI (install, all properties, upgrade, failed-install rollback, uninstall).
- Amazon Linux 2023 under systemd: the three install scripts, takeover of the `otelcol-contrib` package's service, `--no-start`, `-reset-identity`, the Ansible role, the `.deb` (built and installed in a Debian 12 container) and the `.rpm` (installed, upgraded and removed with `dnf`).
- Signature checks against the published 0.7.3-beta packages with the real release key, including a server built with a wrong key and a package altered on the mirror.
- A canary rollout across one Windows and one Linux supervisor, and a rollout of a wrongly signed build that halted at the canary.
- A supervisor self-upgrade while running as an unprivileged user.

### Known issues

- **macOS collector takeover has not run on a Mac.** It was exercised under bash 3.2 with stand-ins for `launchctl`, `PlistBuddy` and `plutil`. Try it on one Mac before rolling it out.
- **The Windows setup program and MSI are not Authenticode-signed.**
- **Signature checks cover the one-line install commands only.** The "Package", Ansible and "Installer" snippets, the `.deb` / `.rpm` / `.msi` packages and a hand-run `install.sh` do not check, and a package a host downloads directly from GitHub (because the mirror does not have it) is not checked.
- **Unprivileged mode is Linux with systemd only**, and was tested on Amazon Linux 2023. In that mode a collector upgrade pushed from the server fails when the collector binary is in a system directory.
- **The supervisor upgrade queue is kept in memory.** A server restart during a rollout forgets it; start the upgrade again.
- **No `.deb` or `.rpm` is attached to this release.** Those packages are produced by the Release workflow, which did not run for this version; the files on the release page were built and signed on the release machine. The MSI is published for amd64 and arm64. Use the tarballs with `install.sh` on Linux until the packages are published.
- **No container images are published for this version yet.** The image workflow did not run for the `v0.8.0-beta` tag, so `latest` still points to the previous release.
- The macOS installer has no label, enrollment-token, CA or image options; the Add collector command sets the token and CA for it.
- **Governance has not been load-tested.** Samples are stored one row per record in the server's database. The new query bound, cache and ingest changes reduce the load, but no capacity figure for large fleets is published yet.
- **Per-record log sampling for external sources was not run against a real collector.** It is covered by tests of the generated configuration only.
- **Deleting a package does not check whether collectors or rollouts still use it.** The confirmation says so.
