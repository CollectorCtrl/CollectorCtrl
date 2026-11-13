# Connecting collectors

Every managed host runs the **CollectorCtrl Supervisor** next to an OpenTelemetry Collector. The Supervisor connects to the server over OpAMP, starts and supervises the collector, validates and applies configuration, reports health and effective config, and performs signed upgrades.

- [Prerequisites](#prerequisites)
- [Recommended: the Add collector command](#recommended-the-add-collector-command)
- [How enrollment works](#how-enrollment-works)
- [Hosts that already run a collector](#hosts-that-already-run-a-collector)
- [Manual installation](#manual-installation)
- [Packages for deployment tools](#packages-for-deployment-tools)
- [Labels](#labels)
- [Running without root (Linux)](#running-without-root-linux)
- [Supervisor upgrades](#supervisor-upgrades)
- [`supervisor.yaml` reference](#supervisoryaml-reference)
- [Vendor and custom collectors](#vendor-and-custom-collectors)
- [Sidecar collector](#sidecar-collector)
- [Application discovery (ZeroTouch)](#application-discovery-zerotouch)
- [Removing or re-adding a host](#removing-or-re-adding-a-host)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

- An OpenTelemetry Collector binary on the host: upstream `otelcol` / `otelcol-contrib`, a vendor distribution, or a build from **Catalog → Custom builds**. The Supervisor installer does not install the collector. The Supervisor adds the `health_check` extension to the collector's configuration, listening on `127.0.0.1:13133` by default, and polls it to see when the collector is ready.
- Administrator / root rights to install a service.
- Outbound access from the host to the server on **4320/tcp** (OpAMP) and **4321/tcp** (package downloads).

## Recommended: the Add collector command

1. In the CollectorCtrl UI, click **Add collector** (on **Overview** or **Fleet**). It has three steps: platform, connect, install.
2. Create an **enrollment token**. Tokens expire (24 hours by default) and can be limited to a number of uses.
3. Pick the platform and environment, and copy the generated command. It already contains the server address, the token, the environment and the server's **CA fingerprint**.
4. Run it on the host:
   - **Linux** (as root): runs the script served at `/api/onboard/linux`.
   - **Windows** (elevated PowerShell): runs the script served at `/api/onboard/windows.ps1`.
   - **macOS** (as root): runs the script served at `/api/onboard/mac`, and installs a launchd daemon.

The script then:

1. downloads the server's CA from `/api/onboard/ca.pem` and checks its SHA-256 against the fingerprint in the command (it **aborts if they differ**);
2. downloads the Supervisor package for the host's OS and architecture: first from the server's own package mirror (so hosts without internet access work), otherwise from this repository's GitHub Releases. On Windows it downloads the setup program;
3. downloads the package's release signature from the server (`/packages/<package>.sig`) and compares the package's SHA-256 with it. A mismatch stops the installation before anything is installed. If the server has no signature for the package, the script prints a warning and continues, unless `--require-signature` is set;
4. installs the Supervisor as a service: `collectorctrl-supervisor` (systemd), `CollectorCtrlSupervisor` (Windows) or `com.collectorctrl.supervisor` (launchd). A collector that already runs as its own service is [taken over](#hosts-that-already-run-a-collector);
5. configures `wss://<server>:4320/v1/opamp` with certificate verification switched on, and hands the enrollment token to the service. On Linux and Windows the environment chosen on the page becomes the collector's `deployment.environment` label.

The signature check covers these one-line commands only. A package the host downloads directly from GitHub, because the mirror does not have it, is not checked, and neither are the other install methods on this page.

The host appears in **Fleet** within a few seconds.

Useful script options:

| Linux / macOS | Windows | Purpose |
| :--- | :--- | :--- |
| `--server-endpoint` / `-e` | `-ServerEndpoint` | OpAMP endpoint, e.g. `wss://cc.example.com:4320/v1/opamp` |
| `--enroll-token` / `-t` | `-EnrollToken` | Enrollment token (`cce_…`) |
| `--ca-sha256` / `-f` | `-CaSha256` | Pin the server CA's SHA-256 fingerprint |
| `--otelcol-binary` / `-b` | `-OtelBin` | Collector executable |
| `--otelcol-config` / `-c` | `-OtelConfig` | Initial collector config file |
| `--version` / `-v` | `-Version` | Supervisor version to install, e.g. `0.8.0-beta` (default: the newest release) |
| `--environment` (Linux only) | `-Environment` | Environment reported as the `deployment.environment` label |
| `--require-signature` | `-RequireSignature` | Stop when the server has no release signature for the package |
| `--insecure-skip-verify` | `-InsecureSkipVerify` | Skip certificate verification. **Testing only.** |

> If the server sits behind NAT, a load balancer or Kubernetes, set `COLLECTORCTRL_ADVERTISE_HOST` or `COLLECTORCTRL_OPAMP_ENDPOINT` on the server so the generated commands use an address the hosts can reach. See [Configuration](configuration.md#network-and-urls).

## How enrollment works

Each host gets its **own credential**; there is no fleet-wide password.

1. On first connect the Supervisor presents the enrollment token together with its instance UID.
2. The server issues a per-agent credential (`cca_…`) over the authenticated OpAMP channel. The Supervisor stores it in `<storage>/agent_credential` (readable only by the service) and uses it from then on. The server keeps only a hash.
3. The identity is then locked to that instance UID. A wrong credential, a second enrollment or a shared-secret connection for the same UID is refused and raises a **Possible agent impersonation** notification.

Enrollment tokens can never be used to sign in to the UI or call the API. Manage tokens and credentials under **Settings → Tokens**.

## Hosts that already run a collector

Since v0.8.0-beta the Linux, Windows and macOS supervisor installers find a collector that runs as its own service and uses the executable you named, stop and disable that service, and start the collector under the Supervisor with the same binary and configuration. Before, both collectors ran and competed for the same ports.

- On a terminal the Linux installer asks first. Unattended installs (`--non-interactive`, the **Add collector** commands, the Ansible role) take the collector over without asking.
- `--keep-existing-collector` (Linux, macOS), `/EXISTING_COLLECTOR=keep` (Windows setup program) and `EXISTING_COLLECTOR=keep` (MSI) leave the service alone.
- After a takeover the collector runs as the Supervisor's user (root or LocalSystem by default), not as the service's own account.
- The macOS takeover has not been run on a Mac yet. Try it on one Mac before rolling it out.

More detail, including how to go back: [Enterprise deployment scenarios](enterprise-deployment.md#hosts-that-already-run-a-collector).

## Manual installation

Use this for machine images or configuration-management tools (Ansible, SCCM, Intune, Group Policy). These methods do not check the package's release signature: [verify the download](verifying-downloads.md) yourself.

**Linux**

```bash
tar -xzf collectorctrl-supervisor_<version>_linux_amd64.tar.gz
curl -k https://cc.example.com:4321/api/onboard/ca.pem -o collectorctrl-ca.pem
sha256sum collectorctrl-ca.pem     # compare with the fingerprint shown under Add collector
sudo ./install.sh \
  --server-endpoint "wss://cc.example.com:4320/v1/opamp" \
  --otelcol-binary /usr/bin/otelcol-contrib \
  --otelcol-config /etc/otelcol-contrib/config.yaml \
  --enroll-token cce_... \
  --ca-file collectorctrl-ca.pem
```

This installs to `/opt/collectorctrl-supervisor` and registers the `collectorctrl-supervisor` systemd service.

| Option | Purpose |
| :--- | :--- |
| `--server-endpoint` / `-e` | OpAMP endpoint of the server |
| `--otelcol-binary` / `-b` | Collector executable to supervise |
| `--otelcol-config` / `-c` | The collector's existing configuration file |
| `--otelcol-args` / `-a` | Extra collector start-up flags |
| `--enroll-token` / `-t` | Enrollment token (`cce_…`). It is used once and removed from the host after the server has issued the credential. |
| `--ca-file` | CA certificate of the server. The Supervisor then verifies the server certificate instead of skipping verification. |
| `--label` / `-l` `KEY=VALUE` | A [label](#labels); repeat for more |
| `--keep-existing-collector` | Do not stop and disable a collector service that already runs the same binary |
| `--run-as-user NAME` | [Run without root](#running-without-root-linux) |
| `--no-start` | Install and enable the service but do not start it, for [machine images](enterprise-deployment.md#machine-images) |
| `--non-interactive` / `-y` | Never prompt |

**Windows**

Run `collectorctrl-supervisor-setup_<version>_windows_<arch>.exe` as Administrator. The wizard asks for the server endpoint, the collector path and the enrollment token, registers the `CollectorCtrlSupervisor` service, and confirms that the server accepted the host. For a silent install, pass the same settings as options: `/SERVER_ENDPOINT=`, `/OTEL_BINARY=`, `/OTEL_CONFIG=`, `/OTEL_ARGS=`, `/ENROLL_TOKEN=`, `/CA_FILE=`, `/LABELS=`, `/NOSTART=1`, `/EXISTING_COLLECTOR=keep`.

**macOS**

The macOS installer in the `.tar.gz` takes `--server-endpoint`, `--otelcol-binary`, `--otelcol-config`, `--keep-existing-collector` and `--non-interactive`. It has no label, enrollment-token, CA or image options; the **Add collector** command sets the token and CA for it.

A Supervisor installed without an enrollment token is refused by the server (`401 Unauthorized`) until it gets one.

## Packages for deployment tools

**MSI (SCCM, Intune, Group Policy).** `collectorctrl-supervisor_<version>_windows_<arch>.msi` installs the same Supervisor as the setup program. It has no wizard and takes its settings as properties:

```powershell
msiexec /i collectorctrl-supervisor_<version>_windows_amd64.msi /qn /l*v supervisor-msi.log `
  SERVER_ENDPOINT="wss://cc.example.com:4320/v1/opamp" `
  ENROLL_TOKEN="cce_..." `
  OTEL_BINARY="C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe" `
  OTEL_CONFIG="C:\Program Files\OpenTelemetry Collector\config.yaml" `
  CA_FILE="C:\Windows\Temp\collectorctrl-ca.pem"
```

| Property | Meaning |
| :--- | :--- |
| `SERVER_ENDPOINT` | OpAMP endpoint of the server |
| `OTEL_BINARY` | The collector executable the Supervisor runs |
| `OTEL_CONFIG` | The collector's existing configuration file (optional) |
| `OTEL_ARGS` | Extra collector start-up flags (optional) |
| `LABELS` | `key=value,key2=value2` (optional) |
| `ENROLL_TOKEN` | Enrollment token. It is not written to the MSI log. |
| `CA_FILE` | CA certificate of the server. The installation runs as SYSTEM, so this must be a path SYSTEM can read. |
| `NOSTART=1` | Install the service without starting it |
| `EXISTING_COLLECTOR=keep` | Leave an existing collector service alone |

- The MSI installs to `C:\Program Files\CollectorCtrl Supervisor` and logs its setup steps in `C:\ProgramData\CollectorCtrlSupervisor\setup.log`.
- The MSI and the setup program do not mix: the MSI refuses to install while the setup program's installation is present. Moving from one to the other keeps the identity but not `supervisor.yaml`.
- An MSI upgrade without settings keeps the existing `supervisor.yaml`. The identity and credential are always kept.
- Group Policy software installation cannot pass properties on a command line; put them in a transform (`.mst`).
- The MSI is not Authenticode-signed.

**`.deb` and `.rpm`.** The v0.8.0-beta release notes describe supervisor `.deb` and `.rpm` packages, but the [v0.8.0-beta release page](https://github.com/CollectorCtrl/CollectorCtrl/releases/tag/v0.8.0-beta) does not list any. Use the `.tar.gz` and `install.sh` on Linux.

**Ansible, Packer, cloud-init and Terraform.** v0.8.0-beta adds an Ansible role (`collectorctrl_supervisor`) and Packer, cloud-init and Terraform examples. They are not in this repository; see [collectorctrl.com/docs](https://collectorctrl.com/docs).

## Labels

A label is a `key=value` pair given to the Supervisor installer. The Supervisor reports its labels to the server as attributes of the collector.

| Installer | Option |
| :--- | :--- |
| Linux `install.sh` | `--label KEY=VALUE`, repeated for more |
| Windows setup program | `/LABELS="key=value,key2=value2"` |
| Windows MSI | `LABELS="key=value,key2=value2"` |
| macOS | None yet. Add a `labels:` section to `supervisor.yaml` by hand. |

- The label `deployment.environment` is the collector's environment, unless a classification rule decides otherwise.
- Classification rules (**Settings → Classification rules**) can match any label with the field `attribute.<key>`.
- An attribute the Supervisor or the collector already reports keeps its value.
- Keys may contain letters, digits and `. _ / -`. On Windows a value cannot contain a comma.
- The installers write the labels to the `labels:` section of `supervisor.yaml`. When you run an installer again with settings, pass the labels again.

## Running without root (Linux)

By default the Supervisor service runs as root. With `--run-as-user NAME` the Supervisor and its collector run as an unprivileged system user in a systemd sandbox. This is opt-in, and Linux with systemd only; it was tested on Amazon Linux 2023.

Root stays the default because these need it, and they fail in unprivileged mode:

- instrumenting other services, and relaunching another user's process with instrumentation;
- discovering details of other users' processes;
- collector and sidecar upgrades pushed by the server when the binary is in a system directory such as `/usr/bin`.

The collector also loses root's access: log files it cannot read as that user, ports below 1024, and detail in host metrics of other users' processes. When the host already ran the collector as its own service, use that service's user, for example `--run-as-user otelcol-contrib`. `--run-as-user root` goes back to root.

## Supervisor upgrades

Supervisor upgrades are rolled out from **Settings → Supervisors**. Since v0.8.0-beta an upgrade of two or more supervisors starts with a canary cohort (10%, at least one, one per operating system). The rest wait until every canary reports the new version and has stayed connected for 2 minutes. A canary that fails, falls back or stays disconnected halts the queue with no other supervisor touched. The upgrade queue is kept in the server's memory: after a server restart during a rollout, start the upgrade again. See [Upgrading](upgrading.md#upgrading-supervisors-and-collectors).

## `supervisor.yaml` reference

```yaml
server:
  endpoint: 'wss://cc.example.com:4320/v1/opamp'
  tls:
    insecure_skip_verify: false          # never true in production
    ca_file: '/opt/collectorctrl-supervisor/collectorctrl-ca.pem'

agent:                                   # the main collector
  executable: '/usr/bin/otelcol-contrib'
  config_files:
    - '/etc/otelcol-contrib/config.yaml' # initial / local config, merged with the remote config
  args: []                               # extra command-line flags (see below)
  env: {}                                # extra environment variables for the collector
  health_endpoint: ''                    # collector health URL, if not the default
  stable_window: 5m                      # how long a config must stay healthy to become last known good
  upgrade_stabilization_wait: 0          # seconds to watch a collector after an upgrade before declaring success
  zerotouch_auto_reattach: false         # ZeroTouch: re-instrument apps after they restart (opt-in)

sidecar:                                 # optional second collector, see below
  enabled: false
  executable: '/usr/bin/otelcol-contrib'
  config_file: ''
  args: []
  env: {}
  health_endpoint: none

discovery:
  enabled: false                         # ZeroTouch application discovery (off by default)

labels:                                  # reported to the server as collector attributes, see Labels
  deployment.environment: Production
  region: eu-west-1

packages:                                # optional
  max_download_bytes: 1073741824         # cap for one package download (default 1 GiB)
  download_timeout: 15m                  # default 15 minutes
  systemd_unit: collectorctrl-supervisor.service

distro:                                  # optional: collector distribution profile; defaults fit otelcol-contrib
  package_key: otelcol-contrib           # must match COLLECTORCTRL_COLLECTOR_PACKAGE_KEY on the server
  config_flag: '--config'
  health_check:
    endpoint: '127.0.0.1:13133'

capabilities:
  accepts_packages: true                 # allow signed collector / supervisor upgrades

storage:
  directory: '/opt/collectorctrl-supervisor/storage'   # credential, instance ID, state

host_name: 'web-01'                      # optional display name
```

Settings changed in the UI (sidecar, discovery override) are pushed to the Supervisor over OpAMP. The Supervisor saves the last remote configuration and restores it at start, so a restart while the server is unreachable keeps it.

## Vendor and custom collectors

CollectorCtrl manages any collector binary. Distributions that need extra start-up flags or environment variables use `agent.args` and `agent.env`. The Supervisor launches:

```text
<executable> --config <effective.yaml> <args...>
```

on every start, config-reload restart and post-upgrade relaunch. With the Linux installer, pass `--otelcol-args "--feature-gate=xyz --custom_flag 'custom value'"`.

To build a collector with only the components you need, use **Catalog → Custom builds** in the UI (it runs the OpenTelemetry Collector Builder, `ocb`). Built packages appear under **Catalog → Packages**, where you sign and roll them out like any other collector package.

## Sidecar collector

The sidecar is a second collector on the same host, supervised separately from the main one. A typical use is to keep a **security / SIEM pipeline** isolated from the **observability pipeline**, with different teams owning each through RBAC.

- Enable and configure it per host on the collector's **Sidecar** tab, or through policies.
- It needs its own executable (`sidecar.executable`); it doesn't fall back to the main collector's binary.
- Starting, stopping, restarting or reconfiguring the sidecar never interrupts the main collector, and a failing sidecar doesn't mark the main collector unhealthy. **Restart Both** restarts the pair.
- Fleet views show sidecar status (Running, Starting, Stopped, Error, Disabled), with **Has sidecar** and **Sidecar issues** filters.

## Application discovery (ZeroTouch)

Discovery is **off by default**. When enabled, the Supervisor periodically lists the host's processes so you can see and instrument applications under **Instrumentation** in the UI.

- Turn it on or off per host, or in bulk, under **Settings → Supervisors**. Changes take effect without restarting the Supervisor, and every toggle is audited. Turning discovery off stops new scans and clears the host's discovered applications.
- For automated deployments you can also set `discovery.enabled: true` in `supervisor.yaml`.
- Command-line arguments that look like secrets are redacted before reports are sent.

Instrumentation (ZeroTouch) is **alpha**. See [Features](features.md#instrumentation-alpha).

## Removing or re-adding a host

- **Revoke** an agent's credential under **Settings → Tokens**. The agent is disconnected and its instance UID is blocked.
- To bring a rebuilt host back with its identity, configuration and history, use **Allow re-enroll**, then enroll it again with a new token.
- To start completely fresh on a host, stop the Supervisor, run `collectorctrl-supervisor --config <path to supervisor.yaml> -reset-identity` (`supervisor.exe` on Windows), and enroll again with a new token.

## Troubleshooting

| Symptom | What to check |
| :--- | :--- |
| Script aborts with a fingerprint mismatch | The CA the server presented doesn't match the pinned fingerprint. Check you're reaching the right server (proxy, DNS) before overriding anything. |
| Supervisor log shows `401 Unauthorized` | The Supervisor has no enrollment token, or the token expired or was revoked. Run the installer again with a new token. |
| Host never appears | Can the host reach port 4320? Is the token valid and unexpired? Check **Notifications** for rejected connections. |
| "Possible agent impersonation" notification | Another process presented this host's UID with a different credential. Investigate before re-enrolling. |
| Config push marked **failed** | The collector rejected the config during validation. The error is shown in the UI, and the running config was left unchanged. |
| Collector rolled back on its own | The new config passed validation but crash-looped the collector, so the Supervisor restored the last known good config. |
| Supervisor update refused | Supervisor packages must carry a valid release signature. See [Verifying downloads](verifying-downloads.md). |

Supervisor logs: `journalctl -u collectorctrl-supervisor` (Linux) or `supervisor.log` in the Supervisor's installation folder (Windows).
