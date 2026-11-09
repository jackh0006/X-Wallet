# Implementation Status

**Last updated:** 2026-11-07
**Source of truth:** `release/manifest.json`, `docs/testing/test-inventory.json`,
`docs/GENERATED_STATUS.md`, `release/evidence.json`, and the GitHub Actions
runs. This file is a human-readable index, not a second source of truth.

## Current release

| Item | Value |
|---|---|
| Version | `1.4.1+10` |
| Branch | `main` (use `git rev-parse HEAD` for the exact checkout) |
| Tested source commit | `20cdcf4374b17e14775961f853afbc0f6264c515` |
| Release source commit | recorded in `release/evidence.json` (`sourceCommit`) |
| Evidence bundle | `release/evidence.json` (release-approved, signed) |
| Pull requests | merged through the 1.2.0 release PR |
| Hosted CI | All required `main` workflows pass |
| Release status | **RELEASE APPROVED / signed** |
| Final package | `x-wallet-1.4.1-amd64.deb`, SHA-256 `cd4e2fef17c907a88fa5e1dde96efc5f30bcc9ee7775157b7295a71097c8b0ec` |
| Signing fingerprint | `CC819EF5E109A1518E840379D8C0CEC84BCCE06B` |

## Verified

- Native Argon2id (`lib/kdf.dart`) with fixed 64 MiB / t=3 / p=4; measured
  **347 ms** vs ~110 s for the debug pure-Dart fallback.
- Exact ERC-20 transfer calldata in `SendIntent`; trailing bytes rejected.
- 60 test files / 347 declarations; default suite 58/58 pass in 578 s;
  3 real-Anvil tests; mutation score 5/5; backup E2E 4/4; localization,
  spending-safety, data-boundary, multi-wallet, password-strength, default-token, legacy-migration, public-default, and private-key cold tests pass.
- Independent ethers.js cold-signature verification; 8 substitutions rejected.
- Linux `flutter build linux --release` pass; signed `.deb` package built.
- Secret scan, dependency advisory audit, license inventory, SBOM, test
  inventory, generated-doc drift, dependency review, CodeQL, and Scorecard pass.
- Reproducibility: two clean builds at fixed path `/tmp/bnb-repro-build` with
  `SOURCE_DATE_EPOCH=0` and `gzip -n` produced archive
  `3107e9c44e5271a3dc0a00219b3c8948899e04a1966770e68f6376c0b518fa91` with
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
| Android signing key rotation | **BLOCKED** | Owner must rotate; denylist is empty; no APK may be published |
| Linux `.deb` GPG signature | **PASS** | Signed with `CC819EF5E109A1518E840379D8C0CEC84BCCE06B` |
| Independent security audit | **NOT CLAIMED** | Internal self-audit only |
| Real EVM integration | **PASS (local Anvil)** | Native transfer, wrong chain, ERC-20 deploy/transfer/approve/revoke/revert on chain 97 |
| Windows / macOS / ARM64 | **NOT TESTED** | No builds for these platforms |
| Startup / RSS performance | **NOT TESTED** | Needs a keyring-backed display session |
| Large-value controls | **IMPLEMENTED** | Split balances, freeze signing, allowlist, per-transaction limit, cold/offline signing |
| Multi-wallet vault | **IMPLEMENTED** | Add, switch, rename, remove; one vault password |
| Any vault password | **IMPLEMENTED** | No minimum length; live strength score; confirmation |
| Default BSC assets | **IMPLEMENTED** | BNB, USDT, USDC |
| Public RPC defaults | **IMPLEMENTED** | BNB Chain, PublicNode, 1RPC, Blast, 48.club |
| Hardware wallets | **OUT OF SCOPE** | No hardware support claimed; cold/offline signing is the isolation path |

## Next actions

1. Owner: rotate the Android key, record the old fingerprint in
   `release/android-signer-denylist.txt`, and approve the new signer.
2. Owner: verify the release fingerprint through an independent channel before
   trusting the signature.
3. Engineering: keep the signed checksum and SBOM attached to the release.
4. Engineering: repeat the clean-desktop and Debian install matrix when a
   second test machine is available.
