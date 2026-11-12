# Bitcoin chain verification

## Network identity

Values checked against Bitcoin Core `chainparams.cpp`:

| Field | Mainnet | Testnet |
|---|---|---|
| Genesis | `000000000019d668…ce26f` | `000000000933ea01…f4943` |
| Magic | `f9beb4d9` | `0b110907` |
| Port | 8333 | 18333 |
| PoW | SHA-256d | SHA-256d |

## Implemented

- BIP44/49/84/86 derivation and P2PKH/P2SH-P2WPKH/P2WPKH/P2TR addresses.
- WIF/raw key import/export.
- UTXO discovery (mempool.space Esplora), fee estimate, coin selection,
  change, dust, signing, serialization, TxID, broadcast, confirmation status.
- UI receive/send with explicit network and address type.

## Regtest evidence (Bitcoin Core v32.1.0)

Performed on 2026-11-13:

- Node: Bitcoin Core `v32.1.0`, `-regtest`, `-txindex=1`.
- X-Wallet derived P2PKH address `mkpZhYtJu2r87Js3pDiWJDmPte2NRZ8bJV`.
- Mined 101 regtest blocks to that address.
- X-Wallet built and signed a 1 BTC transaction to
  `mzpbWabUQm1w8ijuJnAof5eiSTep27deVH`.
- TxID: `4214819c5ab5e6385e072df22b791d5248c48fc16154cd9313435e2b0aedc5da`.
- Fee: 452 sats. Change: 48.99999548 BTC to
  `mi8nhzZgGZQthq6DQHbru9crMDerUdTKva`.
- Broadcast accepted by Bitcoin Core; mined in block
  `693d18deb2e71f75a26de6d896cca2d50cc2b9e6a479af357738325d360b5eab`.
- After restart, `getrawtransaction` showed 1 confirmation and
  `scantxoutset` found both outputs.
- Independent `tiny-secp256k1` verification: **PASS**.

## Evidence levels

- Official vectors: B.
- Independent address/tx comparison: F (bitcoinjs-lib).
- Regtest: **D PASS** (BTC only).
- Live testnet: **NOT PERFORMED**.
- Physical device: **NOT PERFORMED**.
- Independent audit: **NOT PERFORMED**.

## Unsupported

- PSBT, descriptors, xprv/xpub, watch-only, RBF bumping, gap-limit discovery.
- Taproot script-path.
- Regtest integration.
