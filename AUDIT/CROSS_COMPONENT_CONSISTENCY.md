# Cross-component consistency

| Flow | UI | Logic | Storage | Crypto | Network | Test | Verdict |
|---|---|---|---|---|---|---|---|
| Create wallet | yes | yes | vault | BIP-39 | none | yes | consistent |
| Unlock | yes | yes | vault | Argon2/AEAD | none | yes | consistent |
| Send native | yes | SendIntent | pending | sign | RPC | yes | consistent |
| Send ERC-20 | yes | decode | pending | sign | RPC | yes | contract now shown |
| Approve | yes | decode | pending | sign | RPC | yes | spender/contract fixed |
| Cold sign | yes | codec | request | sign | none | yes | policy/chain fixed |
| Cold broadcast | yes | verify | pending | verify | RPC | yes | chain/policy fixed |
| Portable backup | yes | import/export | file | Argon2/AEAD | none | yes | fast-KDF test only |
| Multi-vault | yes | AppState | registry | per-vault | none | yes | registry atomicity gap |
| Erase | yes | AppState | all | shred | none | yes | legacy dirs gap |
| Tor route | yes | RpcService | prefs | TLS | SOCKS | partly | per-node fallback fixed |

## Known inconsistencies

- Tag/docs/evidence commit chain (see RELEASE_TRACEABILITY).
- `release/package-smoke.json` is 1.5.1.
- README historical rows and fixed-path hash.
- Android CI Gradle output is debug-signed (upload removed in this branch).
