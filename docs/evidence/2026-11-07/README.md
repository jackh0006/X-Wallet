# Evidence — 2026-11-07 — X Wallet 1.2.0

Raw, unedited command output for the 1.2.0 release. The tested commit is
recorded in `environment.txt` and in `release/evidence.json`.

| File | Command |
|---|---|
| `all-checks.log` | Combined release check run through `scripts/record_check.py` |
| `full-test-suite.log` | `bash scripts/test-suite.sh` |
| `static-analysis.log` | `flutter analyze --no-pub` |
| `security-mutation.log` | `python3 scripts/security_mutation_check.py` |
| `integration.log` | `bash scripts/run-anvil-tests.sh` |
| `cold-signature.log` | `cd verification && npm ci && node verify.cjs` |
| `backup-e2e.log` | `flutter test test/backup_restore_e2e_test.dart` |
| `release-signing-tests.log` | `bash scripts/test_release_signing.sh` |
| `identity-negative-tests.log` | `python3 scripts/test_release_identity.py` |
| `data-boundary.log` | `flutter test test/data_boundary_test.dart` |
| `localization.log` | `flutter test test/localization_test.dart` |
| `spending-policy.log` | `flutter test test/spending_policy_test.dart` |
| `linux-build.log` | `flutter build linux --release` |
| `deb-build.log` | `bash scripts/build-deb.sh` |
| `reproducibility.log` | `bash scripts/reproducibility-check.sh` |
| `artifact-sha256.txt` | SHA-256 of the built `.deb` |

The signature and the published release hashes are recorded in
`docs/releases/1.2.0.md` and `release/evidence.json`.

Local absolute path prefixes in the raw logs were normalized to
`/workspace/X-Wallet` so the evidence does not embed a builder machine path.
No test command or result line was changed.
