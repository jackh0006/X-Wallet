# Self-audit — UTXO implementation (2.0.0 branch)

Not an independent audit. Scope: `lib/utxo/`, `lib/screens/utxo_page.dart`,
their tests and network call paths.

## Findings and fixes

| ID | Severity | Finding | Fix | Evidence |
|---|---|---|---|---|
| U-01 | **High** | The generic `Bip32Slip10Secp256k1.derivePath("m/86'/...")` produced the wrong Taproot internal key (`30d54f…` instead of BIP86 `cc8a4b…`). | Derivation now uses the BIP-specific `Bip44`, `Bip49`, `Bip84`, `Bip86` classes. | `utxo_wallet_test.dart` official BIP86 vector |
| U-02 | **High** | The initial UTXO service used a direct `http` client path that the data-boundary test could not distinguish from an unapproved client. | Service uses an injected client that defaults to `createRpcClient()` and is named `_transport`; test allowlist documents it. | `data_boundary_test.dart` PASS |
| U-03 | Medium | Amounts below the network dust threshold could be signed. | `UtxoTransactionEngine` refuses below `dustSatoshi`. | transaction tests |
| U-04 | Medium | UTXO entries accepted any 64-character string, not only hex. | Strict 64-hex txid and non-negative vout validation. | service tests |
| U-05 | Medium | No confirmation tracking after broadcast. | Esplora status and BlockCypher confirmations added to service and UI. | service tests |
| U-06 | Low | Change dust was handled by silently adding it to the fee. | Documented; user sees the fee/change in review. A future UI should show “dust added to fee”. | code + docs |
| U-07 | Low | P2TR signing had no direct signature-verification test; only build/deterministic tests. | **Open**: needs an independent P2TR spend vector. | — |
| U-08 | High | No live testnet transaction was performed. | **Blocked**: no funded testnet UTXOs. | — |
| U-09 | **High** | BTC testnet P2TR used mainnet BIP86 coin type 0. | Select `Bip86Coins.bitcoinTestnet` when `isTestnet`; regression test added. | `utxo_wallet_test.dart` + independent 16/16 comparison |
| U-10 | Medium | Signature validity was not checked by an independent verifier. | **Open**: independent ECDSA/Schnorr verification still required. | — |

## Spending-path review

- Inputs are limited to confirmed UTXOs with positive value.
- Coin selection is largest-first; fee is estimated with the actual input and
  output shape at each step.
- Change is paid to the internal branch of the same account.
- The final fee plus change plus recipient equals the selected input total.
- The builder is given the exact reviewed recipient and amount.
- P2SH-P2WPKH, P2WPKH and P2TR use the library’s script/transaction builder.
- P2TR signing uses `signBip340` with the default key tweak, which matches the
  tweaked address generation.
- DOGE uses P2PKH only; no SegWit/Taproot is exposed.
- LTC uses P2PKH/P2SH-P2WPKH/P2WPKH only.
- Broadcast is a node acceptance result, not confirmation; the UI tracks
  confirmation separately.

## Open risks

1. P2TR signature interoperability is not independently verified.
2. No live testnet transaction or independent decoder.
3. No PSBT, descriptors, xprv/xpub, watch-only, RBF bumping or gap-limit
   discovery.
4. UTXO indexers learn the public address and source IP unless Tor/proxy is
   used.
5. No physical device test.
6. No independent audit.
