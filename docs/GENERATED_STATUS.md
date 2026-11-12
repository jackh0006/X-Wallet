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
- Test/testWidgets declarations: **414**
- Real-KDF files: **7**
- Inventory: `docs/testing/test-inventory.json`

A declaration count is not a pass count. Pass/fail evidence comes only from a committed evidence bundle for this exact commit.

## Recorded checks for this commit

| Check | Exit | Duration (s) | Required | Log SHA-256 |
|---|---|---|---|---|
| cold-signature | 0 | 43.525 | yes | 5575c271e9b604d3 |
| deb-build | 0 | 30 | yes | 7bdf533c0ebca50a |
| deb-signature | 0 | 0.762 | yes | c6b9e064495af852 |
| dependency-audit | 0 | 4.286 | yes | 531db7f60a49620c |
| full-test-suite | 0 | 420 | yes | 4abbd03453fa1c16 |
| install-smoke | 0 | 12.542 | yes | 2d0a18668930212e |
| license-inventory | 0 | 0.697 | yes | cc8e41a55e00cdea |
| release-evidence | 0 | 0.1 | yes | 139876833bc8529b |
| reproducibility | 0 | 420 | yes | 13c6eae43a89446d |
| sbom | 0 | 0.218 | yes | 2eae3b70d7706078 |
| secret-scan | 0 | 5.237 | yes | 7ff728a5877b4846 |
| static-analysis | 0 | 34.41 | yes | afa4a2e7bfb84e47 |
| test-inventory | 0 | 0.211 | yes | 971e7b9afe0038b7 |

## Artifacts

| Artifact | SHA-256 | Signed | Signature verified |
|---|---|---|---|
|  | 2f8ef8734bf06bce34d67dab6d83c66fa0bde83106bcb8b1a588ec3531c77298 | yes | yes |
|  | 6978de809944dc682db73ce8f9fe5202160ac186b9829e5f759ca91986327a16 | yes | yes |
|  | eb6772b39ca62832b5f7c110dbb390c63360222ab8cf1b91de81202c589c186b | yes | yes |
|  | 891b7b410eab07c2ad22a1986fdb3d67bf8520000a1eb8b167c46d4432748436 | no | NO |
|  | 1e9946ed5ccd8f78db7dc4035901f033c43cf6cb0fb31c9ca33a26a8a5672a14 | no | NO |

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
- No physical two-device cold-signing test.
- No real screen-reader/assistive-technology session.
- Android APKs are built and signature-verified but not installed on a device.
- Cold custom derivation/passphrase and strong pairing authentication remain open.
- Nonce/from binding is now enforced for the hot path; other signing routes need continued review.
- Release gate is evidence-backed but independent review is absent.
