# Key management audit

## Lifecycle

1. **Seed**: BIP-39 12/24 words, `Random.secure()`; checksum/wordlist validated.
2. **Derivation**: `m/44'/60'/0'/0/i`; xpub at `m/44'/60'/0'`.
3. **Vault**: random 32-byte DEK; password KEK (Argon2id) and device KEK (HKDF) each wrap the DEK; payload under the DEK.
4. **Unlock**: both boxes are opened and the DEKs compared; any failure returns one generic error.
5. **Lock**: references are nulled; no zeroisation.
6. **Password change**: re-reads with the old password, re-encrypts with a new salt and the current device secret, atomic write. No read-back verification.
7. **Backup**: `BNBBKP01` portable, password-only, Argon2id + XChaCha20; restore re-encrypts under the new device secret.
8. **Delete/erase**: shreds vaults, log, receipts, drawer, prefs, secure keys; see storage audit.

## Device secret

- Linux/desktop: a plaintext 0600 drawer file beside the vault. Keyring is used only to migrate an old vault.
- Android/iOS: platform keyring first, drawer fallback.
- **HIGH — fixed in this branch:** mobile keyring returning null/empty/malformed while a vault exists now fails closed. Previously it could mint a replacement secret and orphan the vault.
- **HIGH — remaining:** a copied data directory on Linux includes the drawer, so the device factor does not protect against whole-directory theft; only the password does.

## PIN

- 6–12 digits, weak-PIN list, Argon2id, random salt, `a2:` record, constant-time compare.
- **HIGH — fixed in this branch:** `1 << (count-1)` overflowed after 64 failures and could produce an expired cooldown. It is now clamped and unit-tested.
- **MEDIUM — fixed in this branch:** `verifyPin` now checks the persisted backoff itself.
- **MEDIUM — remaining:** backoff is wall-clock based; a forward clock jump can clear it. There is no monotonic boot counter.
- **MEDIUM — remaining:** the wipe-after-N path is only in the lock screen; `eraseAll` leftovers are now checked after the deadlock fix, but the UI message still needs a warning on leftovers.

## Backup/recovery

- Portable backup is the only cross-device recovery path for imported private keys.
- The recovery phrase recovers HD accounts but not imported keys.
- `test/portable_backup_test.dart` uses the fast 1 MiB KDF profile; the production 64 MiB path is not exercised there. **PARTLY**.
- `test/backup_restore_e2e_test.dart` exercises `VaultCipher`, not `AppState.importVault`/`BNBBKP01`. **PARTLY**.

## Verdict

Key separation and derivation are sound. The remaining material risks are the non-AND device wrapper, the co-located Linux drawer, no zeroisation, and the wall-clock PIN backoff.
