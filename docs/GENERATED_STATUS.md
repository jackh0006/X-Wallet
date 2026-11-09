# Generated release status

**This file is generated. Do not edit it by hand.**
Regenerate with `python3 scripts/generate_docs.py`.

## Release status

- Version: `1.4.0+9`
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
| SBOM SHA-256 | 93eaabf6b05811782d60625d8fcf9251330a5208ef727b4e048979968098a222 |

## Test inventory

- Test files: **60**
- Test/testWidgets declarations: **347**
- Real-KDF files: **7**
- Inventory: `docs/testing/test-inventory.json`

A declaration count is not a pass count. Pass/fail evidence comes only from a committed evidence bundle for this exact commit.

## Recorded checks for this commit

| Check | Exit | Duration (s) | Required | Log SHA-256 |
|---|---|---|---|---|
| backup-e2e | 0 | 11.023 | yes | c60e82b5403835e1 |
| cold-signature | 0 | 5.182 | yes | d1a7cb52ed24b0ce |
| data-boundary | 0 | 7.745 | yes | 0b6069e2112161a2 |
| deb-build | 0 | 28.046 | yes | f4b0b5a50a866124 |
| deb-signature | 0 | 0.108 | yes | 023d35ad20fe3864 |
| dependency-audit | 0 | 4.34 | yes | 531db7f60a49620c |
| full-test-suite | 0 | 584.618 | yes | be1f7b784317a40e |
| identity-negative-tests | 0 | 0.547 | yes | c13bc4062bff62d1 |
| install-smoke | 0 | 171 | yes | — |
| integration | 0 | 13.515 | yes | 923fc43acc8ddb66 |
| license-inventory | 0 | 0.334 | yes | ab9b22cbedaa80d3 |
| linux-build | 0 | 113.526 | yes | ceb4fad44ba25641 |
| release-evidence | 0 | 0.048 | yes | 75c22a5e82dc5a26 |
| release-signing-tests | 0 | 1.176 | yes | 48053f9508e2c324 |
| reproducibility | 0 | 244.518 | yes | 22a73dc3c3ba05a0 |
| sbom | 0 | 0.101 | yes | 2eae3b70d7706078 |
| secret-scan | 0 | 3.007 | yes | 7ff728a5877b4846 |
| security-mutation | 0 | 73.021 | yes | d04b5408453d3d8d |
| static-analysis | 0 | 13.198 | yes | c12cfac47c995520 |
| test-inventory | 0 | 0.095 | yes | 616a5e5f2a49ed5b |
| vault-multi-wallet | 0 | 8.776 | yes | 3e963d1d76a1ff77 |
| wallet-vault-normalization | 0 | 10.732 | yes | ad32aea9dfc0568e |

## Artifacts

No release artifact is recorded for this commit. **NOT TESTED.**

## Android signing incident

- Incident status: `OPEN — ROTATION NOT VERIFIED`
- Rotation verified: **NO**
- Denylisted certificates: 1

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
