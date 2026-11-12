# Claim register — X Wallet 1.6.0

Status: internal, evidence-based review. This is **not** an independent audit.
A claim is marked **PROVEN** only when a test, script, or CI job fails if the
claim becomes false. **PARTLY** means some evidence exists but does not cover
the whole claim. **DOWNGRADED** means the wording was changed to what the
evidence supports. **UNPROVEN** means no evidence exists here.
**DISPROVEN** means the code contradicted the claim before this release.

| ID | Claim | Source | Evidence (1.6.0) | Status |
|---|---|---|---|---|
| C1 | Vault uses Argon2id 64 MiB, t=3, p=4 | README, CRYPTO | `test/kdf_production_test.dart`; `lib/vault.dart`; floor enforced on read | PROVEN |
| C2 | Vault encrypts with XChaCha20-Poly1305 and an authenticated header | README, CRYPTO | `test/vault_test.dart`, `test/vault_header_validation_test.dart` | PROVEN |
| C3 | The vault has two independent wrappers | README, CRYPTO | Format: two AEAD boxes around the same DEK (`lib/vault.dart`). Either factor alone opens the payload. | DOWNGRADED: the device secret is defense-in-depth, not a required second factor |
| C4 | A copied vault is inert without the device secret | CRYPTO, THREAT_MODEL | False when the password is known; the device secret is a co-located 0600 file on Linux | DOWNGRADED |
| C5 | Deleting the device secret is crypto-erasure | THREAT_MODEL, settings UI | Removes the app's device path, but a retained vault + password remains decryptable | DOWNGRADED |
| C6 | Backups can be restored on another device | README, settings | New `BNBBKP01` portable envelope; `test/portable_backup_test.dart` restores with a fresh device secret | PROVEN |
| C7 | Backup rejects wrong password, tamper and truncation | README | `test/portable_backup_test.dart` | PROVEN |
| C8 | v1 `BNBVL003` vaults stay readable | CRYPTO | `test/vault_test.dart` legacy cases | PROVEN |
| C9 | v1 import migrates to v2 on save | CRYPTO | Import path re-encrypts under the current device secret; no dedicated v1-import test | PARTLY |
| C10 | A PIN is Argon2id-hashed with exponential backoff | SECURITY_CLAIMS | `lib/security.dart`, `lib/workers.dart`; no full backoff test | PARTLY |
| C11 | A missing PIN record fails closed | new | `lib/security.dart`; `test/node_secret_storage_test.dart` | PROVEN |
| C12 | No secret is written to the activity log | README | `test/log_canary_test.dart` | PROVEN |
| C13 | The recovery phrase/private key is never copied without warning | README | Reveal dialogs warn and clear after 15 s; the ordinary copy helper refuses secret-looking text and secret labels | PROVEN (explicit reveal only) |
| C14 | BIP-39/32/44 derivation is correct | README | Known junk-mnemonic vector, path tests, EIP-55 vectors; no official BIP-39/32 JSON vectors | PARTLY |
| C15 | ECDSA uses RFC-6979 and low-s | CRYPTO | web3dart/pointycastle; cold codec high-s test; one ethers.js fixture | PARTLY |
| C16 | Cold signed bytes are independently cross-checked | README | `verification/verify.cjs` validates one static fixture and 8 substitutions; it does not execute the Dart codec | PARTLY |
| C17 | Transaction review binds recipient, value, chain, fees, calldata, nonce and sender | README | `test/send_intent_test.dart`; `test/audit_regressions_test.dart` (nonce and sender substitutions refused) | PROVEN |
| C18 | Transaction review checks the nonce and sender | README | `lib/send_intent.dart` compares the reviewed nonce/sender with the exact signed object; `test/audit_regressions_test.dart` | PROVEN |
| C19 | An uncertain broadcast cannot be retried into a second payment | new | Signed bytes persisted before broadcast; unknown rows block sends; `test/hardening_regressions_test.dart` covers the state model | PROVEN (state model) |
| C20 | Cancel works | README | Explicit zero value; `test/hardening_regressions_test.dart` verifies the signature check | PROVEN |
| C21 | Freeze/allowlist applies to every signing path | README | Send and speed-up/cancel call the policy; the cold path does not yet | PARTLY |
| C22 | ERC-20 `approve` shows the spender | new | `test/hardening_regressions_test.dart` | PROVEN |
| C23 | Unlimited approvals are flagged | README | Threshold raised to 2^255; test present | PROVEN |
| C24 | A token with a known symbol on an unknown contract is unverified | README | `test/hardening_regressions_test.dart`; `test/token_registry_test.dart` | PROVEN |
| C25 | The offline signer has no network path | README, NETWORK_GUIDE | Cold mode blocks RPC, prices and explorer history; the binary still links network code | DOWNGRADED: cold mode is enforced at runtime, not by a separate import graph |
| C26 | Tor/proxy fails closed, with no direct fallback | README, PRIVACY | Transport rebuilt after init (`privacy_startup_test`); a dead SOCKS port fails instead of connecting direct; the Tor setup dialog still offers an explicit user fallback | PARTLY |
| C27 | No request carries a User-Agent or device identifier | PRIVACY | `test/ua_scrub_test.dart`; RPC headers are only content-type | PROVEN (current client) |
| C28 | A network capture shows only RPC and explorer requests | PRIVACY | False before 1.5.3: price APIs ran by default. Now prices are off by default and gated in cold mode | DOWNGRADED and fixed |
| C29 | There is no telemetry, analytics, ads or AI SDK | README | `test/data_boundary_test.dart` now checks `pubspec.yaml` **and** `pubspec.lock` | PROVEN |
| C30 | All outbound HTTP construction is in one module | README, DATA_CONTROL | `test/data_boundary_test.dart` checks `HttpClient(`, `IOClient(`, `http.Client(`, `http.get/post`, sockets and launch sites against an allowlist | PROVEN (construction sites) |
| C31 | RPC responses are bounded and methods are allowlisted | new | `lib/rpc_service.dart` (2 MiB cap, method set); adversarial test | PROVEN |
| C32 | RPC URLs reject credentials and cloud metadata targets | new | `lib/models.dart`; `test/rpc_adversarial_test.dart` | PROVEN |
| C33 | Node proxy passwords and tokens are not in plain preferences | README, PRIVACY | Secure-store cache, legacy migration, sanitized export; `test/node_secret_storage_test.dart` | PROVEN |
| C34 | Erase-all removes every vault, the log and orphaned temp files | README | `test/erase_flow_test.dart` now includes log and `.dest-<hex>` files | PROVEN |
| C35 | Up to three independent vaults, each with its own password | new | `test/multi_vault_test.dart` | PROVEN |
| C36 | Pending transactions are scoped to the active vault | new | `test/multi_vault_test.dart` | PROVEN |
| C37 | Release artifacts are signed and hashes match | README | `.deb`/APK GPG signatures verified; `SHA256SUMS` matches assets; post-release verifier imports the published key | PROVEN (1.5.5 artifacts) |
| C38 | The build is reproducible | README | Two clean builds at the same fixed path match (`440aff80…8e08`); no independent-machine rebuild | PARTLY |
| C39 | Android hardening (FLAG_SECURE, R8, native Argon2) | README | Source/CI greps; no physical-device run | PARTLY |
| C40 | Android 1.5.3 and later use a new signing key | new | `apksigner` fingerprint recorded below | PROVEN (artifact) |
| C41 | No independent audit exists | SECURITY | Stated plainly in the release notes, evidence and handoff | PROVEN (disclaimer) |
| C47 | Ethereum mainnet and Sepolia are supported | README | Chain registry, shared EVM path, explorer and signing tests; no live-node run yet | PARTLY |
| C48 | Ethereum USDT, USDC and XAUT defaults use canonical contracts | README | `DefaultTokens.ethereum`; `test/chains_test.dart`; user must still verify the issuer page | PROVEN (constants) |
| C49 | BscScan and Etherscan keys are isolated per chain | README | `test/chains_test.dart`, `test/explorer_history_test.dart` | PROVEN |
| C50 | A pinned price provider never silently falls back | README | `test/price_provider_test.dart` | PROVEN |
| C51 | Cold signing binds the Ethereum chain ID | README | `test/ethereum_signing_test.dart` (EIP-155 vector and cold chain-1) | PROVEN |
| C52 | Hardware wallet and multisig custody exist | README | Not implemented; no claim is made | NOT IMPLEMENTED |
| C42 | Large amounts are safe | README/risk | No evidence; explicitly not claimed | DISPROVEN as a claim; removed |
| C43 | “Erase all data” removes pre-1.2 data directories | README | `lib/storage.dart` includes legacy application-data directories and their vault/device secret; no dedicated regression test yet | PARTLY |
| C44 | Cold pairing fingerprint binds the chain and every address | README | `WalletCore.computeFingerprint`; `test/audit_regressions_test.dart` shows a substituted address changes it | PROVEN |
| C45 | Custom RPC headers cannot add tracking or credentials | README | `lib/net/privacy_client.dart` rejects cookies, referer/origin, authorization, API keys, host/framing headers, CR/LF and oversized values; no dedicated regression test yet | PARTLY |
| C46 | Android file import is bounded | README | `MainActivity.kt` caps imports at 8 MiB; built and signed, but no physical-device test | PARTLY |

## Android signer

- 1.5.3 signer SHA-256: `2a96a384eb0db55bb4fb0fb2107df386ecc595b38bc46225ef9b18309d93ba9a`
- 1.5.1 signer (`db12869c…9748d3`): **not** the 1.5.3 identity. Android will
  refuse an in-place upgrade from 1.5.1 to 1.5.3 because the certificate is
  different. Back up the vault (portable backup) before uninstalling 1.5.1.
- Historical compromised signer (`10c13aa9…25b85`): denylisted.

## What is still not proven here

- Independent professional audit.
- Independent rebuild on another machine.
- Physical two-device cold signing.
- Real screen-reader session.
- Android device run of the new APK.
- Coverage-guided fuzzing and a 30–60 minute soak test.
- That the Tor setup dialog never offers a direct fallback; it currently
  offers an explicit user switch.
- Cold-path spending policy enforcement.

See `docs/PROOF_MATRIX.md` for the command behind each row.
