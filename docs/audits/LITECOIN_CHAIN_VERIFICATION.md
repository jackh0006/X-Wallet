# Litecoin chain verification

## Network identity

Values checked against Litecoin Core `chainparams.cpp`:

| Field | Mainnet | Testnet |
|---|---|---|
| Genesis | `12a765e31ffd4059…4bfe2` | `4966625a4b2851d9…29a0` |
| Magic | `fbc0b6db` | `fdd2c8f1` |
| Port | 9333 | 19335 |
| PoW | Scrypt | Scrypt |

## Implemented

- BIP44/49/84 derivation; P2PKH/P2SH-P2WPKH/P2WPKH.
- WIF, address validation, UTXO discovery (litecoinspace Esplora), fee, signing,
  serialization, TxID, broadcast, status.
- UI network/type selection and review.

## MWEB

**NOT IMPLEMENTED.** The wallet does not discover, receive, spend or recover
MWEB funds. Ordinary LTC UTXO support is not full Litecoin support.

## Evidence

- Address/tx build tests: B.
- Independent comparison: F for addresses and tx serialization.
- Live Litecoin testnet: **D NOT PERFORMED**.
- Physical device: **E NOT PERFORMED**.
- Independent audit: **G NOT PERFORMED**.

## Unsupported

- MWEB, Taproot, PSBT, descriptors, watch-only, RBF, regtest.
