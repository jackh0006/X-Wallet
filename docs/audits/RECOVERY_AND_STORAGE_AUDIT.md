# Recovery and storage audit — 2.0.0 branch

## Existing vault

- Argon2id 64 MiB/t=3/p=4 + XChaCha20-Poly1305, authenticated header,
  device secret, atomic writes, owner-only permissions.
- Existing multi-vault, rename, backup/restore and erase tests remain green.

## UTXO recovery

- UTXO accounts are derived deterministically from the wallet's BIP39 phrase.
- Address type, account and change branch are part of the derivation path.
- The same phrase restores the same address on the same network.
- A wrong network or wrong path produces a different address; the UI shows both.
- Raw-key-only wallets cannot open the UTXO page (no phrase to derive).

## Not verified

- Clean second-install recovery with real UTXO funds.
- Gap-limit discovery across many addresses.
- xprv/xpub/watch-only recovery.
- MWEB recovery (not implemented).
- Forensic erase of flash storage (not claimed).

No private key, seed or password is written to logs or test artifacts.
