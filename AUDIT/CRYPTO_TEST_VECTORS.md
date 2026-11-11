# Cryptographic test vectors

| Vector / property | Source | Status |
|---|---|---|
| BIP-39 Trezor vector 1 seed (passphrase `TREZOR`) | official BIP-39 vectors | **PASS** (`test/audit_regressions_test.dart`) |
| BIP-39 “abandon…about” first Ethereum address | independent known vector | **PASS** (`test/audit_regressions_test.dart`) |
| BIP-39 checksum/wordlist rejection | library + test | **PASS** (`test/wallet_core_test.dart`) |
| EIP-55 five official vectors | EIP-55 | **PASS** (`test/wallet_core_test.dart`) |
| EIP-55 mixed-case typo rejection | new audit test | **PASS** (`test/audit_regressions_test.dart`) |
| EIP-1559 digest/raw/r/s/hash | ethers.js 6.17.0 | **PASS** (`verification/verify.cjs`, one fixture) |
| RFC-6979 deterministic signing | property test | **PASS** |
| low-s rejection | cold codec test | **PASS** |
| Argon2id RFC 9106 vector | RFC 9106 | **NOT RUN** |
| Official BIP-32 xprv/xpub chain vectors | BIP-32 | **NOT RUN** |
| Wycheproof XChaCha20-Poly1305 / ECDSA | Project Wycheproof | **NOT RUN** |
| 24-word known-address vector | independent | **NOT RUN** |
| Cross-implementation random differential fuzz (thousands of txs) | ethers.js | **NOT RUN**; only one static fixture |

The cold-signature fixture is a real independent cross-check, but it is one vector. It proves the published bytes, not the whole codec over random inputs.
