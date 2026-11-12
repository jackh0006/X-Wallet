# Final update scope — 2.0.0 development branch

Date: 2026-11-13
Stable release preserved: **X Wallet 1.6.0+18**, tag `v1.6.0`,
commit `881e6b62c530ee7565fff947009d663cada5e596`.
Development branch: `release/2.0.0`.

## What this branch adds

- A real, persisted **network kill switch** that blocks RPC, explorer and
  price requests before any socket is opened. It is enforced in
  `RpcService._ensureOnline`, `RpcService.connect` and `PriceService.refresh`.
- Four regression tests in `test/network_kill_switch_test.dart`.
- Documentation of the exact scope and the remaining gaps.

## What is NOT implemented

The requested final update names Bitcoin, Litecoin and Dogecoin support,
custom UTXO networks, PSBT, descriptor wallets, hardware wallets, multisig and
an independent audit. None of these are implemented on this branch.

| Requested item | Status | Why it is not claimed |
|---|---|---|
| BTC P2PKH/P2SH/P2WPKH/P2TR | **NOT IMPLEMENTED** | Requires a reviewed UTXO library, address/script codec, coin selection, PSBT and testnet evidence. Adding it without those would be unsafe. |
| BTC PSBT / descriptors | **NOT IMPLEMENTED** | Same. |
| LTC mainnet/testnet | **NOT IMPLEMENTED** | Requires chain-specific prefixes, WIF, script and network parameters plus testnet evidence. |
| DOGE mainnet/testnet | **NOT IMPLEMENTED** | Requires chain-specific prefixes, WIF and serialization plus testnet evidence. |
| Custom UTXO networks | **NOT IMPLEMENTED** | No UTXO engine exists. |
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
