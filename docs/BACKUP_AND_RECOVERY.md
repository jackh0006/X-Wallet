# Backup and Recovery

**Scope:** the encrypted local vault, the portable backup, and recovery.
The vault file itself is device-bound; a portable `BNBBKP01` backup depends on
its password only and restores on a new device. The recovery phrase remains the
ultimate backup for HD accounts.

## What is backed up

- Encrypted vault file: `bnb-wallet-vault.bnb` (`BNBVL004` v2).
- Portable backup: `BNBBKP01`, Argon2id + XChaCha20-Poly1305, password only.
  It contains the encrypted account list and restores on a fresh install.
- Encrypted receipt archive and activity log are local; they are not required
  to recover funds.
- The device secret is **not** in the backup. It lives in the platform secure
  store or the Linux owner-only drawer. The portable backup deliberately does
  not need it.

## Canonical recovery procedure

1. Stop the wallet.
2. Keep the original vault file untouched.
3. On a clean installation, choose **Import wallet → recovery phrase**.
4. Enter the 12/24 words in the correct order. Never type them into a website,
   chat, terminal, or support message.
5. Confirm the derived address against an independent record.
6. Send a small test amount before relying on the restored wallet.

Do not restore by copying only the vault file to another machine: the
device-bound wrapper will not open without that machine's device secret. Use
**Export portable backup** instead; it is designed for exactly this case.

## Backup verification

- The portable backup must decrypt with its password on a fresh device and
  re-encrypt under the new device secret.
- A failed export must never replace a known-good backup.
- A failed import must leave the original vault byte-identical; this is covered
  by `test/vault_import_rollback_kdf_test.dart`.
- A wrong password, truncated file, corrupted tag, or modified header must fail
  closed with a generic error.

## Tested

- Vault v2 round-trip, wrong password, wrong device secret, fresh nonce.
- Portable backup round-trip, wrong password, tamper, truncation, and restore
  on a fresh device (`test/portable_backup_test.dart`).
- v1 migration and truncated-header rejection.
- Atomic write, rollback injection, post-commit verification failure.
- Import rollback and concurrent serialization.

## Not tested

- End-to-end UI restore on a clean physical machine (the unit test models a
  fresh device secret, not a full desktop run).
- Disk-full and power-loss recovery on a physical device.
- Backup media failure and long-term paper degradation.

## Recovery limitations

- There is no support recovery, no key escrow, and no password reset.
- Losing both the recovery phrase and the vault password loses the funds.
- A compromised OS can capture the phrase while it is displayed.
- Do not store the phrase in a photo, cloud note, password manager, or chat.
