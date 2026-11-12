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

## MWEB status

**NOT IMPLEMENTED.**

Investigation on Litecoin Core 0.21.4:

- `getnewaddress` accepts `"mweb"` as an address type, so MWEB exists in the
  Core wallet.
- The public Esplora/indexer path used by X-Wallet does not expose MWEB
  extension-block outputs, peg-ins, peg-outs or MWEB transaction construction.
- MWEB is a separate protocol with its own address format, blinding, slates
  and peg logic. It is not a prefix change on transparent LTC.
- X-Wallet therefore handles **transparent LTC only**.
- The UI now shows an explicit warning when Litecoin is selected: do not send
  MWEB funds to these addresses.

## NOT implemented / NOT tested

- MWEB.
- Live Litecoin testnet send/receive.
- Taproot (not claimed for Litecoin).
- PSBT, descriptors, watch-only.
- Independent Litecoin implementation comparison.
- Physical device test.
