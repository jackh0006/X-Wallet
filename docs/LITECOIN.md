# Litecoin support — status

## Implemented

- Networks: Litecoin mainnet and testnet.
- Coin type `2'` mainnet and `1'` testnet.
- BIP44 P2PKH, BIP49 P2SH-P2WPKH and BIP84 P2WPKH derivation.
- Litecoin address validation and WIF handling.
- UTXO discovery/fee/broadcast through litecoinspace.org (Esplora).
- Transaction construction, signing, serialization and TxID.
- UI network/address-type selection and send review.

## Verified

- `ltc1q` native SegWit derivation on mainnet.
- Address validation against the Litecoin network.
- WIF round-trip and wrong-network rejection.
- P2PKH and P2WPKH transaction build/sign.

## NOT implemented / NOT tested

- Live Litecoin testnet send/receive.
- Taproot (not claimed for Litecoin).
- PSBT, descriptors, watch-only.
- Independent Litecoin implementation comparison.
- Physical device test.
