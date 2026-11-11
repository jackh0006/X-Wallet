# Cold signing audit

## Protocol

- Canonical JSON, versioned, allow-listed fields, SHA-256 checksum; payload limits 8/16/32 KiB.
- Request expiry 30 min default, 24 h max, 5 min future/skew tolerance.
- Response verification: field-by-field vs the pending request, canonical RLP, transaction hash, signature recovery, signer address, request ID and pending state.
- Signer can only sign an address derived from its own seed; `from` must match the key and the recovered signer.

## Fixed in this audit branch

- ERC-20 approve/increaseAllowance/transferFrom now bind `assetInfo.contractAddress` to `request.to`.
- Cold review displays the token contract and the unknown-token warning.
- Cold signing/broadcast now enforce `SpendingPolicy`.
- Cold broadcast refuses a chain mismatch.

## Remaining

- Pairing authentication is advisory: a 4-byte fingerprint of address[0], manual visual comparison only; addresses 1..N are not bound.
- Request-ID/signature replay lists are capped at 20; after eviction an old ID can be re-signed within its expiry window.
- Derivation path/passphrase are hard-coded; custom-path wallets may not match.
- A signature older than request expiry is still broadcastable.
- Cold timeout/unknown broadcast does not persist a raw hash or a pending row.
- No physical two-device test; the flow is automated/mock-tested only.
