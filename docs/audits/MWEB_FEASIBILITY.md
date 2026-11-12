# Litecoin MWEB feasibility — audit

Status: **NOT IMPLEMENTED.** This record explains why, and the only safe path
found.

## Findings

1. **No Dart MWEB implementation is available.**
   `pub.dev` has no MWEB protocol package. The closest packages are:
   - `mweb_client` 0.2.0 — a gRPC client for an external `mwebd` daemon.
   - `flutter_mwebd` 0.0.1-pre.12 — a wrapper for `mwebd-wrapper`.
   Neither implements MWEB inside the wallet; both require an external daemon.

2. **Litecoin Core 0.21.4 has MWEB wallet support.**
   `getnewaddress` accepts `"mweb"`, so Core can create MWEB addresses. But
   X-Wallet uses Esplora/LitecoinSpace, not a Litecoin Core wallet RPC. The
   indexer does not expose MWEB outputs, slates or peg transactions.

3. **MWEB is a separate protocol.**
   It has its own address encoding, blinding factors, scan/spend keys, slates,
   peg-in/peg-out and extension-block rules. It is not a prefix or script
   variant of transparent LTC.

4. **The daemon path changes the trust model.**
   An `mwebd` integration would send MWEB key material or signing requests to a
   local daemon over gRPC. That daemon must be installed, configured, isolated
   and audited. It is not equivalent to the current on-device signing model.

5. **No test environment is available here.**
   `mwebd` is not installed, and no MWEB testnet workflow was run. Claiming
   MWEB support without an actual MWEB transaction would be false.

## Options

### A. External `mwebd` daemon (possible, not implemented)
- Add `mweb_client`/gRPC dependencies.
- Add a local-only `mwebd` configuration and connection test.
- Keep MWEB keys out of logs; document that the daemon sees them.
- Prove with a real MWEB test transaction.
- Requires a separate trust/security review.

### B. Litecoin Core wallet RPC (not self-custodial)
- Connect to a user-controlled Litecoin Core wallet.
- Core holds the MWEB keys.
- This is a node-wallet mode, not the X-Wallet vault model.
- Must be labelled separately.

### C. Implement MWEB from scratch (not recommended)
- Reimplementing MWEB cryptography and slates is high-risk and out of scope.

## Decision

**Do not add MWEB to X-Wallet 2.0.0.**

The UI now says:
> MWEB is NOT supported. This wallet handles transparent Litecoin only. Do not
> send MWEB funds to these addresses.

This is safer than a half-working integration.

## What would be required to reverse this

1. Pin and review `mweb_client` and `mwebd`.
2. Define the key-handling boundary and isolation.
3. Add a local-only daemon setting with explicit disclosure.
4. Implement receive/send/recovery and failure handling.
5. Run MWEB testnet transactions and independently verify them.
6. Obtain a separate MWEB security review.
