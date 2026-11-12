# Cryptographic verification — 2.0.0 branch

## Verified by official vectors

| Standard | Vector | Result |
|---|---|---|
| BIP39 | `abandon … about` seed | Used by all derived vectors |
| BIP44 | `m/44'/0'/0'/0/0` | `1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA` PASS |
| BIP49 | `m/49'/0'/0'/0/0` | `37VucYSaXLCAsxYyAPfbSi9eh4iEcbShgf` PASS |
| BIP84 | `m/84'/0'/0'/0/0` | `bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu` PASS |
| BIP86 | `m/86'/0'/0'/0/0` | `bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr` PASS |

## Independent comparison

- 16/16 addresses matched `bitcoinjs-lib` 6.1.7 + `bip32` 4.0.0 +
  `tiny-secp256k1` 2.2.3.
- 4/4 transactions matched for input/output set, sums and TxID.
- One defect found: BTC testnet BIP86 used coin type 0. Fixed.

## Not verified

- ECDSA and Schnorr signature validity against an independent verifier.
- Taproot script-path spending.
- Malformed signature/script fuzzing.
- Side-channel behaviour of the underlying libraries.
- Independent review of `bitcoin_base`/`blockchain_utils`.

A correct address and TxID do not prove a valid signature. Signature
verification remains an explicit open item.
