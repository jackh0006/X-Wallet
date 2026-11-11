# Transaction security audit

## What is verified

- Review and signed object share the same locals; `SendIntent.verify` binds chain ID, positive gas limit, recipient, value, exact calldata and the exact fee pair (`test/send_intent_test`).
- Chain ID is checked on connect/probe and bound into the signed transaction (EIP-155/1559).
- ERC-20 `transfer` requires exact 8+64+64 calldata, a clean address word and zero native value.
- `approve`/`increaseAllowance`/`transferFrom` decode the spender/recipient and amount; unlimited is flagged at ≥2^255.
- Signed bytes are persisted before broadcast; a returned hash mismatch is marked unknown; an unknown row blocks new sends.
- Cancel signs an explicit zero value and passes verification (`test/hardening_regressions_test`).
- Hold-to-confirm (1.6 s + typed word) is required; message signing (`personal_sign`/EIP-712) is absent, which removes that attack surface.

## Fixed in this audit branch

1. **Critical — cold ERC-20 contract binding.** `approve`/`increaseAllowance`/`transferFrom` did not compare `assetInfo.contractAddress` with `request.to`, so a request could display token A while signing an allowance on token B. The decoder now requires a match (`_requireTokenContract`) and the cold review shows the token contract. New test: mismatched approve is refused.
2. **High — cold spending policy bypass.** Cold signing and cold broadcast now call `SpendingPolicy.rejection`; a frozen wallet/allowlist/limit applies offline too.
3. **High — unknown broadcast could be removed after 120 s**, clearing the guard and allowing a second payment. Unknown rows can no longer be removed from the pending card; only "Check" remains.
4. **High — cold broadcast had no chain check.** It now refuses a request whose `chainId` differs from the connected network.
5. **Medium — EIP-55 input was not validated.** A mixed-case typo was silently re-checksummed. `WalletCore.isChecksumValid` now rejects it; all-lower/upper remain accepted.
6. **Medium — hot review omitted the token contract.** The review now shows the full contract and the registry warning.

## Remaining

- `SendIntent.verify` still omits nonce and `from`; `signOnly` re-reads `rpc.chainId` after verification. A network switch in the await gap could sign a different chain than verified.
- Nonce is fetched before review and can go stale; there is no reservation against locally tracked `broadcast` rows or gap detection.
- Speed-up/cancel unknown outcomes are not persisted with `rawHex`; a timeout there can still be retried manually.
- Fee safety has no hard ceiling or fee/value ratio; custom fee parsing accepts `1e3`/`Infinity`.
- Cold pairing fingerprint is 4 bytes of the first address only; the rest of the address list is unauthenticated.
- Cold derivation hard-codes `m/44'/60'/0'/0/{0..19}` and ignores a stored custom path/passphrase.
- Cold replay lists are capped at 20.
- No widget/integration test drives review → hold → sign → broadcast.
