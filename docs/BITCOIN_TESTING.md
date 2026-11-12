# Bitcoin / Litecoin / Dogecoin testing record

Commit: development branch `release/2.0.0`.
Environment: Ubuntu 24.04, Flutter 3.47.6, Dart 3.13.5.

## Automated tests

```bash
flutter test --concurrency=1 \
  test/utxo_wallet_test.dart \
  test/utxo_transaction_test.dart \
  test/utxo_service_test.dart \
  test/utxo_page_test.dart
```

Result: **32/32 passed**.

### Vectors

- BIP44 `m/44'/0'/0'/0/0` → `1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA`
- BIP49 `m/49'/0'/0'/0/0` → `37VucYSaXLCAsxYyAPfbSi9eh4iEcbShgf`
- BIP84 `m/84'/0'/0'/0/0` → `bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu`
- BIP86 `m/86'/0'/0'/0/0` → `bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr`

These are copied from the published BIPs. The BIP86 vector caught a wrong
generic derivation path during development; the implementation now uses the
BIP-specific classes.

### Transaction tests

- BTC P2PKH, P2SH-P2WPKH, P2WPKH, P2TR build/sign.
- LTC P2PKH/P2WPKH build/sign.
- DOGE P2PKH build/sign.
- fee + change + amount equals selected input total.
- deterministic raw transaction and TxID for repeated identical input.
- wrong-network recipient, insufficient funds, zero amount, unconfirmed-only
  and no-UTXO cases are refused.

### Indexer tests

Mock HTTP only:

- Esplora UTXO JSON, fee-estimates and `/tx` broadcast.
- BlockCypher Dogecoin `txrefs` and `/txs/push`.
- Malformed responses and invalid raw hex are refused.
- Network kill switch blocks before any request.
- Esplora transaction status and BlockCypher confirmation count parsing.

## Independent comparison

Using Node 24, `bitcoinjs-lib` 6.1.7, `bip32` 4.0.0 and `tiny-secp256k1` 2.2.3:

- 16/16 derived addresses matched for BTC/LTC/DOGE mainnet/testnet and all
  supported address kinds after fixing the BTC-testnet BIP86 coin-type bug.
- 4/4 raw transactions matched for version, inputs, output set, output sum,
  and TxID.
- See `docs/audits/UTXO_INDEPENDENT_VERIFICATION.md`.

Signature validity and live testnet inclusion were **not** independently
verified.

## Evidence level

- **B** automated unit tests.
- **A** source inspection.
- **D** regtest/testnet: **NOT PERFORMED**.
- **E** physical device: **NOT PERFORMED**.
- **F** independent implementation comparison: **NOT PERFORMED**.
- **G** independent audit: **NOT PERFORMED**.

## What is not proven

No testnet coins were funded, no transaction was broadcast to a live network,
and no second implementation was used to compare signed bytes. The tests prove
the local logic and response parsing, not a live transfer.
