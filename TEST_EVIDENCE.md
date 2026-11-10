# Test Evidence — X Wallet 1.5.0

Canonical command-by-command evidence: [docs/TEST_EVIDENCE.md](docs/TEST_EVIDENCE.md).

## Executed at `6778a6f51800ff2b9a519a05a8396da6efd4eec2`

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test tool` | PASS |
| `flutter analyze --no-pub` | PASS |
| `bash scripts/test-suite.sh` | PASS — 59/59 files, 696 s |
| `python3 scripts/test_inventory.py --check` | PASS — 62 files / 352 declarations |
| `flutter test test/vault_multi_wallet_test.dart` | PASS — 6/6 |
| `flutter test test/token_registry_test.dart` | PASS — 3/3 |
| `flutter test test/data_boundary_test.dart` | PASS — 4/4 |
| `bash scripts/run-anvil-tests.sh` | PASS — 3/3 |
| `python3 scripts/security_mutation_check.py` | PASS — 5/5 killed |
| `flutter test test/backup_restore_e2e_test.dart` | PASS — 4/4 |
| `cd verification && npm ci && node verify.cjs` | PASS — 8 substitutions rejected |
| `bash scripts/test_release_signing.sh` | PASS |
| `bash scripts/build-deb.sh` | PASS — signed `.deb` |
| `bash scripts/reproducibility-check.sh` | PASS — fixed path, identical manifests |
| `bash scripts/build-apk.sh` | PASS — arm64 + universal, signed |
| `apksigner verify --print-certs` | PASS — approved signer |
| `scripts/verify-android-signer.sh --require-deny` | PASS |
| Linux install/launch/upgrade smoke | PASS |
| Android physical-device runtime | NOT TESTED — no phone connected |
| Cold-wallet physical two-device test | NOT TESTED — demonstration only |
| Independent third-party audit | NOT TESTED |

Status vocabulary is exactly **PASS / FAIL / NOT TESTED / BLOCKED / NOT
APPLICABLE**. No skipped test is reported as passed.
