# Generated release status

**This file is generated. Do not edit it by hand.**
Regenerate with `python3 scripts/generate_docs.py`.

## Release status

- Version: `1.4.1+10`
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
| SBOM SHA-256 | 00d73c9ac3c3de66a7d06e3162c40a543a679193fa813a62259a33de200315ca |

## Test inventory

- Test files: **60**
- Test/testWidgets declarations: **347**
- Real-KDF files: **7**
- Inventory: `docs/testing/test-inventory.json`

A declaration count is not a pass count. Pass/fail evidence comes only from a committed evidence bundle for this exact commit.

## Recorded checks for this commit

| Check | Exit | Duration (s) | Required | Log SHA-256 |
|---|---|---|---|---|
| android-arm64-build | 0 | 317 | yes | — |
| android-signer | 0 | 2 | yes | — |
| android-universal-build | 0 | 543 | yes | — |
| backup-e2e | 0 | 12.13 | yes | 6629cc627168d087 |
| cold-signature | 0 | 5.48 | yes | d1a7cb52ed24b0ce |
| data-boundary | 0 | 8.071 | yes | 3b5c788081aaa22f |
| deb-build | 0 | 16.953 | yes | ad87cf377cc6ea3b |
| deb-signature | 0 | 0.611 | yes | 3243608fad939b34 |
| dependency-audit | 0 | 4.676 | yes | 531db7f60a49620c |
| full-test-suite | 0 | 695.781 | yes | 1bc2f39641595163 |
| identity-negative-tests | 0 | 0.402 | yes | ec361915e8a72349 |
| install-smoke | 0 | 284 | yes | — |
| integration | 0 | 13.801 | yes | d581506f5377a5df |
| license-inventory | 0 | 0.066 | yes | ab9b22cbedaa80d3 |
| linux-build | 0 | 119.427 | yes | ee7e1d90cc6af35a |
| release-evidence | 0 | 0.048 | yes | 3d40456dd12f5b27 |
| release-signing-tests | 0 | 1.369 | yes | 806b2e225357df53 |
| reproducibility | 0 | 262.037 | yes | 1796b1e24fa98789 |
| sbom | 0 | 0.148 | yes | 2eae3b70d7706078 |
| secret-scan | 0 | 3.417 | yes | 7ff728a5877b4846 |
| security-mutation | 0 | 82.11 | yes | d04b5408453d3d8d |
| static-analysis | 0 | 19.286 | yes | 2599b548443a6c2c |
| test-inventory | 0 | 0.093 | yes | 67786091b8099080 |
| token-registry | 0 | 9.117 | yes | 8f0310eb951563c0 |
| ui-contrast | 0 | 30.28 | yes | c3df95d1938aef0b |
| vault-multi-wallet | 0 | 10.275 | yes | 46bee835c0630cf6 |

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
