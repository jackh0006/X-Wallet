# Supply-chain audit

## Verified

- `pubspec.lock` and `verification/package-lock.json` committed; SBOM is CycloneDX.
- No telemetry/analytics/AI/ads/payment dependencies.
- GitHub Actions are pinned to full commit SHAs; no `pull_request_target`; no repository secrets in workflows.
- Dependabot, dependency-review, CodeQL, secret scan and scheduled security workflows exist.
- `scripts/dependency-audit.py` and `license-check.py` pass in this environment.
- Release artifacts are GPG-signed; the APK signer is pinned and the historical key is denylisted.

## Findings

**HIGH:** `package-smoke.yml` downloads `bnb-wallet-1.0.9-amd64.deb` and installs it as root after only printing its SHA-256. Pin the hash or remove the upgrade leg.

**HIGH:** CodeQL has no Dart target; the main wallet language is not SAST-scanned.

**HIGH:** release gate returns 0 for INCOMPLETE/PARTIALLY VERIFIED and CI does not use `--require-verified`. The identity check does not verify artifact hashes/signatures without `--artifact`.

**MEDIUM:** reproducibility workflow is manual-only and builds the bundle, not the `.deb`; no tag trigger.

**MEDIUM:** CI Android outputs were debug-signed and uploaded as “release” APKs (fixed in this audit branch by removing the upload).

**MEDIUM:** Gradle wrapper distribution is not checksum-pinned; vendored Argon2 CMake lacks hardening flags.

**MEDIUM:** `release/evidence.json` contains 0-second `full-test-suite`/`deb-build` records, a launch-only smoke labelled `install-smoke`, and a stale 1.5.1 `package-smoke.json`.

**LOW:** denylist header still carries an OWNER-ACTION line while the incident record says CLOSED.
