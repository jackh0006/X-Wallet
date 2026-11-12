# Bitcoin support — status

## Implemented

- Networks: Bitcoin mainnet and testnet (`lib/utxo/utxo_network.dart`).
- BIP39 seed derivation from the wallet recovery phrase.
- BIP32 derivation through the standard purpose paths:
  - BIP44 `m/44'/0'/account'/change/index` (P2PKH)
  - BIP49 `m/49'/0'/account'/change/index` (P2SH-P2WPKH)
  - BIP84 `m/84'/0'/account'/change/index` (P2WPKH)
  - BIP86 `m/86'/0'/account'/change/index` (P2TR)
- Address validation for P2PKH, P2SH, P2WPKH and P2TR.
- WIF import/export (compressed and uncompressed) and raw hex import.
- UTXO discovery through mempool.space Esplora.
- Fee estimate from mempool.space.
- Integer-satoshi coin selection, change, dust handling, fee calculation.
- Transaction construction, signing (ECDSA and Schnorr), serialization,
  transaction ID and broadcast.
- A UI screen for receive, UTXO balance, review and send.

## Verified by automated tests

- Official BIP44, BIP49, BIP84 and BIP86 first-address vectors.
- Testnet `tb1q` derivation.
- WIF round-trip and wrong-network rejection.
- P2PKH, P2SH-P2WPKH, P2WPKH and P2TR transaction construction/signing.
- Deterministic raw transaction and TxID for the same inputs.
- Insufficient funds, wrong-network recipient, zero amount and unconfirmed-only
  refusal.
- UTXO, fee and broadcast response parsing with mock HTTP.

## NOT implemented / NOT tested

- PSBT export/import and two-device offline signing.
- Output descriptors and xprv/xpub import/export.
- Watch-only wallets.
- Replace-by-fee bumping.
- Account discovery with gap limits.
- Live testnet send/receive evidence.
- Independent implementation comparison.
- Physical device test.
- Custom UTXO network configuration.
- Coin control UI.

Do not describe Bitcoin as fully complete until the missing items have tests
and, for PSBT/offline signing, physical two-device evidence.
