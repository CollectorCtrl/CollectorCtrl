# Enterprise deployment scenarios

Three situations that come up when CollectorCtrl is rolled out across an existing estate, as of **v0.8.0-beta**. This page is a summary. The full guides are at [collectorctrl.com/docs](https://collectorctrl.com/docs).

- [Hosts that already run a collector](#hosts-that-already-run-a-collector)
- [Machine images](#machine-images)
- [Air-gapped sites](#air-gapped-sites)

Installer options used below are described in [Connecting collectors](agent-onboarding.md).

---

## Hosts that already run a collector

The Supervisor does not replace your OpenTelemetry Collector. It runs the collector you already have: the same executable, started with the same configuration file, as a child process it can restart, reconfigure and upgrade.

A collector installed from the upstream packages runs as its own service (`otelcol-contrib.service` on Linux, the `otelcol-contrib` Windows service). Two collectors from the same executable would compete for the same ports, so the Supervisor installer takes the collector over:

1. It finds the service whose command line runs the collector executable you named (`--otelcol-binary`, or the collector path in the Windows wizard).
2. Just before the Supervisor starts, it stops and disables that service. The executable and the configuration file are not touched.
3. On Linux it copies the service's `Environment=` and `EnvironmentFile=` settings to a systemd drop-in for the Supervisor, so a configuration that reads `${env:NAME}` keeps working. On macOS it copies the job's `EnvironmentVariables`.
4. The Supervisor starts the collector with your existing configuration. The name of the replaced service is written to `replaced-collector-units` (Linux), `replaced-collector-services` (Windows) or `replaced-collector-jobs` (macOS) in the Supervisor's storage directory.

The collector is down for the few seconds between steps 2 and 4.

- **Unattended installs take over without asking.** On a terminal the Linux installer asks before step 2. `--non-interactive`, the **Add collector** commands and the Ansible role do not ask.
- **To leave the existing service alone,** pass `--keep-existing-collector` (Linux, macOS), `/EXISTING_COLLECTOR=keep` (Windows setup program) or `EXISTING_COLLECTOR=keep` (MSI), and stop one of the two collectors yourself.
- **macOS** covers LaunchDaemons, LaunchAgents and Homebrew services. The macOS takeover has not been run on a Mac yet; it was tested with stand-ins for the launchd tools. Try it on one Mac before rolling it out.

What changes for the collector:

| | Before | With the Supervisor |
| :--- | :--- | :--- |
| Started by | Its own service | The Supervisor service |
| Runs as | The service's account (often `otelcol-contrib`) | The Supervisor's account: root or LocalSystem by default |
| Configuration | The local file | The local file, merged with what the server pushes. Remote keys win. |
| Logs | The service's journal or event log | The Supervisor's log and journal |

Because the collector then runs as the Supervisor's user, files it creates (a `file_storage` directory, for example) belong to that user from then on. On Linux, `--run-as-user` keeps the collector under an unprivileged account; see [Running without root](agent-onboarding.md#running-without-root-linux).

**Going back:** remove the Supervisor, then re-enable the services named in the `replaced-collector-*` file, for example `sudo systemctl enable --now otelcol-contrib.service` on Linux, or `sc.exe config otelcol-contrib start= auto` and `Start-Service otelcol-contrib` on Windows.

## Machine images

Every Supervisor has an identity: an instance ID it creates on its first start, and a credential the server issues for that ID when it enrolls. Both live in the Supervisor's storage directory. An image that contains them makes every machine created from it present the same identity, and the server sees one collector or reports impersonation.

The rule: **the image contains the Supervisor, but no identity.** Each machine creates its own on first boot and enrolls with an enrollment token.

**Build the image** by installing without starting the service:

```bash
# Linux
sudo ./install.sh --no-start \
  --server-endpoint wss://cc.example.com:4320/v1/opamp \
  --otelcol-binary /usr/bin/otelcol-contrib \
  --otelcol-config /etc/otelcol-contrib/config.yaml \
  --ca-file collectorctrl-ca.pem
```

```powershell
# Windows
.\collectorctrl-supervisor-setup_<version>_windows_amd64.exe /VERYSILENT /SUPPRESSMSGBOXES /NOSTART=1 `
  /SERVER_ENDPOINT="wss://cc.example.com:4320/v1/opamp" `
  /OTEL_BINARY="C:\Program Files\OpenTelemetry Collector\otelcol-contrib.exe" `
  /CA_FILE="C:\build\collectorctrl-ca.pem"
```

The service is installed and enabled, so it starts on the first boot of each machine. With the MSI, use `NOSTART=1`; with the Ansible role, `collectorctrl_supervisor_no_start: true`.

**If the Supervisor has already run** on the machine you capture, remove its identity as the last step, with the service stopped:

```bash
sudo systemctl stop collectorctrl-supervisor
sudo /opt/collectorctrl-supervisor/collectorctrl-supervisor \
  --config /opt/collectorctrl-supervisor/supervisor.yaml -reset-identity
```

On Windows, stop the `CollectorCtrlSupervisor` service and run `supervisor.exe -config <path to supervisor.yaml> -reset-identity` from the installation folder.

**Give each machine its enrollment token.** The Supervisor reads the token from the `enroll_token` file in its storage directory, or from `COLLECTORCTRL_ENROLL_TOKEN`, and deletes the file once the server has issued the machine its credential.

- **At first boot (recommended).** Keep the token out of the image and write it when the machine is created, from user data or your secrets manager. With cloud-init:

  ```yaml
  #cloud-config
  write_files:
    - path: /opt/collectorctrl-supervisor/storage/enroll_token
      permissions: "0600"
      content: cce_...
  ```

  The token can then be short-lived and replaced without rebuilding the image.
- **In the image.** Pass `--enroll-token` (or `/ENROLL_TOKEN=`) together with `--no-start`. The token is then readable by anyone who can read the image, and it must stay valid for as long as machines are created from it. Revoke it under **Settings → Tokens** when the image is retired.

Each machine reports its real host name, which [Classification rules](features.md#fleet-management) can match. To set the environment or role from the image instead, use [labels](agent-onboarding.md#labels).

## Air-gapped sites

CollectorCtrl does not need the internet to run. A few conveniences fetch from GitHub when they can, and each has an offline path:

| What | Reaches | Offline |
| :--- | :--- | :--- |
| Server: package mirror sync | GitHub, at start and every 6 hours | Set `COLLECTORCTRL_PACKAGE_SYNC=false` and fill the mirror yourself (below). |
| One-line install commands | GitHub to look up the release, then the server mirror, then GitHub | Work from the mirror alone once it is filled. |
| Package, Ansible and Installer snippets in **Add collector** | Download URLs on `github.com` | Replace the URL with the mirror URL. |
| Copilot, web search | The provider you configure | Off until configured. The provider base URL can point at an internal gateway. |
| Custom builds | The Go module proxy | Set `GOPROXY` to an internal proxy, or don't use the builder. |
| Linux PostgreSQL installer | Your OS package repositories | Use an internal repository mirror, or install PostgreSQL yourself and use the plain server archive with `COLLECTORCTRL_DB_TYPE=postgres`. |

The Windows server installer with PostgreSQL carries the PostgreSQL installer inside it and downloads nothing.

**Bring in the software.** On a connected machine, download the server, the supervisor packages for your platforms and their `.sig` files from the [Releases](https://github.com/CollectorCtrl/CollectorCtrl/releases) page, and [verify them](verifying-downloads.md). For Windows hosts take both `collectorctrl-supervisor-setup_<version>_windows_amd64.exe` (the setup program the install command runs) and `collectorctrl-supervisor_<version>_windows_amd64.exe` (the bare binary, used for upgrades pushed by the server). The Supervisor installer does not install the collector, so bring that too if hosts don't have it.

**Fill the package mirror.** The server serves a directory at `https://<server>:4321/packages/`, and the install commands download the supervisor from it before trying GitHub. There are two ways to fill it:

- **Upload in the web console** under **Settings → Supervisors**. A Linux or macOS release archive uploaded under its release file name is stored for upgrades and for the install commands. The Windows setup program is stored for the install commands only; upload the plain supervisor `.exe` for upgrades. Upload each package's `.sig` with it.
- **Copy files by hand** into the directory set with `COLLECTORCTRL_PACKAGES_DIR`, under both the release name and a name without the version (for example `collectorctrl-supervisor_linux_amd64.tar.gz`), which is what an install command asks for when it cannot look the version up. Copy each package's `.sig` next to it under the same two names.

The directory is served without authentication, like a package repository. Put only installable packages in it.

**Signatures.** From v0.8.0-beta the server no longer mirrors a supervisor package whose release signature is missing or invalid, and serves `/packages/<package>.sig` only when it is a valid release signature of that package. Without a `.sig` on the mirror, the one-line install commands print a warning and install; with `--require-signature` (`-RequireSignature` on Windows) they stop. See [Checks at install time](verifying-downloads.md#checks-at-install-time).

**Proxies.** Hosts that reach the server through a proxy: set `HTTPS_PROXY` (and `NO_PROXY`) in the Supervisor service's environment, for example in a systemd drop-in.

**Upgrades.** Upload the new supervisor binary and its `.sig` under **Settings → Supervisors** and roll it out from there. Upload collector packages under **Catalog → Packages** and approve them with **Sign**. For the server, install the new version over the old one; see [Upgrading](upgrading.md).
