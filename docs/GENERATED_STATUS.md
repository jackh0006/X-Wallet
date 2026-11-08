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
| backup-e2e | 0 | 10.82 | yes | 698ade7e217b727c |
| cold-private-key | 0 | 8.358 | yes | 2610eb3d12fa6254 |
| cold-signature | 0 | 5.123 | yes | d1a7cb52ed24b0ce |
| data-boundary | 0 | 7.649 | yes | 0b6069e2112161a2 |
| deb-build | 0 | 28.363 | yes | f41b673e1897f758 |
| deb-signature | 0 | 0.172 | yes | 1255eec026cf1f1d |
| default-tokens | 0 | 7.496 | yes | 666a60ff94d663aa |
| dependency-audit | 0 | 5.212 | yes | 531db7f60a49620c |
| full-test-suite | 0 | 577.79 | yes | 7660785d9edbac50 |
| identity-negative-tests | 0 | 0.358 | yes | 221dba3a6206541e |
| install-smoke | 0 | 144 | yes | — |
| integration | 0 | 9.746 | yes | 923fc43acc8ddb66 |
| legacy-migration | 0 | 7.986 | yes | 38f82daa1e285b28 |
| license-inventory | 0 | 0.354 | yes | ab9b22cbedaa80d3 |
| linux-build | 0 | 111.273 | yes | ceb4fad44ba25641 |
| localization | 0 | 10.181 | yes | 4705d6d50211ad12 |
| password-strength | 0 | 7.429 | yes | f6233533ff2d4c2a |
| public-defaults | 0 | 7.133 | yes | 9b881ac33596ed3a |
| release-evidence | 0 | 0.051 | yes | 12ec0097c3fb6d36 |
| release-signing-tests | 0 | 1.45 | yes | 403e79feabd98396 |
| reproducibility | 0 | 246.573 | yes | 17b7fdce5e5873ef |
| sbom | 0 | 0.115 | yes | 2eae3b70d7706078 |
| secret-scan | 0 | 2.775 | yes | 7ff728a5877b4846 |
| security-mutation | 0 | 69.478 | yes | d04b5408453d3d8d |
| spending-policy | 0 | 8.666 | yes | 41b11ae9362ba0ec |
| static-analysis | 0 | 4.491 | yes | 06df47b141afc20b |
| test-inventory | 0 | 0.091 | yes | e36a43f2200c3c31 |
| vault-multi-wallet | 0 | 11.343 | yes | 6962b10be1fd0ab8 |

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
