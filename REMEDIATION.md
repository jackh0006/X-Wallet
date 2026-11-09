# Remediation Record

| ID | Issue | Fix | Regression test | Status |
|---|---|---|---|---|
| REM-01 | Vault keys with an insignificant leading `00` failed account parsing and were reported as a wrong password | Normalize private-key hex on vault read and save; separate decryption errors from record errors | `vault_multi_wallet_test` leading-zero key; real-vault probe | Fixed |
| REM-02 | Linux app-ID rename could leave the vault in the old data directory | Migrate the legacy app directory, device secret, preferences, logs, and receipts | `legacy_migration_test` | Fixed |
| REM-03 | Second vault password could silently fail | One vault password; explicit unlock of an existing vault before adding | `vault_multi_wallet_test` | Fixed |
| REM-04 | 16-character password minimum blocked valid passphrases | Any non-empty password, no trimming, confirm field, live strength score | `password_strength_test`, dialog tests | Fixed |
| REM-05 | Private-key-only wallets could not export a cold pairing | Key-based pairing and signing path with replay and field checks | `cold_private_key_test` | Fixed |
| REM-06 | Fake tokens could appear as real USDT/USDC | Canonical BSC registry; unknown lookalikes marked unverified with a warning | `token_registry_test` | Fixed |
| REM-07 | Android had no approved release signer | New 4096-bit RSA key outside the repo; old signer denylisted | `apksigner` + `verify-android-signer.sh` | Fixed |
| REM-08 | Android light-theme gold text had poor contrast | Dark amber for text/outlines; black text on bright gold buttons; standard Material text sizes | Widget/navigation/accessibility tests | Fixed |
| REM-09 | Android runtime and cold-wallet physical security are unverified | Documented; small-amount device checklist provided | `SECURITY_LIMITATIONS.md` | Open by design |
| REM-10 | No independent external audit | Documented; audit package published | `SECURITY_AUDIT.md` | Open |
