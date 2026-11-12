# Implementation Status

**Last updated:** 2026-11-13
**Source of truth:** `release/manifest.json`, `docs/testing/test-inventory.json`,
`docs/GENERATED_STATUS.md`, `release/evidence.json`, and the GitHub Actions
runs. This file is a human-readable index, not a second source of truth.

## Current release

| Item | Value |
|---|---|
| Version | `1.6.0+18` |
| Branch | `main` (use `git rev-parse HEAD` for the exact checkout) |
| Tested source commit | `5ff0f0a1cc1bd315d80ba55ade4ee0b92dc0720c` |
| Release source commit | `8d7ec1239cebbc5de8c6945f7c0c337a5315544d`; the release tag adds evidence only |
| Evidence bundle | `release/evidence.json` (RELEASE APPROVED for recorded checks) |
| Pull requests | merged through the 1.6.0 release/evidence PRs (#54, #55) |
| Hosted CI | All required `main` workflows pass |
| Release status | **RELEASE APPROVED for recorded internal checks; independent audit NOT PERFORMED** |
| Final package | `x-wallet-1.6.0-amd64.deb` (hash recorded in `release/evidence.json`) |
| Signing fingerprint | GPG `CC819EF5E109A1518E840379D8C0CEC84BCCE06B`; Android `2a96a384eb0db55bb4fb0fb2107df386ecc595b38bc46225ef9b18309d93ba9a` |

## Verified

- Native Argon2id (`lib/kdf.dart`) with fixed 64 MiB / t=3 / p=4; measured
  **347 ms** vs ~110 s for the debug pure-Dart fallback.
- Exact ERC-20 transfer calldata in `SendIntent`; trailing bytes rejected.
- 73 test files / 415 declarations; 1.6.0 adds Ethereum chain/explorer/signing and price-provider tests; 1.5.5 added nonce/sender and cold-pairing regressions;
  3 real-Anvil tests; mutation score 5/5 (not re-run for 1.6.0); backup E2E 4/4; localization,
  spending-safety, data-boundary, multi-wallet, password-strength, default-token, legacy-migration, public-default, and private-key cold tests pass.
- Independent ethers.js cold-signature verification; 8 substitutions rejected.
- Android native Argon2 (`libargon2-arm.so`) is present in the release APK
  with exported `argon2id_hash_raw`.
- Android vault lock clears keys on background/idle without a PIN; 6-digit
  PIN policy and optional wipe-after-failures are implemented.
- Linux `flutter build linux --release` pass; signed `.deb` package built.
- Secret scan, dependency advisory audit, license inventory, SBOM, test
  inventory, generated-doc drift, dependency review, CodeQL, and Scorecard pass.
- Reproducibility: two clean builds at fixed path `/tmp/bnb-repro-1.6.0` with
  `SOURCE_DATE_EPOCH=0` and `gzip -n` produced archive
  `fcdf38ad6a65e42c27d288169abe5e964bb34d0c88f4c8ab11b173da7be6bc0d` with
  identical file manifests. Different absolute paths are not guaranteed to
  match because Flutter embeds the path in `libapp.so` and plugin libraries.
- Clean install/launch/upgrade/uninstall smoke: GitHub `ubuntu-24.04`
  `package-smoke` installs the `.deb`, launches under Xvfb, upgrades from the
  public 1.0.9 package with a data marker, uninstalls, and reinstalls.
- Signed `SHA256SUMS` covers the package and source archive; the detached
  signature verifies in a clean keyring.

## Scope and controls

| Item | Status | Detail |
|---|---|---|
| Android signing key rotation | **RELEASE SIGNER VERIFIED** | Current APKs use `2a96a384…3ba9a`; the historical `10c13a…` is denylisted. Offline backup of the key remains an owner action. |
| Linux `.deb` GPG signature | **PASS** | Signed with `CC819EF5E109A1518E840379D8C0CEC84BCCE06B` |
| Independent security audit | **NOT PERFORMED** | Internal self-audit only; no third-party report exists |
| Real EVM integration | **PASS (local Anvil)** | Native transfer, wrong chain, ERC-20 deploy/transfer/approve/revoke/revert on chain 97 |
| Windows / macOS / ARM64 | **NOT TESTED** | No builds for these platforms |
| Android device runtime | **NOT TESTED** | No physical Huawei Y9 2019 or emulator run in this environment |
| Android KDF timing | **NOT TESTED** | Native library is present; device timing still needs measurement |
| Startup / RSS performance | **NOT TESTED** | Needs a keyring-backed display session |
| Large-value controls | **IMPLEMENTED** | Split balances, freeze signing, allowlist, per-transaction limit, cold/offline signing |
| Multi-wallet vault | **IMPLEMENTED** | Add, switch, rename, remove; one vault password |
| Any vault password | **IMPLEMENTED** | No minimum length; live strength score; confirmation |
| Default BSC assets | **IMPLEMENTED** | BNB, USDT, USDC |
| Public RPC defaults | **IMPLEMENTED** | BNB Chain, PublicNode, 1RPC, Blast, 48.club |
| Hardware wallets | **OUT OF SCOPE** | No hardware support claimed; cold/offline signing is the isolation path |

## Next actions

1. Owner: run the small-amount checklist on the Huawei Y9 2019 and record the
   results; do not mark Android runtime as verified before that.
2. Owner: verify the release fingerprint through an independent channel before
   trusting the signature.
3. Engineering: keep the signed checksum and SBOM attached to the release.
4. Engineering: repeat the clean-desktop and Debian install matrix when a
   second test machine is available.
