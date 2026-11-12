# Release Process

**Status:** process definition. No release is approved by this document.

## Preconditions

1. Clean working tree on the release branch.
2. Version in `pubspec.yaml` matches `docs/releases/<version>.md`.
3. Android signing incident is closed, or the release contains no Android
   artifact and says so.
4. Owner has approved the release and the signing key/host.
5. `release/manifest.json`, `docs/testing/test-inventory.json`, SBOM, and
   generated docs are current.

## Required commands

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
bash scripts/test-suite.sh
bash scripts/secret-scan.sh
(cd verification && npm ci && node verify.cjs)
python3 scripts/dependency-audit.py
python3 scripts/license-check.py
python3 scripts/sbom.py --out docs/SBOM.json
python3 scripts/test_inventory.py --check
python3 scripts/check_release_evidence.py
python3 scripts/release_manifest.py --check
python3 scripts/generate_docs.py --check
python3 scripts/check_release_identity.py
python3 scripts/test_release_identity.py
python3 scripts/security_mutation_check.py
bash scripts/run-anvil-tests.sh
bash scripts/test_release_signing.sh
bash scripts/test_android_inventory.sh
```

Record each result with `scripts/record_check.py`; never paste a result that a
command did not produce.

Package smoke and reproducibility:

```bash
# On a disposable Ubuntu 24.04 runner with root/apt:
bash scripts/package-smoke.sh \
  --deb "dist/x-wallet-<version>-amd64.deb" \
  --previous previous-1.0.9.deb \
  --seconds 20

# Fixed absolute path is required: Flutter embeds it.
BNB_REPRO_PATH=/tmp/bnb-repro-final \
  bash scripts/reproducibility-check.sh <commit>
```

## Build and sign

```bash
# Build from the exact candidate commit.
flutter build linux --release
bash scripts/build-deb.sh

# Owner-controlled release host only:
export BNB_GPG_KEY='<approved fingerprint or UID>'
gpg --batch --yes --detach-sign --armor \
  --default-key "$BNB_GPG_KEY" \
  "/home/mhh06/Downloads/X Wallet/x-wallet-<version>-amd64.deb"
```

Run `scripts/check_release_identity.py --artifact <deb>` before signing. The
`.deb`, `.asc`, and `SHA256SUMS` must all be produced from the same source
commit. See `docs/SIGNING_CHECKLIST.md` for the owner procedure. If documentation changed after the build, rebuild or explicitly record
which documentation is not in the package.

## Verify

```bash
sha256sum --check SHA256SUMS
gpg --verify x-wallet-<version>-amd64.deb.asc x-wallet-<version>-amd64.deb
dpkg-deb -c x-wallet-<version>-amd64.deb
python3 scripts/release-gate.py --require-verified
```

A clean Ubuntu install/launch/upgrade/uninstall result is mandatory for a
`VERIFIED` release.

## Status rules

- `VERIFIED`: every mandatory gate passed for the exact commit and artifact.
- `PARTIALLY VERIFIED`: some gates pass, at least one mandatory gate is absent.
- `INCOMPLETE`: evidence has not been collected.
- `FAILED`: a gate failed or a blocking vulnerability exists.
- `BLOCKED`: an owner-controlled action (key rotation, signature, approval)
  prevents release.

Never publish a `PARTIALLY VERIFIED`, `INCOMPLETE`, `FAILED`, or `BLOCKED`
artifact as production-ready.

## Publication (owner only)

1. Tag the exact commit with a signed tag. Keep the tested code commit
   fetchable with a signed `tested-x.y.z` tag; the evidence ancestry check
   needs it.
2. Upload the `.deb`, `.asc`, `SHA256SUMS`, SBOM, manifest, test summary, and
   known limitations together.
3. State the reproducibility constraint and independent-audit status.
4. Publish the signing-key fingerprint through an independent channel.
5. Re-verify the published assets:
   `bash scripts/verify-release-assets.sh vX.Y.Z /tmp/assets`.
6. Move `stable` to the release commit, or to a later commit whose only
   differences are docs/release tooling; never move a published tag.
