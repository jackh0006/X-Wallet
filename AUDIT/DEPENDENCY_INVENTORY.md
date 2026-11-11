# Dependency inventory

## Direct Dart dependencies

- `web3dart`
- `collection`
- `bip39_mnemonic`
- `bip32_plus`
- `dargon2_flutter`
- `dargon2_core`
- `cryptography`
- `socks5_proxy`
- `flutter_secure_storage`
- `local_auth`
- `qr_flutter`
- `url_launcher`
- `shared_preferences`
- `http`
- `intl`
- `path_provider`
- `crypto`
- `wallet`
- `flutter_localizations`
- `asn1lib`
- `ffi`
- `synchronized`

## Locked Dart packages

`pubspec.lock` contains **116** package entries. The CycloneDX SBOM has 126 components (116 Dart, 9 npm, 1 generic).

## Node verification dependencies

- `ethers` 6.17.0

## Supply-chain controls

- `pubspec.lock` and `verification/package-lock.json` are committed.
- GitHub Actions `uses:` are pinned to full commit SHAs.
- `scripts/dependency-audit.py` and `scripts/license-check.py` run in CI.
- `scripts/sbom.py` writes `docs/SBOM.json`.
- `test/data_boundary_test.dart` rejects telemetry/analytics/AI SDK names in both `pubspec.yaml` and `pubspec.lock`.

## Findings

- No telemetry, analytics, ads, crash reporter, Firebase, AI SDK or payment SDK was found.
- CodeQL does not analyse Dart; the main wallet language is not covered by CodeQL.
- Android CI builds are debug-signed and are no longer uploaded as release artifacts (fixed in this audit branch).
- `package-smoke.yml` downloads `bnb-wallet-1.0.9-amd64.deb` and installs it as root after only printing a hash. **UNVERIFIED / HIGH**: pin the hash.
