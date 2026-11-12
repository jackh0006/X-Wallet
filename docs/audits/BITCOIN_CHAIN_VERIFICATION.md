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

## Evidence

- Official vectors: B.
- Independent address/tx comparison: F (bitcoinjs-lib).
- Mock indexer tests: B.
- Live testnet: **D NOT PERFORMED**.
- Physical device: **E NOT PERFORMED**.
- Independent audit: **G NOT PERFORMED**.

## Unsupported

- PSBT, descriptors, xprv/xpub, watch-only, RBF bumping, gap-limit discovery.
- Taproot script-path.
- Regtest integration.
