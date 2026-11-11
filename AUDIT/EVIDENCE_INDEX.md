# Evidence index

| Claim / area | Evidence |
|---|---|
| Baseline / commit | `AUDIT/BASELINE.md`, `git rev-parse HEAD` |
| File/dependency inventory | `AUDIT/FILE_INVENTORY.md`, `AUDIT/DEPENDENCY_INVENTORY.md` |
| Crypto primitives | `AUDIT/CRYPTOGRAPHY.md`, `test/vault_test.dart`, `test/kdf_production_test.dart` |
| Official BIP-39 vector | `test/audit_regressions_test.dart` |
| EIP-55 typo rejection | `test/audit_regressions_test.dart` |
| Cold contract binding | `test/audit_regressions_test.dart` |
| PIN backoff overflow | `test/audit_regressions_test.dart` |
| Erase deadlock | `test/erase_all_appstate_test.dart` |
| Portable backup | `test/portable_backup_test.dart` |
| Multi-vault | `test/multi_vault_test.dart` |
| Cold signature oracle | `verification/verify.cjs` |
| Egress construction | `test/data_boundary_test.dart` |
| Tor startup | `test/privacy_startup_test.dart` |
| RPC adversarial | `test/rpc_adversarial_test.dart` |
| TLS pinning | `test/tls_pinning_test.dart` |
| Node credentials | `test/node_secret_storage_test.dart` |
| Full suite | `AUDIT/TEST_RESULTS.md`, `/tmp/xw-audit-final-suite.log` |
| Release artifacts | GitHub release `v1.5.3`, `SHA256SUMS`, `BUNDLE_SHA256SUMS` |
| Handoff + keys | `/home/mhh06/Downloads/X Wallet/1.5.3/` |
