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

## Regtest evidence (Litecoin Core v0.21.4)

- Node: Litecoin Core `v0.21.4`, `-regtest`, `-txindex=1`.
- X-Wallet P2PKH address: `mkpZhYtJu2r87Js3pDiWJDmPte2NRZ8bJV`.
- Mined 101 regtest blocks to it.
- X-Wallet signed 1 LTC to `mzpbWabUQm1w8ijuJnAof5eiSTep27deVH`.
- TxID: `444770b030bf5f481bd7c548cf3eec7f81f836c5ee9889037fda816a1c7ddfbf`.
- Fee: 452 sats. Change: 48.99999548 LTC.
- Block: `1f30f0ae1efb7f54983bcdf6f38a92ac11aa334410258f527833ea85cac4fd4f`.
- After node restart: 1 confirmation.
- Independent `tiny-secp256k1` ECDSA verification: **PASS**.

## Evidence levels

- Address/tx build tests: B.
- Independent comparison: F for addresses and tx serialization.
- Regtest: **D PASS**.
- Live Litecoin testnet: **NOT PERFORMED**.
- Physical device: **NOT PERFORMED**.
- Independent audit: **NOT PERFORMED**.

## Unsupported

- MWEB, Taproot, PSBT, descriptors, watch-only, RBF, regtest.
