# Generated release status

**This file is generated. Do not edit it by hand.**
Regenerate with `python3 scripts/generate_docs.py`.

## Release status

- Version: `1.6.0+18`
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
| SBOM SHA-256 | b561c6680ae3618023fc060fd5ae8c529e68c002364fb53b1ca842624b4a533d |

## Test inventory

- Test files: **73**
- Test/testWidgets declarations: **415**
- Real-KDF files: **7**
- Inventory: `docs/testing/test-inventory.json`

A declaration count is not a pass count. Pass/fail evidence comes only from a committed evidence bundle for this exact commit.

## Recorded checks for this commit

| Check | Exit | Duration (s) | Required | Log SHA-256 |
|---|---|---|---|---|
| cold-signature | 0 | 6.091 | yes | 5575c271e9b604d3 |
| deb-build | 0 | 17.512 | yes | 23dcf8eeac3f5dab |
| deb-signature | 0 | 0.112 | yes | f1ce2d2116953833 |
| dependency-audit | 0 | 4.324 | yes | 531db7f60a49620c |
| full-test-suite | 0 | 276.279 | yes | 2689d6d7394e227b |
| install-smoke | 0 | 13.453 | yes | 2d0a18668930212e |
| license-inventory | 0 | 0.061 | yes | cc8e41a55e00cdea |
| release-evidence | 0 | 0.053 | yes | 3beab56311d33e80 |
| reproducibility | 0 | 420 | yes | 99f8d0d69376f19f |
| sbom | 0 | 0.127 | yes | 2eae3b70d7706078 |
| secret-scan | 0 | 4.942 | yes | 7ff728a5877b4846 |
| static-analysis | 0 | 18.603 | yes | 8fe365348f7141b3 |
| test-inventory | 0 | 0.106 | yes | 0f59b7dd55eabbaa |

## Artifacts

| Artifact | SHA-256 | Signed | Signature verified |
|---|---|---|---|
|  | b55d1f037c3bf71557878329252a57142c782d54aa870d674be0d8e78f6688ef | yes | yes |
|  | 35fd8243140b867acd6a105b664de35cd0adbaaf95025d4219a68013a9eb1156 | yes | yes |
|  | cd55737cdb4be2c04a52cbfb1c67a79318a4345184d8df559f5970bee7e70628 | yes | yes |
|  | cd09963aa5d5dc56cdaf06a6154fc4ac549ba539e7f4b3ac08626de3163471c9 | no | NO |
|  | b561c6680ae3618023fc060fd5ae8c529e68c002364fb53b1ca842624b4a533d | no | NO |

## Android signing incident

- Incident status: `CLOSED — RELEASE SIGNER ROTATED AND DENYLISTED`
- Rotation verified: **yes**
- Denylisted certificates: 1

An Android artifact is never releasable while rotation is unverified or the denylist is empty. See [the incident record](security/INCIDENT_2026-11-KEYSTORE.md).

## Platform compatibility

| Platform | Arch | Package | Build | Install | Functional | Status |
|---|---|---|---|---|---|---|
| Ubuntu 24.04 | x86_64 | .deb / source | PASS | PASS (package smoke, 1.5.3) | NOT TESTED (interactive) | BUILD + PACKAGE ONLY |
| Debian 12 | x86_64 | .deb / source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| Fedora 40 | x86_64 | source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| Linux | arm64 | source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| Windows | x86_64 | source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| macOS | arm64/x86_64 | source | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED |
| Android | arm64-v8a | .apk | PASS | NOT TESTED | NOT TESTED | BUILD + SIGNATURE ONLY |

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

## Open gate problems

- No independent professional audit.
- No independent-machine rebuild.
- No live Ethereum node round-trip or physical Android run.
- No two-device cold-signing test.
- No real screen-reader session.
- Hardware-wallet and multisig custody are not implemented.
- Cold path supports EIP-1559 type-2 only; hot path also supports legacy fees.
- Price/explorer providers still see source IP and queried public addresses.
