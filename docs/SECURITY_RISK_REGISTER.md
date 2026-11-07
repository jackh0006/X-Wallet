# Security Risk Register

**Last reviewed:** 2026-11-06
**Source commit:** `3aef4b908fded5e92823c76f02d4016265c8bf12`
**Scope:** Linux amd64 EVM wallet (BNB Smart Chain enabled in 1.1.0). Internal self-assessment only.

| ID | Risk | Severity | Impact | Likelihood | Mitigations | Residual risk | Test evidence | Last reviewed |
|---|---|---|---|---|---|---|---|---|
| R-01 | Malware / compromised OS reads unlocked keys | Critical | Total loss | Medium | Auto-lock; `PR_SET_DUMPABLE=0`; core limit; encrypted vault; no plaintext logs | Same-user attacker can read process memory; no secure element | `memory_protection_test`, `encrypted_log_store_test`, `log_canary_test` | 2026-11-06 |
| R-02 | Malicious RPC lies about chain/balance/fees | High | Wrong decision/loss | Medium | Chain-ID check on connect; HTTPS-only; optional Tor; local signing; review screen | No light-client proof; a lying node can mislead | `nodes_test`, `node_manager_test`, `tls_pinning_test`, `rpc_adversarial_test` | 2026-11-06 |
| R-03 | Malicious/non-standard token calldata | High | Loss/misleading review | Medium | Exact 4+32+32 calldata; contract shown; decimals bounds; simulation; fee-on-transfer log check | Contract can still behave unexpectedly | `send_intent_test`, `fuzz_and_property_test`, `tx_lifecycle_test` | 2026-11-06 |
| R-04 | Address poisoning / clipboard substitution | High | Loss | Medium | Full checksummed address; grouped display; affix warning; clipboard guard | User can confirm a wrong valid address | `wallet_core_test`, `clipboard_guard_test`, `send_intent_test` | 2026-11-06 |
| R-05 | Supply-chain compromise | Critical | Total loss | Medium | Lockfiles; pinned action SHAs; SBOM; dependency audit; CodeQL; secret scan | Upstream compromise possible; dependabot pending | `verify` workflow, `dependency-audit.py`, `sbom.py`, `license-check.py` | 2026-11-06 |
| R-06 | Historical Android signing key | High | Distribution authenticity | **Confirmed exposure** | Removed from tree; history scan; allowlist/denylist; release blocked | Rotation **NOT VERIFIED**; denylist empty | `docs/security/INCIDENT_2026-11-KEYSTORE.md`, `secret-scan.sh --history` | 2026-11-06 |
| R-07 | Vault/backup theft | High | Loss if password weak | Low–Medium | Argon2id fixed profile; double wrapper; device secret; fixed header policy | Weak password remains weak; device secret is a local drawer | `vault_test`, `kdf_production_test`, `vault_import_rollback_kdf_test` | 2026-11-06 |
| R-08 | Clipboard substitution | Medium | Loss | Medium | Secret detection; auto-clear; full address review; affix warning | Clipboard is inherently untrusted | `clipboard_guard_test` | 2026-11-06 |
| R-09 | Phishing / social engineering | High | Total loss | Medium | No dapp browser; no remote seed entry; plain-language warnings | User can be tricked into revealing the seed | UI tests, docs | 2026-11-06 |
| R-10 | Physical theft of unlocked session | High | Total loss | Low | Auto-lock; password KDF; device secret | Unlocked session exposed | `navigation_flow_test`, `vault_test` | 2026-11-06 |
| R-11 | Malicious update | Critical | Total loss | Low | GPG-signed `.deb`; `SHA256SUMS`; release gate; provenance workflow | Artifact currently unsigned; user must verify | `release-check.sh`, `release-gate.py` | 2026-11-06 |
| R-12 | Memory inspection / core dump | High | Key disclosure | Medium | `PR_SET_DUMPABLE=0`; `RLIMIT_CORE=0`; best-effort `mlockall` | Dart GC memory cannot be securely erased | `memory_protection_test` | 2026-11-06 |
| R-13 | Offline-signing substitution | High | Wrong signature | Low | Canonical RLP; field-by-field verify; checksum; expiry; replay list; independent ethers.js | Shared codec bug could affect both sides; no two-device test | `cold_tx_codec_test`, `cold_wallet_protocol_test`, `cold_wallet_service_test`, `verification/verify.cjs` | 2026-11-06 |
| R-14 | Non-reproducible artifact | High | Supply-chain uncertainty | Medium | Fixed-path procedure; pinned toolchain; provenance workflow | Different paths differ; no independent-machine proof | `scripts/reproducibility-check.sh`, `docs/IMPLEMENTATION_LOG.md` | 2026-11-06 |
| R-15 | Android APK signed by old identity | Critical | Forged distribution | **Exposure known** | Denylist, owner approval flag, signer verification | Rotation not done; cannot publish | `scripts/verify-android-signer.sh`, incident record | 2026-11-06 |
| R-16 | No independent audit | High | Unknown systemic risk | — | Self-audit, tests, SBOM, gate | No external assurance | Scorecard, threat model | 2026-11-06 |

A finding is not “fixed” because code changed: reproduce the issue, run the
regression, and record the exact commit and result. `VERIFIED` is never used
for a risk that depends on the user's device or operational behavior.
