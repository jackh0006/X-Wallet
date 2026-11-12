# Final update scope — 2.0.0 development branch

Date: 2026-11-13
Stable release preserved: **X Wallet 1.6.0+18**, tag `v1.6.0`,
commit `881e6b62c530ee7565fff947009d663cada5e596`.
Development branch: `release/2.0.0`.

## What this branch adds

- A real, persisted **network kill switch** that blocks RPC, explorer and
  price requests before any socket is opened. It is enforced in
  `RpcService._ensureOnline`, `RpcService.connect` and `PriceService.refresh`.
- **Bitcoin/Litecoin/Dogecoin core:** BIP44/49/84/86 derivation, P2PKH,
  P2SH-P2WPKH, P2WPKH and P2TR addresses, WIF/raw key import/export, UTXO
  discovery, fee estimate, coin selection, change, signing, serialization,
  TxID and broadcast. UI at `lib/screens/utxo_page.dart`.
- Official BIP44/49/84/86 address vectors, transaction build/sign tests,
  UTXO/fee/broadcast parsing tests and kill-switch tests.
- Documentation of the exact scope and the remaining gaps.

## What is NOT implemented

The requested final update names Bitcoin, Litecoin and Dogecoin support,
custom UTXO networks, PSBT, descriptor wallets, hardware wallets, multisig and
an independent audit. None of these are implemented on this branch.

| Requested item | Status | Why it is not claimed |
|---|---|---|
| BTC derivation/addresses/transactions | **IMPLEMENTED (core)** | `lib/utxo/`; official vectors and transaction tests pass. |
| BTC PSBT / descriptors / xprv | **NOT IMPLEMENTED** | Requires BIP174/BIP380 integration and physical two-device evidence. |
| LTC mainnet/testnet | **IMPLEMENTED (core)** | Derivation, addresses, WIF, UTXO fetch, build/sign/broadcast. No live testnet evidence. |
| DOGE mainnet/testnet | **IMPLEMENTED (core)** | P2PKH, WIF, UTXO fetch, build/sign/broadcast. No live testnet evidence. |
| Live testnet send/receive | **NOT PERFORMED** | Requires funded testnet UTXOs and a controlled node. |
| Custom UTXO networks | **NOT IMPLEMENTED** | No custom UTXO parameter UI. |
| Hardware wallet | **NOT IMPLEMENTED** | No standard protocol integration was added. |
| Multisig/threshold custody | **NOT IMPLEMENTED** | No reviewed standard contract/descriptor was added. |
| Independent audit | **NOT PERFORMED** | Cannot be produced by the development agent. |
| Independent rebuild | **NOT PERFORMED** | Requires a separate machine. |
| Physical device / two-device cold test | **NOT PERFORMED** | Requires hardware. |
| Packet capture | **NOT PERFORMED** | Requires a controlled capture environment. |

## Why this is not released as 2.0.0 stable

A 2.0.0 stable tag without BTC/LTC/DOGE and without independent review would
be a false claim. The stable branch remains **1.6.0**. This branch is a
development candidate only.

## Readiness

**NOT READY** for the requested multi-chain final release.
`1.6.0` remains **LIMITED REAL-WORLD USE — SMALL AMOUNTS ONLY**.
