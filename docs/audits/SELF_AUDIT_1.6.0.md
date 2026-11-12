# Self-audit — X Wallet 1.6.0

**This is a development self-audit. It is not an independent third-party
audit and does not certify large-holding use.**

Scope: the 1.6.0 changes on top of `1.5.5+17`, plus the shared signing, vault,
network and release paths they touch.

## Findings and fixes

| ID | Severity | Finding | Fix | Regression evidence |
|---|---|---|---|---|
| SA-01 | High (blocker for Ethereum) | The cold signer accepted only chain IDs 56/97 in three separate places. Ethereum requests would be rejected or a future chain could bypass the registry. | All cold checks use `Chains.byChainId`; the codec’s supported set is the chain registry and is unmodifiable. | `test/ethereum_signing_test.dart` |
| SA-02 | High | The explorer API key was a single BscScan key. Switching to Ethereum would have reused it for Etherscan. | Per-chain secure keys (`explorer_api_key_<chainId>`), family getter, legacy BSC migration, erase-all clears every key. | `test/explorer_history_test.dart`; `test/chains_test.dart` |
| SA-03 | High | Default-token de-duplication was address-only, not `(network, address)`. The same address on two chains could hide or merge a token. | `addToken` and `withDefaultTokens` compare network and address. | `test/default_tokens_test.dart` |
| SA-04 | Medium | The send page cached the native asset as a `const` BNB token. After a network switch the picker could show BNB on Ethereum. | Native asset is a per-chain cached object; a network change resets a native selection. | `test/navigation_flow_test.dart`, `test/chains_test.dart` |
| SA-05 | Medium | A pinned price provider silently fell back to another provider, so the UI could claim one source while using another. | Pinned providers are the only ones contacted; failure sets `lastError` and leaves stale prices. | `test/price_provider_test.dart` |
| SA-06 | Medium | Home/Send/Wallet/Receipt screens hardcoded “BNB/BSC”, which would mislabel Ethereum balances and fee warnings. | Chain-aware labels from `ChainSpec`; native symbol and chain name are dynamic. | `flutter analyze`; widget navigation test |
| SA-07 | Low | `BnbNetworks` was the only network table; adding Ethereum by editing each call site invited drift. | One `Chains` registry; `BnbNetworks` delegates. | `test/chains_test.dart` |
| SA-08 | Low | Token registry and logos were BSC-only. | Ethereum USDT/USDC/XAUT entries and address-aware labels. | `test/chains_test.dart` |
| SA-09 | Low | History error text named BscScan on Ethereum. | Chain-specific API host and key message. | `test/explorer_history_test.dart` |
| SA-10 | **Critical** | The selected RPC node was stored in one global `rpc` preference. After using BNB and switching to Ethereum, a restart could load the BNB node as the Ethereum node. | Per-chain `rpc_<network>` storage; legacy key migrated only to BNB mainnet; switching restores that chain’s saved node and never overwrites another chain. | `test/chains_test.dart` (“a BNB node never becomes the Ethereum node”) |

## Attacks attempted

| Attack | Result |
|---|---|
| Unlock vault A with vault B’s password | Different salts/keys and per-vault password verification; existing multi-vault test passes. |
| Change a transaction after approval | `SendIntent.verify` binds chain, sender, nonce, recipient, amount, token, calldata and fee; existing and new tests reject substitution. |
| Sign on the wrong chain | Cold and hot paths take the chain ID from the reviewed request; chain ID is part of the signed payload. New tests sign chain 1 and chain 56 and get different hashes. |
| Reuse a BscScan key on Etherscan | The family getter returns only the Ethereum key; test proves a BSC-only key cannot read Ethereum history. |
| Leak a wallet address to a price provider | Price requests contain only fixed symbols/IDs; no address parameter exists. Code-based review, no packet capture. |
| Recover a deleted secret from the handoff | Handoff contains only passphrase-protected keys; verification checks the GPG key is protected. Physical storage erasure is not provable. |
| Make the release gate accept incomplete evidence | The strict gate and identity validator reject missing checks, status, hashes and commit mismatches; negative tests remain. |

## Residual risks (not fixed)

1. **RPC trust:** a lying RPC can misreport balances, nonces, fees and history.
   The local signature cannot be forged, but the review screen can be misled.
2. **Dart memory:** GC and string immutability prevent a zeroisation guarantee.
3. **No independent audit / rebuild / physical Android / two-device cold test /
   screen-reader session.**
4. **Hardware wallet and multisig:** not implemented. Do not describe the
   password vault as either.
5. **Explorer and price providers** learn the queried address (explorer) or
   source IP (all). Tor/proxy is optional, not mandatory.
6. **Cold path supports type-2 transactions only;** the hot path also supports
   legacy fees. This is a scope boundary, not a hidden fallback.
7. **Android release signing** is still built locally, not CI-signed.

## Readiness

`LIMITED REAL-WORLD USE` for small amounts after all automated gates pass.
**Not** `INDEPENDENTLY REVIEWED`, **not** `LARGE-HOLDING READINESS CANDIDATE`.
