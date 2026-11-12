# Feature-to-evidence matrix — 2.0.0 development branch

Evidence levels: **A** source inspection, **B** automated unit tests,
**C** integration tests, **D** live testnet/regtest, **E** physical device,
**F** independent implementation comparison, **G** independent audit.

| Feature | Implementation | Standards | Tests | Level | Status |
|---|---|---|---|---|---|
| BNB mainnet/testnet | `lib/chains.dart`, `lib/rpc_service.dart` | EIP-155, EIP-1559, BEP-20 | existing suite + `chains_test` | B/C | Working |
| Ethereum mainnet/Sepolia | `lib/chains.dart`, shared EVM path | EIP-155, EIP-1559, ERC-20 | `chains_test`, `explorer_history_test`, `ethereum_signing_test` | B | Working; no live-node D |
| Ethereum USDT/USDC/XAUT defaults | `lib/default_tokens.dart` | ERC-20 | `chains_test` | B | Constants verified against issuer docs; user must re-verify |
| Per-chain RPC choice | `lib/storage.dart`, `lib/app_state.dart` | — | `chains_test` | B | Working |
| Per-chain explorer keys | `lib/storage.dart`, `lib/rpc_service.dart` | Etherscan v2 | `explorer_history_test` | B | Working |
| Price provider choice | `lib/price_service.dart` | — | `price_provider_test` | B | Working |
| Network kill switch | `lib/rpc_service.dart`, `lib/price_service.dart` | — | `network_kill_switch_test` | B | Working |
| EVM transaction binding | `lib/send_intent.dart` | EIP-155/1559 | `send_intent_test`, `audit_regressions_test` | B | Working |
| Cold EVM signing | `lib/cold_tx_codec.dart`, `lib/wallet_core.dart` | EIP-1559 | `cold_*`, `ethereum_signing_test` | B | Working; no two-device E |
| Vault encryption | `lib/vault.dart`, `lib/kdf.dart` | Argon2id, XChaCha20-Poly1305 | `vault_test`, `kdf_production_test` | B | Working |
| Multi-vault isolation | `lib/vault.dart`, `lib/app_state.dart` | — | `multi_vault_test` | B | Working |
| Vault rename | `lib/app_state.dart` | — | `vault_rename_test` | B | Working |
| BTC/LTC/DOGE chain identity (genesis, magic, port, PoW) | `lib/utxo/utxo_network.dart` | Core `chainparams.cpp` | `utxo_chain_config_test` | B | Verified against official source |
| BTC P2PKH/P2SH/P2WPKH/P2TR derivation/addresses | `lib/utxo/utxo_wallet.dart` | BIP44/49/84/86 | `utxo_wallet_test` official vectors | B | Working |
| BTC transaction build/sign/broadcast | `lib/utxo/utxo_transaction.dart`, `utxo_service.dart` | Bitcoin tx, ECDSA/Schnorr | `utxo_transaction_test`, `utxo_service_test` | B (mocks) | Working; no testnet D |
| BTC/LTC/DOGE confirmation status | `lib/utxo/utxo_service.dart`, `utxo_page.dart` | Esplora/BlockCypher status | `utxo_service_test` | B | Working; no live D |
| UTXO address derivation vs independent bitcoinjs-lib | `lib/utxo/utxo_wallet.dart` | BIP32/39/44/49/84/86 | `utxo_wallet_test` + 16/16 independent comparison | B/F | Verified against independent implementation |
| UTXO tx serialization/TxID vs independent bitcoinjs-lib | `lib/utxo/utxo_transaction.dart` | Bitcoin tx format | 4/4 independent decode comparison | B/F | Verified; signature validity still not independently checked |
| BTC PSBT/descriptors/offline | — | BIP174/380 | none | — | **NOT IMPLEMENTED** |
| BTC PSBT/descriptors | — | BIP174/BIP380 | none | — | **NOT IMPLEMENTED** |
| LTC mainnet/testnet | `lib/utxo/utxo_network.dart`, `utxo_wallet.dart` | BIP44/49/84, coin type 2' | `utxo_wallet_test`, `utxo_transaction_test` | B | Working; no testnet D |
| LTC PSBT/offline | — | — | none | — | **NOT IMPLEMENTED** |
| DOGE mainnet/testnet | `lib/utxo/utxo_network.dart`, `utxo_wallet.dart` | BIP44, coin type 3' | `utxo_wallet_test`, `utxo_transaction_test` | B | Working; no testnet D |
| DOGE PSBT/offline | — | — | none | — | **NOT IMPLEMENTED** |
| UTXO send/receive UI | `lib/screens/utxo_page.dart` | — | `utxo_page_test` | B | Working; no physical E |
| Custom UTXO networks | — | — | none | — | **NOT IMPLEMENTED** |
| Hardware wallet | — | — | none | — | **NOT IMPLEMENTED** |
| Multisig/threshold | — | — | none | — | **NOT IMPLEMENTED** |
| Independent audit | — | — | — | — | **NOT PERFORMED** |
| Independent rebuild | — | — | — | — | **NOT PERFORMED** |
| Physical Android / two-device cold | — | — | — | — | **NOT PERFORMED** |
| Packet capture | — | — | — | — | **NOT PERFORMED** |

## Rule

No row may be promoted to a higher evidence level without a command, log or
external report. A unit test is not a live-network test. A self-audit is not
an independent audit.
