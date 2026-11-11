# Storage audit

## Inventory

| Data | Location | Protection |
|---|---|---|
| Vault(s) | app dir / `vaults/<id>.bnb` | Argon2id + XChaCha20, 0600 |
| Device secret | `device_secret_v2.drawer` (Linux) / keyring (mobile) | plaintext 0600 on Linux; OS keyring on mobile |
| Receipts | active vault parent | `BNBRCPT1`, wallet key + device secret |
| Activity log | app dir | `BNBLOG01`, wallet key + device secret |
| Prefs | `shared_preferences.json` | plain: registry, RPC/Tor config, pending public tx, watch address |
| Node credentials | `node_secrets_v1` secure blob | OS keyring |
| Temp files | `.<dest>-<hex>` 0600 | encrypted, except drawer temp |
| Exports | user path / system temp | encrypted backup; decrypted log/receipt exports are plaintext temp |

## Verified

- Descriptor-pinned `openat(O_CREAT|O_EXCL|O_NOFOLLOW)` temp, fsync, read-back verify, use-time destination recheck, `renameat`, dir fsync.
- Import rollback restores exact original bytes on post-commit failure.
- Multi-vault create/switch/rename/delete and per-vault pending scoping.
- Erase-all now removes vaults, log, receipts, drawer, prefs, registry and secure keys, and **no longer deadlocks** (the log clear was moved before `withVaultOperationLock`; `test/erase_all_appstate_test.dart` proves it).
- Node credential blob is now deleted by erase.

## Remaining

- **HIGH:** erase does not remove pre-1.2 legacy app-ID directories (vault + plaintext device secret) and does not scan `vaults/` if the registry is missing/corrupt.
- **HIGH:** mobile keyring mint bug is fixed in code, but there is no platform-channel test.
- **MEDIUM:** registry + active-id are two independent prefs writes; a crash can change the active vault silently. Mutations are not wrapped in the vault/process lock.
- **MEDIUM:** receipts/log are shared by vaults in the same directory; a log decrypt failure can overwrite history.
- **MEDIUM:** Android uses the portable write path (no no-follow pin/NOREPLACE/dir fsync).
- **MEDIUM:** decrypted log/receipt exports go to `Directory.systemTemp` and are not deleted.
- **LOW:** orphan atomic temps are not swept at startup; erase unlinks are not dir-fsynced.
