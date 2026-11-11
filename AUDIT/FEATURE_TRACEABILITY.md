# Feature traceability

Every user-facing feature is traced to its UI entry, logic, storage, crypto,
network path, tests and docs. “Consistent” means the parts agree in the source
and tests; it does not mean independently audited.

| Feature | UI | Logic | Storage | Crypto | Network | Tests | Docs |
|---|---|---|---|---|---|---|---|
| Create wallet | Wallet page | AppState.saveVaultAccount | vault | BIP-39/BIP-32 | none | wallet_core, vault, backup | README, CRYPTO |
| Import phrase | Wallet page | AppState | vault | BIP-39 | none | wallet_core | README |
| Import private key | Wallet page | AppState | vault | secp256k1 | none | wallet_core, cold | README |
| Unlock/lock | lock screen / dialogs | AppState | vault | Argon2/AEAD | none | vault, drawer | CRYPTO |
| Multi-account | Wallet manager | AppState | vault | same | none | vault_multi_wallet | README |
| Multi-vault | Settings → Vaults | AppState | registry | per-vault | none | multi_vault | README |
| Change password | Settings → Vaults | AppState | vault | Argon2/AEAD | none | multi_vault, vault | README |
| Portable backup | Settings | AppState | file | BNBBKP01 | none | portable_backup | BACKUP |
| Restore | Settings | AppState.importVault | vault | BNBBKP01 | none | portable_backup, import | BACKUP |
| Send BNB | Send page | SendIntent/RpcService | pending | sign | RPC | send_intent, tx_lifecycle | README |
| Send ERC-20 | Send page | decode/SendIntent | pending | sign | RPC | send_intent, hardening | README |
| Approve/allowance | Send page | decode | pending | sign | RPC | hardening, audit | TRANSACTION |
| Fees | Send page | FeeEngine | prefs | none | multi-node | fee_engine | README |
| Receive/QR | Wallet page | qr_flutter | none | none | none | widget | README |
| Activity/receipts | Activity | stores | encrypted | wallet key | none | receipt/log | PRIVACY |
| Tor/SOCKS/proxy | Settings | RpcService/privacy_client | prefs/keyring | TLS | network | privacy/tls/startup | NETWORK |
| Cold pairing | Cold dialogs | protocol | prefs | fingerprints | none | cold_protocol | COLD |
| Cold sign | Cold dialogs | codec/service | request | secp256k1 | none | cold_* | COLD |
| Cold broadcast | Cold dialogs | service | pending | verify | RPC | cold_service | COLD |
| Erase all | Settings | AppState/Storage | all | shred | none | erase_all | PRIVACY |
| Android/desktop | platform | Flutter | platform | platform | platform | source checks | ANDROID/LINUX |

## Disconnected or partial

- `resetVaultPath` is a no-op once a registry entry exists.
- `privateKeyWIF`/`privateKeyFromWIF` are dead and incorrect.
- `broadcastToMultiple`, `batchedRpcCalls`, `sendDustTransaction` have no UI.
- `deriveAddressesCustomPath` is dead; cold flow ignores custom paths.
- Message signing (EIP-191/712) is not implemented.
- Token approval list/revoke is not implemented.
