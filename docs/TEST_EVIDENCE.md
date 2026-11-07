# X Wallet Test Evidence

This page collects the checks that have already passed for X Wallet. Every
entry names the command or evidence source so the result can be inspected.
No result on this page was invented, and the checks are not a substitute for
reading the source or testing the wallet yourself.

## Release integrity

| Item | Value |
|---|---|
| Release | **X Wallet 1.2.0** (`1.2.0+6`) |
| Tag | `v1.2.0` |
| Package | `x-wallet-1.2.0-amd64.deb` |
| SHA-256 | `d580d03909c0bf60cb036a87ba6300e55eb9a7865b19f539998bd46bad71387c` |
| SBOM | `docs/SBOM.json` — 116 packages |
| Signature | `SHA256SUMS.asc` — EdDSA |
| Signing fingerprint | `CC819EF5E109A1518E840379D8C0CEC84BCCE06B` |
| Evidence bundle | `release/evidence.json` |
| Test matrix | `docs/testing/TEST_MATRIX.md` |
| Recorded results | `docs/TEST_RESULTS.md` |

## Code quality and policy

| Mark | Check | Command / evidence | Result | What it proves |
|---|---|---|---|---|
| ✅ PASS | Formatting | `dart format --output=none --set-exit-if-changed lib test tool` | PASS in 1.5 s | The source is consistently formatted and easier to review. |
| ✅ PASS | Static analysis | `flutter analyze --no-pub` | PASS, no issues | The wallet code has no analyzer findings. |
| ✅ PASS | Default test suite | `bash scripts/test-suite.sh` | PASS: 52/52 non-integration files, 0 failed, 0 timed out, 575 s | Unit, widget, vault, network, transaction, and security tests pass. |
| ✅ PASS | Test inventory | `python3 scripts/test_inventory.py --check` | PASS: 53 files / 322 declarations / 7 real-KDF files | Every test file is accounted for; none is silently missing. |
| ✅ PASS | Mutation testing | `python3 scripts/security_mutation_check.py` | PASS: 5/5 mutations killed, 89 s | Deliberately broken security checks are caught by the tests. |
| ✅ PASS | Branding validator | `python3 scripts/check_branding.py` | PASS | User-facing product identity is consistent. |
| ✅ PASS | Localization | `flutter test test/localization_test.dart` | PASS | The runtime `Text` layer follows the selected locale. |
| ✅ PASS | Spending safety | `flutter test test/spending_policy_test.dart` | PASS: 5/5 | Freeze signing, recipient allowlist, and native per-transaction limit are enforced before signing. |
| ✅ PASS | Data boundary | `flutter test test/data_boundary_test.dart` | PASS: 4/4 | No telemetry/ads/AI SDK; no network path in key or signing modules; a single HTTP choke point. |
| ✅ PASS | Free-use validator | `python3 scripts/check_free_product.py` | PASS | No subscription, paywall, ads, or payment SDK. |

## Cryptography, vault, and signing

| Mark | Check | Command / evidence | Result | What it proves |
|---|---|---|---|---|
| ✅ PASS | Production KDF | `flutter test test/kdf_production_test.dart` | PASS: native Argon2id 344 ms; pure-Dart cross-check; one real 64 MiB round-trip | The production key derivation path works with the fixed 64 MiB / t=3 / p=4 parameters. |
| ✅ PASS | Independent cold signature | `(cd verification && npm ci && node verify.cjs)` | PASS: 8 substitutions rejected, ~7 s | A separate ethers.js implementation rebuilds and verifies signed transactions; tampered variants fail. |
| ✅ PASS | Cold wallet protocol | `flutter test test/cold_wallet_protocol_test.dart` | PASS: 15 tests | Pairing, request, signature, checksum, expiry, and substitution rules are enforced. |
| ✅ PASS | Cold wallet service | `flutter test test/cold_wallet_service_test.dart` | PASS: 15 tests | Persistence, replay protection, signing, verification, broadcast, and burn-list handling work. |
| ✅ PASS | Cold transaction codec | `flutter test test/cold_tx_codec_test.dart` | PASS: 6 tests | Canonical payloads, digests, signed-transaction parsing, and field validation are correct. |
| ✅ PASS | Backup/restore E2E | `flutter test test/backup_restore_e2e_test.dart` | PASS: 4/4 | Create, backup, wipe, restore, wrong password, tamper, and truncation cases pass. |
| ✅ PASS | Vault encryption | `flutter test test/vault_test.dart` | PASS: 9 tests | Vault v2 round-trip, wrong password/device, fresh nonce, downgraded parameters, and v1 migration are covered. |
| ✅ PASS | Release signing tools | `bash scripts/test_release_signing.sh` | PASS: 6 cases, 1.6 s | Valid signatures pass; wrong key, tampered package/sums, missing signature, and unknown key are rejected. |
| ✅ PASS | Android signer inventory | `bash scripts/test_android_inventory.sh` | PASS | Signer fingerprints are read correctly and passwords do not leak into output. |

## Chain, transactions, and privacy

