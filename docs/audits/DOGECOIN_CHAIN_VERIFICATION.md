# Dogecoin chain verification

## Network identity

Values checked against Dogecoin Core `chainparams.cpp`:

| Field | Mainnet | Testnet |
|---|---|---|
| Genesis | `1a91e3dace36e2be…5691` | `bb0a78264637406b…559e` |
| Magic | `c0c0c0c0` | `fcc1b7dc` |
| Port | 22556 | 44556 |
| PoW | Scrypt | Scrypt |
| Difficulty | DigiShield | DigiShield |

AuxPoW merged mining is a consensus feature; it does not merge Dogecoin's
chain identity with Litecoin.

## Implemented

- BIP44 P2PKH derivation, WIF, address validation.
- UTXO discovery (BlockCypher), fee floor, coin selection, change, signing,
  serialization, TxID, broadcast, confirmations.
- UI network/type selection and review.

## Unsupported

- SegWit, Taproot, RBF, PSBT, descriptors, watch-only, regtest.
- Live Dogecoin testnet evidence.
- Independent signature verification.

## Evidence

- Address/tx build tests: B.
- Independent comparison: F for P2PKH address and tx serialization.
- Live testnet: **D NOT PERFORMED**.
- Physical device: **E NOT PERFORMED**.
