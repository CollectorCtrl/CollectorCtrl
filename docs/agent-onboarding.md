# Connecting collectors

Every managed host runs the **CollectorCtrl Supervisor** next to an OpenTelemetry Collector. The Supervisor connects to the server over OpAMP, starts and supervises the collector, validates and applies configuration, reports health and effective config, and performs signed upgrades.

- [Prerequisites](#prerequisites)
- [Recommended: the Get Started command](#recommended-the-get-started-command)
- [How enrollment works](#how-enrollment-works)
- [Manual installation](#manual-installation)
- [`supervisor.yaml` reference](#supervisoryaml-reference)
- [Vendor and custom collectors](#vendor-and-custom-collectors)
- [Sidecar collector](#sidecar-collector)
- [Application discovery (ZeroTouch)](#application-discovery-zerotouch)
- [Removing or re-adding a host](#removing-or-re-adding-a-host)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

- An OpenTelemetry Collector binary on the host: upstream `otelcol` / `otelcol-contrib`, a vendor distribution, or a build from the CollectorCtrl **Custom Builder**. The collector should expose its health check extension (`health_check`, port 13133 by default) so the Supervisor can see when it's ready.
- Administrator / root rights to install a service.
- Outbound access from the host to the server on **4320/tcp** (OpAMP) and **4321/tcp** (package downloads).

## Recommended: the Get Started command

1. In the CollectorCtrl UI, open **Get Started**.
2. Create an **enrollment token**. Tokens expire (24 hours by default) and can be limited to a number of uses.
3. Pick the platform and copy the generated command. It already contains the server address, the token and the server's **CA fingerprint**.
4. Run it on the host:
   - **Linux** (as root): runs the script served at `/api/onboard/linux`.
   - **Windows** (elevated PowerShell): runs the script served at `/api/onboard/windows.ps1`.
   - **macOS** (as root): runs the script served at `/api/onboard/mac`, and installs a launchd daemon.

The script then:

1. downloads the server's CA from `/api/onboard/ca.pem` and checks its SHA-256 against the fingerprint in the command (it **aborts if they differ**);
2. downloads the Supervisor package for the host's OS and architecture: first from the server's own package mirror (so hosts without internet access work), otherwise from this repository's GitHub Releases;
3. installs the Supervisor as a service: `collectorctrl-supervisor` (systemd), `CollectorCtrlSupervisor` (Windows) or `com.collectorctrl.supervisor` (launchd);
4. configures `wss://<server>:4320/v1/opamp` with certificate verification switched on, and hands the enrollment token to the service.

The host appears in **Fleet** within a few seconds.

Useful script options:

| Linux / macOS | Windows | Purpose |
| :--- | :--- | :--- |
| `--server-endpoint` / `-e` | `-ServerEndpoint` | OpAMP endpoint, e.g. `wss://cc.example.com:4320/v1/opamp` |
| `--enroll-token` / `-t` | `-EnrollToken` | Enrollment token (`cce_…`) |
| `--ca-sha256` / `-f` | `-CaSha256` | Pin the server CA's SHA-256 fingerprint |
| `--otelcol-binary` / `-b` | `-OtelBin` | Collector executable |
| `--otelcol-config` / `-c` | `-OtelConfig` | Initial collector config file |
| `--version` / `-v` | `-Version` | Supervisor version to install, e.g. `0.5.5-beta` (default: the newest release) |
| `--insecure-skip-verify` | `-InsecureSkipVerify` | Skip certificate verification. **Testing only.** |

> If the server sits behind NAT, a load balancer or Kubernetes, set `COLLECTORCTRL_ADVERTISE_HOST` or `COLLECTORCTRL_OPAMP_ENDPOINT` on the server so the generated commands use an address the hosts can reach. See [Configuration](configuration.md#network-and-urls).

## How enrollment works

Each host gets its **own credential**; there is no fleet-wide password.

1. On first connect the Supervisor presents the enrollment token together with its instance UID.
2. The server issues a per-agent credential (`cca_…`) over the authenticated OpAMP channel. The Supervisor stores it in `<storage>/agent_credential` (readable only by the service) and uses it from then on. The server keeps only a hash.
3. The identity is then locked to that instance UID. A wrong credential, a second enrollment or a shared-secret connection for the same UID is refused and raises a **Possible agent impersonation** notification.

Enrollment tokens can never be used to sign in to the UI or call the API. Manage tokens and credentials under **Settings → API Tokens → Agent Enrollment**.

## Manual installation

Use this for golden images or configuration-management tools (Ansible, SCCM, Group Policy).

**Linux**

```bash
tar -xzf collectorctrl-supervisor_<version>_linux_amd64.tar.gz
sudo ./install.sh \
  --server-endpoint "wss://cc.example.com:4320/v1/opamp" \
  --otelcol-binary /usr/bin/otelcol-contrib \
  --otelcol-config /etc/otelcol-contrib/config.yaml
```

This installs to `/opt/collectorctrl-supervisor` and registers the `collectorctrl-supervisor` systemd service. The archive's installer doesn't configure TLS trust or enrollment, so then:

1. Download the CA and compare its fingerprint with the one shown in the UI:

   ```bash
   curl -k https://cc.example.com:4321/api/onboard/ca.pem -o /opt/collectorctrl-supervisor/collectorctrl-ca.pem
   sha256sum /opt/collectorctrl-supervisor/collectorctrl-ca.pem
   ```

2. In `/opt/collectorctrl-supervisor/supervisor.yaml`, set:

   ```yaml
   server:
     endpoint: 'wss://cc.example.com:4320/v1/opamp'
     tls:
       insecure_skip_verify: false
       ca_file: '/opt/collectorctrl-supervisor/collectorctrl-ca.pem'
   ```

3. Give the service an enrollment token, then restart it:

   ```bash
   sudo systemctl edit collectorctrl-supervisor
   #   [Service]
   #   Environment=COLLECTORCTRL_ENROLL_TOKEN=cce_...
   sudo systemctl restart collectorctrl-supervisor
   ```

**Windows**

Run `collectorctrl-supervisor-setup_<version>_windows_<arch>.exe` as Administrator. It installs to `C:\Program Files\CollectorCtrl Supervisor` and registers the `CollectorCtrlSupervisor` service. Then set the CA and endpoint in `supervisor.yaml` as above, put `COLLECTORCTRL_ENROLL_TOKEN=cce_…` in the service's registry `Environment` value (`HKLM\SYSTEM\CurrentControlSet\Services\CollectorCtrlSupervisor`), and restart the service.

The token is only needed for the first connection. After enrollment you can remove it.

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

labels:                                  # node identity tags, available for targeting and grouping
  environment: production
  region: eu-west-1

capabilities:
  accepts_packages: true                 # allow signed collector / supervisor upgrades

storage:
  directory: '/opt/collectorctrl-supervisor/storage'   # credential, instance ID, state

host_name: 'web-01'                      # optional display name
```

Settings changed in the UI (sidecar, discovery override) are pushed to the Supervisor over OpAMP.

## Vendor and custom collectors

CollectorCtrl manages any collector binary. Distributions that need extra start-up flags or environment variables use `agent.args` and `agent.env`. The Supervisor launches:

```text
<executable> --config <effective.yaml> <args...>
```

on every start, config-reload restart and post-upgrade relaunch. With the Linux installer, pass `--otelcol-args "--feature-gate=xyz --custom_flag 'custom value'"`.

To build a collector with only the components you need, use **Custom Builder** in the UI (it runs the OpenTelemetry Collector Builder, `ocb`). Built packages appear on the **Packages** page, where you sign and roll them out like any other collector package.

## Sidecar collector

The sidecar is a second collector on the same host, supervised separately from the main one. A typical use is to keep a **security / SIEM pipeline** isolated from the **observability pipeline**, with different teams owning each through RBAC.

- Enable and configure it per host on the collector's **Sidecar** tab, or through policies.
- It needs its own executable (`sidecar.executable`); it doesn't fall back to the main collector's binary.
- Starting, stopping, restarting or reconfiguring the sidecar never interrupts the main collector, and a failing sidecar doesn't mark the main collector unhealthy. **Restart Both** restarts the pair.
- Fleet views show sidecar status (Running, Starting, Stopped, Error, Disabled), with **Has sidecar** and **Sidecar issues** filters.

## Application discovery (ZeroTouch)

Discovery is **off by default**. When enabled, the Supervisor periodically lists the host's processes so you can see and instrument applications from **ZeroTouch** in the UI.

- Turn it on or off per host, or in bulk, under **Settings → Supervisor Management**. Changes take effect without restarting the Supervisor, and every toggle is audited. Turning discovery off stops new scans and clears the host's discovered applications.
- For automated deployments you can also set `discovery.enabled: true` in `supervisor.yaml`.
- Command-line arguments that look like secrets are redacted before reports are sent.

ZeroTouch is **alpha**. See [Features](features.md#zerotouch-instrumentation-alpha).

## Removing or re-adding a host

- **Revoke** an agent's credential under **Settings → API Tokens → Agent Enrollment**. The agent is disconnected and its instance UID is blocked.
- To bring a rebuilt host back with its identity, configuration and history, use **Allow re-enroll**, then enroll it again with a new token.
- To start completely fresh on a host, stop the Supervisor, delete `<storage>/instance.id` and `<storage>/agent_credential`, and enroll again.

## Troubleshooting

| Symptom | What to check |
| :--- | :--- |
| Script aborts with a fingerprint mismatch | The CA the server presented doesn't match the pinned fingerprint. Check you're reaching the right server (proxy, DNS) before overriding anything. |
| Host never appears | Can the host reach port 4320? Is the token valid and unexpired? Check **Notifications** for rejected connections. |
| "Possible agent impersonation" notification | Another process presented this host's UID with a different credential. Investigate before re-enrolling. |
| Config push marked **failed** | The collector rejected the config during validation. The error is shown in the UI, and the running config was left unchanged. |
| Collector rolled back on its own | The new config passed validation but crash-looped the collector, so the Supervisor restored the last known good config. |
| Supervisor update refused | Supervisor packages must carry a valid release signature. See [Verifying downloads](verifying-downloads.md). |

Supervisor logs: `journalctl -u collectorctrl-supervisor` (Linux) or `%PROGRAMDATA%\CollectorCtrlSupervisor\supervisor.log` (Windows).
