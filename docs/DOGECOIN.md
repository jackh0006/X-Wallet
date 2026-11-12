# Dogecoin support — status

## Implemented

- Networks: Dogecoin mainnet and testnet.
- Coin type `3'` mainnet and `1'` testnet.
- P2PKH address derivation and validation.
- Network-specific WIF handling.
- UTXO discovery/balance through BlockCypher.
- Dogecoin relay-floor fee policy (0.001 DOGE/kB = 100 sat/vB).
- Transaction construction, signing, serialization and TxID.
- UI network selection and send review.

## Verified

- Dogecoin mainnet P2PKH address starts with `D`.
- WIF round-trip and wrong-network rejection.
- P2PKH transaction build/sign.
- BlockCypher UTXO and broadcast response parsing with mocks.

## NOT implemented / NOT tested

- SegWit or Taproot on Dogecoin (not claimed).
- Live Dogecoin testnet send/receive.
- PSBT, descriptors, watch-only.
- Independent Dogecoin implementation comparison.
- Physical device test.
