# Generated release status

**This file is generated. Do not edit it by hand.**
Regenerate with `python3 scripts/generate_docs.py`.

## Release status

- Version: `1.3.0+7`
- Exact source commit: recorded in `release/evidence.json` when a release bundle is published. It is deliberately not embedded here, because a document cannot contain the hash of the commit that contains it.
- Status: **RELEASE APPROVED**

Status meanings: `VERIFIED` requires every source and release check; `PARTIALLY VERIFIED` means source checks passed but a release-only check is missing; `INCOMPLETE` means a required result is absent; `FAILED` means a recorded check or artifact failed.

## Source and toolchain

| Item | Value |
|---|---|
| Flutter | Flutter 3.47.6 • channel stable • https://github.com/flutter/flutter.git |
| Dart | Dart SDK version: 3.13.5 (stable) (Tue Sep 29 01:00:52 2026 -0700) on "linux_x64" |
| pubspec.lock SHA-256 | c1c31c95438e44de4172d2b27a759bda13fd305981a0bf0dbac32d2868d49e24 |
| verification/package-lock.json SHA-256 | ad659384d423e91d21aab1d3f7b32d73eb78f6019effa9f6c6b638031363e5e7 |
| SBOM SHA-256 | 2441d9b89371b182a7a5f22e4def2dfbef892e9d35ef8b4b8ecaf9d86dcb1f45 |

## Test inventory

- Test files: **59**
- Test/testWidgets declarations: **342**
- Real-KDF files: **7**
- Inventory: `docs/testing/test-inventory.json`

A declaration count is not a pass count. Pass/fail evidence comes only from a committed evidence bundle for this exact commit.

## Recorded checks for this commit

| Check | Exit | Duration (s) | Required | Log SHA-256 |
|---|---|---|---|---|
| backup-e2e | 0 | 12.885 | yes | e88446990daf2af0 |
| cold-signature | 0 | 5.971 | yes | 87d225095d2a70a4 |
| data-boundary | 0 | 8.527 | yes | 0b6069e2112161a2 |
| deb-build | 0 | 34.458 | yes | 96d731661c0a623c |
| deb-signature | 0 | 0.187 | yes | 50bd6f7befeae07e |
| dependency-audit | 0 | 28.526 | yes | 531db7f60a49620c |
| full-test-suite | 0 | 673.834 | yes | 3d2bc88a77bc4547 |
| identity-negative-tests | 0 | 0.366 | yes | b758e321d4c54be6 |
| install-smoke | 0 | 151 | yes | — |
| integration | 0 | 27.645 | yes | 923fc43acc8ddb66 |
| license-inventory | 0 | 0.091 | yes | ab9b22cbedaa80d3 |
| linux-build | 0 | 18.971 | yes | ceb4fad44ba25641 |
| localization | 0 | 13.322 | yes | 4705d6d50211ad12 |
| release-evidence | 0 | 0.05 | yes | 3b852b7433b74e16 |
| release-signing-tests | 0 | 2.094 | yes | 041275c000cd6e48 |
| reproducibility | 0 | 256.453 | yes | 7c9274c7f3bec4d3 |
| sbom | 0 | 0.124 | yes | 2eae3b70d7706078 |
| secret-scan | 0 | 3.373 | yes | 7ff728a5877b4846 |
| security-mutation | 0 | 96.641 | yes | d04b5408453d3d8d |
| spending-policy | 0 | 34.543 | yes | 41b11ae9362ba0ec |
| static-analysis | 0 | 12.95 | yes | 970df57c6e2a6895 |
| test-inventory | 0 | 0.107 | yes | 53ba54fdb93550bc |

## Artifacts

No release artifact is recorded for this commit. **NOT TESTED.**

## Android signing incident

- Incident status: `OPEN — ROTATION NOT VERIFIED`
- Rotation verified: **NO**
- Denylisted certificates: 0

An Android artifact is never releasable while rotation is unverified or the denylist is empty. See [the incident record](security/INCIDENT_2026-11-KEYSTORE.md).

## Platform compatibility

| Platform | Arch | Package | Build | Install | Functional | Status |
|---|---|---|---|---|---|---|
| Ubuntu 24.04 | x86_64 | .deb / source | PASS | NOT TESTED | NOT TESTED | BUILD + PACKAGE ONLY |
| Debian 12 | x86_64 | .deb / source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| Fedora 40 | x86_64 | source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| Linux | arm64 | source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| Windows | x86_64 | source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| macOS | arm64/x86_64 | source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| Android | arm64-v8a | .apk | BLOCKED | BLOCKED | BLOCKED | BLOCKED |

## Performance

Measured on: architecture=x86_64, cpuCount=2, dart=3.13.5, flutter=3.47.6 stable, kernel=7.0.0-42-generic, memoryGiB=3.8, os=Ubuntu 24.04.5 LTS

| Benchmark | Value | Unit | Status | Evidence |
|---|---|---|---|---|
| Argon2id 64 MiB, t=3, p=4 (native reference library) | 0.344 | s | MEASURED | tool/argon2_probe.dart, 2026-11-06 |
| Argon2id 64 MiB, t=3, p=4 (debug pure-Dart fallback) | 110 | s | MEASURED | test/vault_test.dart timing before native wiring, 2026-11-06 |
| Application startup to first frame | — | s | NOT TESTED | needs an X/Wayland session and a packaged build |
| Resident memory while idle | — | MiB | NOT TESTED | needs an X/Wayland session and a packaged build |
| Wallet derivation (BIP-39 to first address) | — | ms | NOT TESTED | planned |

## Honest limitations

- This project is self-assessed. It has **not** been independently audited.
- No automated test, signature, or score can guarantee the safety of funds.
- A compromised operating system, malware, or a stolen unlocked session can defeat a local hot wallet.
- Android releases are blocked until the historical signing key is rotated and denylisted.
- Full limitations: [docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md)

## Evidence files

- Manifest: `release/manifest.json`
- Checks: `release/checks.json`
- Artifacts: `release/artifacts.json`
- Test inventory: `docs/testing/test-inventory.json`
- SBOM: `docs/SBOM.json`
