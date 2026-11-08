# Evidence — 2026-11-08 — X Wallet 1.3.0

Raw command output for the 1.3.0 release. The tested commit is recorded in
`environment.txt` and in `release/evidence.json`.

| File | Command |
|---|---|
| `all-checks.log` | Combined release check run through `scripts/record_check.py` |
| `full-test-suite.log` | `bash scripts/test-suite.sh` |
| `static-analysis.log` | `flutter analyze --no-pub` |
| `security-mutation.log` | `python3 scripts/security_mutation_check.py` |
| `integration.log` | `bash scripts/run-anvil-tests.sh` |
| `cold-signature.log` | `cd verification && npm ci && node verify.cjs` |
| `vault-multi-wallet.log` | `flutter test test/vault_multi_wallet_test.dart` |
| `password-strength.log` | `flutter test test/password_strength_test.dart` |
| `default-tokens.log` | `flutter test test/default_tokens_test.dart` |
| `cold-private-key.log` | `flutter test test/cold_private_key_test.dart` |
| `legacy-migration.log` | `flutter test test/legacy_migration_test.dart` |
| `public-defaults.log` | `flutter test test/public_defaults_test.dart` |
| `deb-build.log` | `bash scripts/build-deb.sh` |
| `deb-signature.log` | clean-keyring signature and checksum verification |
| `reproducibility.log` | `bash scripts/reproducibility-check.sh` |
| `artifact-sha256.txt` | SHA-256 of the built `.deb` |

Local absolute path prefixes were normalized to `/workspace/X-Wallet`; no test
command or result line was changed.
