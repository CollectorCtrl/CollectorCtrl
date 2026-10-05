#!/usr/bin/env python3
"""Verify CollectorCtrl release downloads against their detached .sig files.

Every file attached to a CollectorCtrl GitHub release has a matching
"<file>.sig". This script checks that:

  1. the file's SHA-256 matches the digest recorded in the .sig, and
  2. the Ed25519 signature over that digest verifies against the
     CollectorCtrl release public key.

Usage:
    python3 verify-release.py <file> [<file> ...]
    python3 verify-release.py --key <hex-public-key> <file> ...

Requires Python 3.8+ and the "cryptography" package
(pip install cryptography). Exit code is 0 only if every file verifies.
"""

import argparse
import base64
import hashlib
import json
import sys

# Current CollectorCtrl release public key (Ed25519, hex), used for
# v0.5.3-beta and later. Keys for older releases are listed in
# docs/verifying-downloads.md; pass them with --key.
# Always compare it with an independently trusted copy before relying on it.
RELEASE_PUBLIC_KEY = "cd8f932ebfd0e38a37e1235f4e7a61cb5dd6d8630b6f425b33fbbcf5880c5cde"

# Domain separator used by CollectorCtrl package signatures.
PACKAGE_DOMAIN = b"collectorctrl-package-v1\n"


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def verify(path, public_keys):
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

    try:
        with open(path + ".sig", "r", encoding="utf-8") as f:
            sig = json.load(f)
    except FileNotFoundError:
        return False, "missing " + path + ".sig"
    except (OSError, ValueError) as exc:
        return False, "unreadable signature file: %s" % exc

    signed_digest = str(sig.get("sha256", "")).lower()
    try:
        signature = base64.b64decode(sig.get("signature", ""), validate=True)
    except ValueError:
        return False, "signature is not valid base64"
    if len(signed_digest) != 64 or not signature:
        return False, "signature file has no digest or signature"

    actual_digest = sha256_file(path)
    if actual_digest != signed_digest:
        return False, "file content does not match the signed sha256"

    message = PACKAGE_DOMAIN + signed_digest.encode("ascii")
    for key_hex in public_keys:
        key = Ed25519PublicKey.from_public_bytes(bytes.fromhex(key_hex))
        try:
            key.verify(signature, message)
            return True, "sha256 " + actual_digest
        except InvalidSignature:
            continue
    return False, "signature does not verify against the release key"


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--key",
        default=RELEASE_PUBLIC_KEY,
        help="hex Ed25519 public key; comma-separate several keys during a key rotation",
    )
    parser.add_argument("files", nargs="+", help="downloaded release files (the .sig must sit next to each)")
    args = parser.parse_args()

    keys = [k.strip() for k in args.key.split(",") if k.strip()]
    for k in keys:
        if len(k) != 64:
            parser.error("public key must be 64 hex characters: %r" % k)

    ok_all = True
    for path in args.files:
        if path.endswith(".sig"):
            continue
        ok, detail = verify(path, keys)
        print("%s  %s  (%s)" % ("OK  " if ok else "FAIL", path, detail))
        ok_all = ok_all and ok
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
