# Verifying downloads

Every file on the [Releases](https://github.com/CollectorCtrl/CollectorCtrl/releases) page, from **v0.5.1-beta** onwards, has a detached signature next to it: `<file>.sig`. Check it before you install a server or supervisor, or upload a package to CollectorCtrl.

## What a signature file contains

```json
{
  "sha256": "<hex SHA-256 of the file>",
  "signature": "<base64 Ed25519 signature>"
}
```

The signature is an Ed25519 signature, made with the CollectorCtrl release key, over the bytes:

```text
collectorctrl-package-v1\n<sha256 hex>
```

A file verifies only if its SHA-256 matches the `sha256` field **and** the signature verifies against the release public key.

## Release public keys

| Releases | Ed25519 public key (hex) |
| :--- | :--- |
| v0.5.3-beta and later | `cd8f932ebfd0e38a37e1235f4e7a61cb5dd6d8630b6f425b33fbbcf5880c5cde` |
| v0.5.2-beta | `1bff4168b179adce0781b93dbf3ef115de821e9bf65a6152af24dbc10c9d8f78` |
| v0.5.1-beta | `7202077ce0fc6670d1db81b955c9becfb509a2813ae68b606706e15a3f07c17b` |

`cd8f932e…` is the **long-term release key** from v0.5.3-beta on. If it ever has to change, the new key will be announced in advance, and releases will trust both keys during the changeover.

Compare the key with a copy from a second channel you trust (for example [collectorctrl.com](https://collectorctrl.com)) before relying on it. A signature checked only against a key downloaded from the same place as the file proves little.

## Verify with the script in this repository

[`scripts/verify-release.py`](../scripts/verify-release.py) needs Python 3.8+ and the `cryptography` package.

```bash
pip install cryptography
curl -fsSLO https://raw.githubusercontent.com/CollectorCtrl/CollectorCtrl/main/scripts/verify-release.py

# Download the file and its .sig into the same folder, then:
python3 verify-release.py collectorctrl-supervisor_0.6.3-beta_linux_amd64.tar.gz
# OK    collectorctrl-supervisor_0.6.3-beta_linux_amd64.tar.gz  (sha256 e1ab9efa…)
```

The script uses the current release key by default. For older releases pass the matching key: `--key <hex>`.

## Verify with OpenSSL 3

```bash
F=collectorctrl-supervisor_0.6.3-beta_linux_amd64.tar.gz
KEY=cd8f932ebfd0e38a37e1235f4e7a61cb5dd6d8630b6f425b33fbbcf5880c5cde

# 1. The file must match the signed digest
SIGNED=$(python3 -c "import json;print(json.load(open('$F.sig'))['sha256'])")
[ "$(sha256sum "$F" | cut -d' ' -f1)" = "$SIGNED" ] && echo "digest OK"

# 2. The signature must verify against the release key
python3 - "$F" <<'EOF'
import base64, json, sys
d = json.load(open(sys.argv[1] + ".sig"))
open("sig.bin", "wb").write(base64.b64decode(d["signature"]))
open("msg.bin", "wb").write(b"collectorctrl-package-v1\n" + d["sha256"].encode())
EOF
python3 -c "import sys;sys.stdout.buffer.write(bytes.fromhex('302a300506032b6570032100' + '$KEY'))" > pub.der
openssl pkey -pubin -inform DER -in pub.der -out pub.pem
openssl pkeyutl -verify -pubin -inkey pub.pem -rawin -in msg.bin -sigfile sig.bin
# Signature Verified Successfully
```

## Packages inside CollectorCtrl

When you upload a **supervisor** package under **Settings → Supervisor Lifecycle Management → Package Repository**, upload its `.sig` too. Supervisors install supervisor updates only with a valid release signature. For **collector** packages from other vendors, compare the SHA-256 shown in the **Sign** dialog with the checksum the vendor publishes before you approve it.

## Software bill of materials (SBOM)

From **v0.6.3-beta**, the server and supervisor archives and binaries on the [Releases](https://github.com/CollectorCtrl/CollectorCtrl/releases) page have an SBOM next to them: `<file>.spdx.json`, in [SPDX 2.3](https://spdx.github.io/spdx-spec/v2.3/) JSON. `SBOM-SHA256SUMS.txt` lists the checksum of each SBOM.

Each SBOM lists the Go standard library version and every Go module compiled into that binary, with its version and a package URL (`pkg:golang/...`). The top-level package records the SHA-256 of the release file, so you can match the SBOM to the file you downloaded, and the source revision the binary was built from.

Load the SBOMs into Dependency-Track, Grype or Trivy to check for known vulnerabilities:

```bash
grype sbom:collectorctrl-server_0.6.3-beta_linux_amd64.tar.gz.spdx.json
trivy sbom collectorctrl-server_0.6.3-beta_linux_amd64.tar.gz.spdx.json
```

In v0.6.3-beta, the Windows installers (the server `.exe` files and `collectorctrl-supervisor-setup_*.exe`) don't have their own SBOM, and server SBOMs list Go modules only. From the next release:

- every Windows installer has an SBOM;
- server SBOMs also list the web UI's npm packages, and the PostgreSQL installers list the bundled PostgreSQL;
- each SBOM is signed like the other release files (`<file>.spdx.json.sig`);
- the Docker images carry an SBOM and a cosign signature.
