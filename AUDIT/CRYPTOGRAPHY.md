# Cryptography audit

Baseline: `8583393`; audit branch includes local fixes. Internal review, not an independent audit.

## Primitives

| Purpose | Implementation | Parameters |
|---|---|---|
| Password KDF | native Argon2id via `dargon2_core`; pure-Dart fallback `cryptography` | 64 MiB, t=3, p=4, 32-byte output, 16-byte random salt |
| Vault AEAD | XChaCha20-Poly1305 (`cryptography` 2.9.0) | 24-byte nonce, 16-byte tag, header as AAD |
| Device KEK | HKDF-SHA256 | IKM device secret, 32-byte zero salt, info `bnb-wallet/device-kek-v2` |
| Portable backup | Argon2id → XChaCha20-Poly1305 | 64 MiB/t=3/p=4, `BNBBKP01` v1, header AAD |
| PIN | Argon2id on a worker isolate | same parameters, random salt, `a2:` record |
| secp256k1 | `web3dart` 3.0.3 / `pointycastle` 4.0.0 | RFC-6979, low-s, recovery id |
| BIP-39/32 | `bip39_mnemonic` 4.1.0 / `bip32_plus` 1.0.0 | PBKDF2-HMAC-SHA512/2048, NFKD |
| EIP-55 | project code | keccak256 nibble rule |

## Verified

- Argon2id parameters are fixed and exact-matched on read before derivation; a hostile header cannot request unbounded work (`test/kdf_production_test`, `test/vault_header_validation_test`).
- Vault header (magic, version, m/t/p, salt) is authenticated AAD; any flip fails (`test/vault_test`).
- Fresh random salt, DEK and three nonces per vault save; no reuse path found.
- Portable backups are password-only, AEAD-authenticated, versioned, and restore on a fresh device (`test/portable_backup_test`, 5/5).
- Official BIP-39 Trezor vector 1 seed and the known first address now pass (`test/audit_regressions_test`, added by this audit).
- EIP-55 vectors pass; mixed-case input is now checked and rejected on the send path (`isChecksumValid`, new test).
- Cold EIP-1559 digest/raw/r/s/hash matches ethers.js 6.17.0 (`verification/verify.cjs`).
- RFC-6979 determinism and high-s rejection are tested.

## Findings

**HIGH — the vault is not a true 2-of-2.** Both wrappers wrap the same DEK. The app parser opens both boxes and compares the DEKs, but the format allows either factor to recover the DEK; on Linux the device secret is a 0600 file beside the vault. A whole-directory copy plus no password work is enough to recover the seed. Docs that say the password wrapper “alone is sufficient” and docs that say both are required are both wrong in different places. **FIXED IN DOCS**: describe it as “parser requires both; format is not AND; device secret is defense-in-depth.”

**HIGH — no zeroisation.** Passwords, mnemonics and private keys are immutable `String`/`Uint8List` values; `compute()` copies them to a worker. There is no secure wipe. Linux `PR_SET_DUMPABLE=0`, `RLIMIT_CORE=0` and best-effort `mlockall` are real; `mlockall` success is not asserted. Documented limitation, not fixed.

**MEDIUM — official BIP-32 and Argon2 vectors are absent.** BIP-39 vector and Ethereum derivation are now covered. No official BIP-32 chain/xprv/xpub vector, no Argon2 RFC 9106 vector, no Wycheproof corpus. Marked **PARTLY**.

**MEDIUM — legacy v1 (`BNBVL003`) is password-only and accepted indefinitely.** No forced migration prompt. A stale v1 file is a password-only copy.

**LOW — invalid base64 throws `FormatException` rather than `VaultException`.** Cosmetic error-type leak.

**LOW — WIF is wrong/dead.** `privateKeyWIF` returns the private key in an error string; WIF decoding uses double-keccak instead of SHA-256d. No UI path uses it. Recommend deleting both functions.

## Status

Strong primitive selection, AEAD construction and vector-backed cold signing. The material crypto weaknesses are the “second factor” semantics and the absence of zeroisation, not the KDF/AEAD parameters.