| Mark | Check | Command / evidence | Result | What it proves |
|---|---|---|---|---|
| ✅ PASS | Real EVM integration | `bash scripts/run-anvil-tests.sh` against Anvil, chain 97 | PASS: 3/3, 11 s | Native transfer, wrong-chain rejection, and ERC-20 deploy/mint/transfer/approve/revoke/revert work against a real EVM node. |
| ✅ PASS | RPC adversarial tests | `flutter test test/rpc_adversarial_test.dart` | PASS: 6 tests | Wrong chain, non-JSON/HTML responses, oversized/malformed balances, network-switch mismatch, and unsafe URLs are rejected. |
| ✅ PASS | TLS pinning | `flutter test test/tls_pinning_test.dart` | PASS: 7 tests | Standard certificate and hostname validation runs first; a pin cannot bypass it. |
| ✅ PASS | Privacy dialogs and routing | `privacy_dialogs_test`, `privacy_config_test`, `tor_manager` tests | PASS in the default suite | Proxy/Tor options parse correctly and traffic follows the configured route. |
| ✅ PASS | User-Agent scrubbing | `flutter test test/ua_scrub_test.dart` | PASS | Identifying headers are removed on every transport. |
| ✅ PASS | Node management | `flutter test test/node_manager_test.dart` | PASS: 17 tests | Pool selection, strict mode, import/export, enable/disable, and ordering work. |
| ✅ PASS | Fee engine | `flutter test test/fee_engine_test.dart` | PASS: 12 tests | EIP-1559 and legacy fee math, multi-node merge, and sanity clamps are correct. |
| ✅ PASS | Fee parity | `flutter test test/fee_parity_test.dart` | PASS: 4 tests | The terminal-v1 fee arithmetic is preserved. |
| ✅ PASS | Send intent and lifecycle | `send_intent_test`, `tx_lifecycle_test`, `hold_to_confirm_test` | PASS in the default suite | Recipient, chain, nonce, fee, maximum-cost, calldata, and hold-to-confirm checks run before signing. |
| ✅ PASS | Wallet core | `flutter test test/wallet_core_test.dart` | PASS: 12 tests | Mnemonic generation, derivation, address formatting, signing, and import work. |
| ✅ PASS | Fuzz and property tests | `flutter test test/fuzz_and_property_test.dart` | PASS: 10 tests | Amount round-trips, checksum invariants, canonical RLP fuzzing, envelope fuzzing, and ERC-20 calldata totality hold. |

## Release, build, and supply chain

| Mark | Check | Command / evidence | Result | What it proves |
|---|---|---|---|---|
| ✅ PASS | Linux release build | `flutter build linux --release` | PASS, 123 s | The desktop release bundle builds successfully. |
| ✅ PASS | Debian package build | `bash scripts/build-deb.sh` | PASS, 30 s | A real, signed `x-wallet-1.2.0-amd64.deb` is produced. |
| ✅ PASS | Package sanity | `dpkg-deb -x` + `ldd` + secret-name scan | PASS | All native libraries resolve and no secret-bearing filenames are packaged. |
| ✅ PASS | Install / launch / upgrade / uninstall | `scripts/package-smoke.sh` on Ubuntu 24.04 | PASS: install, upgrade from `bnb-wallet` 1.0.9 with data preserved, launch, uninstall, reinstall | The real package lifecycle works and existing data survives the rename. |
| ✅ PASS | Fixed-path reproducibility | `bash scripts/reproducibility-check.sh` | PASS: identical archive `dffb5b35…` and manifests, 265 s | Two builds at the same path produce the same archive. |
| ✅ PASS | Cross-runner reproducibility | GitHub Actions `reproducibility` workflow, release commit | PASS | Separate runners reproduce the same fixed-path archive. |
| ✅ PASS | Secret scan | `bash scripts/secret-scan.sh` | PASS, 1.8 s | No secrets in the current tree. |
| ✅ PASS | Dependency advisory audit | `python3 scripts/dependency-audit.py` | PASS, 4.6 s | No current advisory flags for the locked dependencies. |
| ✅ PASS | License inventory | `python3 scripts/license-check.py` | PASS, 0.4 s | Every dependency license is inventoried. |
| ✅ PASS | SBOM | `python3 scripts/sbom.py --out docs/SBOM.json` | PASS: 116 packages | The complete dependency inventory is generated and hashed. |
| ✅ PASS | Release evidence identity | `python3 scripts/check_release_identity.py` | PASS | Manifest, SBOM, evidence, and artifact hashes bind to one source commit. |
| ✅ PASS | Release identity negative tests | `python3 scripts/test_release_identity.py` | PASS: 15/15 | Stale, tampered, malformed, and ambiguous identities are rejected. |
| ✅ PASS | Published artifact signature | `scripts/verify-release-signature.sh` in a clean GNUPGHOME | PASS: `SHA256SUMS.asc` verified; fingerprint `CC819EF5E109A1518E840379D8C0CEC84BCCE06B` | The exact published `.deb` checksum is covered by a detached owner signature and verified independently. |
| ✅ PASS | Hosted CI | GitHub Actions on `main`: `verify`, `docs-sync`, `integration`, `package-smoke`, `CodeQL` | PASS | Every required workflow is green. |
| ✅ PASS | CodeQL | GitHub CodeQL: C/C++, JavaScript/TypeScript, Python, Actions | PASS | Static security analysis runs across four languages. |
| ✅ PASS | Generated-docs sync | `python3 scripts/generate_docs.py --check` | PASS | Generated status and README blocks match the committed files. |

## Where the evidence lives

- `release/evidence.json` — machine-readable check bundle bound to the release.
- `release/manifest.json` — toolchain, lockfile, SBOM, and inventory hashes.
- `docs/TEST_RESULTS.md` — recorded runs, commands, durations, and environment.
- `docs/testing/TEST_MATRIX.md` — test file inventory and coverage areas.
- `docs/SBOM.json` — CycloneDX dependency inventory.
- GitHub Actions — `verify`, `docs-sync`, `integration`, `package-smoke`,
  `reproducibility`, and `CodeQL` workflows.

## Reading the table

- **PASS** means the recorded command exited successfully and the result was
  captured for the commit named in the evidence bundle.
- A test count is a declaration count, not a claim that every possible input
  has been tried.
- The release package and its SHA-256 are listed in
  [the latest release](https://github.com/jackh0006/X-Wallet/releases/latest).
  Verify the download before installing.
