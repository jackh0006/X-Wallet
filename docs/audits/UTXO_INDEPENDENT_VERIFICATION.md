# UTXO independent verification

Scope: `release/2.0.0` commit `9a59763` plus the audit fixes on top.
This is an independent-tool comparison, **not** an independent security audit.

## Independent tools

| Tool | Version | Purpose |
|---|---|---|
| Node.js | 24.22.2 | runner |
| `bitcoinjs-lib` | 6.1.7 | independent address/transaction implementation |
| `bip32` | 4.0.0 | independent BIP32 derivation |
| `tiny-secp256k1` | 2.2.3 | secp256k1 point operations for P2TR |
| `bip39` | 3.1.0 | mnemonic-to-seed |

Installed in a temporary directory, not added to the wallet.

## Address comparison

The same public test mnemonic was derived in X-Wallet and in the independent
Node implementation for:

- BTC mainnet: BIP44, BIP49, BIP84, BIP86
- BTC testnet: BIP44, BIP49, BIP84, BIP86
- LTC mainnet/testnet: BIP44, BIP49, BIP84
- DOGE mainnet/testnet: BIP44

Comparison fields: derivation path, compressed public key, address.

**Result: 16/16 matched after one defect was fixed.**

### Defect found

- `btc-testnet` P2TR used `Bip86Coins.bitcoin` (coin type 0) instead of
  `Bip86Coins.bitcoinTestnet` (coin type 1).
- X-Wallet produced `tb1p5cyxnux…p3mvzv`; independent produced
  `tb1p8wpt9v4frpf3tkn0srd97pksgsxc5hs52lafxwru9kgeephvs7rqlqt9zj`.
- Fixed `lib/utxo/utxo_wallet.dart` to select the testnet BIP86 coin.
- Regression test added in `test/utxo_wallet_test.dart`.

## Transaction comparison

A deterministic transaction was built in X-Wallet for:

- BTC P2WPKH
- BTC P2TR
- LTC P2WPKH
- DOGE P2PKH

Each raw transaction was decoded with `bitcoinjs-lib`.

**Result: 4/4 matched** for:

- transaction version
- input count and prevout hash
- output count, output values and output address set (BIP69 order may differ)
- transaction ID
- output sum = amount + change
- amount + change + fee = selected input total

Example BTC P2WPKH TxID: `2b4d00280b99da48a1f88cb75f2c539302b5089674da9e4ac3c1a482e5b1e045`.

## What was not verified

- ECDSA/Schnorr signature validity against an independent verifier.
- Live testnet inclusion, confirmation or block height.
- Taproot script-path spending (only key-path).
- PSBT, descriptors, xprv/xpub, watch-only, RBF.
- Physical two-device signing.
- Independent security audit.

The comparisons used only a public test mnemonic. No real funds were used.
