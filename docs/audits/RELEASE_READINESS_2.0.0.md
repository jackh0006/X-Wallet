# Release readiness — 2.0.0

Decision: **DEVELOPMENT — NOT READY**.

| Evidence | BTC | LTC | DOGE | EVM |
|---|---|---|---|---|
| Implemented | Yes | Yes (no MWEB) | Yes (P2PKH only) | Yes |
| Unit-tested | Yes | Yes | Yes | Yes |
| Independently compared | Addresses/tx | Addresses/tx | Address/tx | Partial |
| Signatures independently verified | **No** | **No** | **No** | Partial |
| Regtest | **No** | **No** | **No** | Anvil tests |
| Live testnet | **No** | **No** | **No** | BSC tests only |
| Mainnet-compatible claim | **No** | **No** | **No** | Limited |
| Physical device | **No** | **No** | **No** | **No** |
| Recovery verified on clean install | **No** | **No** | **No** | Partial |
| Independent security audit | **No** | **No** | **No** | **No** |

## Blockers

1. Live testnet send/receive for BTC, LTC and DOGE.
2. Independent ECDSA/Schnorr signature verification.
3. PSBT, descriptors, xprv/xpub, watch-only, gap-limit recovery, RBF.
4. Physical two-device offline signing.
5. MWEB for Litecoin; Dogecoin-specific feature audit beyond P2PKH.
6. Android/Linux build of this branch and clean-install test.
7. Independent professional review.

## Stable

1.6.0+18 remains stable for **small amounts only**. No large-holding claim.
