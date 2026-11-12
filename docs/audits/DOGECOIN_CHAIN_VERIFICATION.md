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

## Regtest evidence (Dogecoin Core v1.14.9)

- Node: Dogecoin Core `v1.14.9`, `-regtest`, `-txindex=1`.
- X-Wallet P2PKH address: `mkpZhYtJu2r87Js3pDiWJDmPte2NRZ8bJV`.
- Mined 101 regtest blocks to it.
- X-Wallet signed 1 DOGE to `mzpbWabUQm1w8ijuJnAof5eiSTep27deVH`.
- TxID: `fdcddc05086bc38252da3d13f916581f32c6e744ca95ac0e5d7cde39b2674ef3`.
- Fee: 22,600 sats (0.000226 DOGE). Change: 499,998.999774 DOGE.
- Block: `38fb37b8b4003cb1c26459470b69848f682a78a652337dd12c34e4d321569137`.
- After node restart: 1 confirmation.
- Independent `tiny-secp256k1` ECDSA verification: **PASS**.

## Evidence levels

- Address/tx build tests: B.
- Independent comparison: F for P2PKH address and tx serialization.
- Regtest: **D PASS**.
- Live testnet: **NOT PERFORMED**.
- Physical device: **NOT PERFORMED**.
