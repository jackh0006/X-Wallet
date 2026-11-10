# Proof matrix — X Wallet 1.5.3

Each row maps a claim from `docs/CLAIM_REGISTER.md` to the command that fails
when the claim is false. Run from the repository root.

| Claim | Command | What failure means |
|---|---|---|
| C1 KDF parameters | `flutter test test/kdf_production_test.dart` | Parameters drifted or native/pure disagree |
| C2/C3 vault format | `flutter test test/vault_test.dart test/vault_header_validation_test.dart` | Header, nonce, wrapper or downgrade behavior changed |
| C6/C7 portable backup | `flutter test test/portable_backup_test.dart` | Backup no longer restores, or accepts tamper/truncation |
| C8/C9 v1 read/import | `flutter test test/vault_test.dart test/vault_import_rollback_kdf_test.dart` | Legacy vaults stop reading or import rollback breaks |
| C11 PIN fails closed | `flutter test test/node_secret_storage_test.dart` | A missing PIN record unlocks |
| C12 log canary | `flutter test test/log_canary_test.dart` | A secret appears in the encrypted log in plaintext |
| C14/C15 derivation/signing | `flutter test test/wallet_core_test.dart test/cold_tx_codec_test.dart` | A vector or signature property changes |
| C16 ethers cross-check | `cd verification && npm ci && node verify.cjs` | The independent fixture no longer matches |
| C17/C18 review binding | `flutter test test/send_intent_test.dart test/cold_wallet_protocol_test.dart` | A reviewed field can change before signing |
| C19/C20 broadcast/cancel | `flutter test test/hardening_regressions_test.dart` | Unknown broadcast state or cancel verification regresses |
| C22/C23/C24 approvals/tokens | `flutter test test/hardening_regressions_test.dart test/token_registry_test.dart` | Spender hidden, unlimited threshold wrong, spoof accepted |
| C25 cold mode | `flutter test test/price_service_test.dart test/privacy_startup_test.dart` | Cold mode starts a network client |
| C26 proxy fail-closed | `flutter test test/privacy_startup_test.dart test/tls_pinning_test.dart` | A configured Tor route falls back direct |
| C27 headers | `flutter test test/ua_scrub_test.dart` | A User-Agent or identifying header appears |
| C29 dependency ban | `flutter test test/data_boundary_test.dart` | A telemetry/analytics/AI package is locked |
| C30 egress construction | `flutter test test/data_boundary_test.dart` | A new HTTP/socket/launch site appears outside the allowlist |
| C31/C32 RPC limits/URLs | `flutter test test/rpc_adversarial_test.dart` | Oversized/malformed/untrusted RPC is accepted |
| C33 node credentials | `flutter test test/node_secret_storage_test.dart` | A credential is written to plain preferences or export |
| C34 erase-all | `flutter test test/erase_flow_test.dart` | A vault, log or temp file survives erase |
| C35/C36 multi-vault | `flutter test test/multi_vault_test.dart` | Vaults leak into each other or password checks fail |
| C37 signatures/hashes | `bash scripts/verify-release-signature.sh` and `sha256sum -c SHA256SUMS` | A release artifact or signature is wrong |
| C39 Android source hardening | `bash scripts/test_android_hardening.sh` | A manifest/gradle hardening marker disappears |
| C40 Android signer | `apksigner verify --print-certs <apk>` and `bash scripts/verify-android-signer.sh <apk> --allow <fpr> --deny release/android-signer-denylist.txt --require-deny` | The APK is signed by an unapproved key |
| Formatting | `dart format --output=none --set-exit-if-changed lib test tool` | Source is not formatted |
| Static analysis | `flutter analyze --no-pub` | A type or lint error exists |
| Full suite | `bash scripts/test-suite.sh` | Any test file fails or times out |
| Secret scan | `bash scripts/secret-scan.sh` | A keystore/private key pattern is tracked |
| Inventory | `python3 scripts/test_inventory.py --check` | A test file is missing from the matrix |
| Branding | `python3 scripts/check_branding.py` | The display name or version drifts |
| Release identity | `python3 scripts/check_release_identity.py` | Manifest/SBOM/evidence no longer bind to the commit |

## Commands that are NOT yet proof

- `test/rpc_adversarial_test.dart` injects an `http.Client`; it does not capture
  real TLS traffic.
- `test/tls_pinning_test.dart` calls the pin helper directly; it does not prove
  every node path is pinned.
- `verification/verify.cjs` validates a static fixture; it is not a live
  differential test of the Dart encoder.
- There is no `strace`/network-namespace artifact in the repository yet.
