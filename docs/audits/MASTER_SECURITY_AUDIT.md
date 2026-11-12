# Master security audit — 2.0.0 branch

Status: **internal self-audit**, not an independent audit.
Stable preserved: 1.6.0+18 (`881e6b6`, tag `v1.6.0`).
Branch: `release/2.0.0`; starting commit `db656915`.

## Scope

- Existing vault, KDF, storage, EVM, network, cold-wallet and release paths.
- New UTXO registry, derivation, addresses, transactions, indexer calls and UI.
- Network kill switch and privacy routing.

## Critical/high findings

| ID | Severity | Finding | State |
|---|---|---|---|
| U-01 | High | Generic BIP32 path produced a wrong BTC Taproot key | Fixed; official BIP86 vector passes |
| U-09 | High | BTC testnet P2TR used mainnet coin type | Fixed; regression test + independent comparison |
| U-02 | High | UTXO client path evaded the data-boundary detector | Fixed by using the privacy client factory and an audited allowlist |
| U-08 | High | No live testnet transaction | **Blocked**: no funded testnet UTXOs |
| U-10 | Medium | No independent signature verification | **Closed for 4 key-path/legacy fixtures**; script-path and exhaustive sighash matrix still open |
| U-11 | Medium | No PSBT/descriptors/watch-only/RBF | **Not implemented** |

## What the evidence supports

- Official BIP44/49/84/86 address vectors.
- 16/16 address comparison with bitcoinjs-lib/bip32.
- 4/4 raw transaction comparison for inputs, output set, sums and TxID.
- UTXO, fee, broadcast and confirmation parsing with mocks.
- Kill switch blocks UTXO and EVM network requests before sockets.

## What it does not support

- No claim of vulnerability-free code.
- No claim of large-holding safety.
- No live-chain, physical-device, independent-rebuild or independent-audit
  evidence.
- No claim that Litecoin MWEB, Dogecoin SegWit/Taproot or RBF are supported.

## Build evidence

- Linux release build: **PASS** (`flutter build linux --release`) on 2026-11-13.
- Android build: **NOT RUN** on this weak machine.
- Clean install/migration of this branch: **NOT TESTED**.

## Release decision

**DEVELOPMENT — NOT READY.** Stable 1.6.0 remains the only stable release.
