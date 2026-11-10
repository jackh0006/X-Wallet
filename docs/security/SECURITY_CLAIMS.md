# SECURITY_CLAIMS.md — Honest Security Claims and Verification Status

**Date**: 2026-11-04
**Baseline Commit**: `9a057fc005ecfe7df7946bf747497c5ebd03d87b`
**Classification**: **Self-assessed Testnet-ready — NOT production-ready — NO third-party audit**

---

## Claim Classification

| Label | Meaning |
|-------|---------|
| **VERIFIED WITH EVIDENCE** | Independent reproduction possible: packet capture, hardware test, cross-implementation vector, cryptographic proof |
| **TESTED** | Automated test passes in CI/local; code coverage exists |
| **IMPLEMENTED** | Code exists and compiles; no automated test or manual verification |
| **NOT TESTED** | No automated test + no manual verification |
| **BLOCKED** | Explicit dependency prevents verification |
| **NOT SUPPORTED** | Intentionally out of scope |
| **PARTIAL** | Some aspects verified, others not |

---

## Cryptographic Claims

| Claim | Status | Evidence |
|-------|--------|----------|
| Vault uses Argon2id (64 MiB, t=3, p=4) + XChaCha20-Poly1305 | **TESTED** | `lib/vault.dart`, `test/vault_test.dart` (9 tests), `test/kdf_production_test.dart` |
| Argon2id runs on the reference native library, with pure-Dart fallback | **TESTED** | `lib/kdf.dart`, `test/kdf_production_test.dart` (native vs pure-Dart agreement, 344 ms measured) |
| Vault v2 (BNBVL004) has two AEAD wrappers; the password wrapper opens the payload and the device wrapper is defense-in-depth | **TESTED** | `lib/vault.dart`, `test/vault_test.dart` |
| Vault v1 (BNBVL003) read-only migration | **TESTED** | `test/vault_test.dart` legacy blob test |
| Argon2id runs on worker isolate (off UI thread) | **TESTED** | `lib/workers.dart`, `test/workers_test.dart` (3 tests) |
| BIP-39 seed generation (24 words, CSPRNG) | **TESTED** | `lib/wallet_core.dart`, `test/wallet_core_test.dart` |
| BIP-32/44 derivation (m/44'/60'/0'/0/i) | **TESTED** | `lib/wallet_core.dart`, `test/wallet_core_test.dart` |
| EIP-55 checksummed address display | **TESTED** | `lib/wallet_core.dart`, `test/wallet_core_test.dart` |
| ECDSA signing (RFC-6979 deterministic, low-s) | **TESTED** | `lib/wallet_core.dart` (via web3dart) |
| EIP-1559 transaction construction | **TESTED** | `lib/cold_tx_codec.dart`, `test/cold_tx_codec_test.dart` (4/4) |
| EIP-1559 signing digest = keccak256(0x02 \| rlp([...])) | **VERIFIED WITH EVIDENCE** | `verification/verify.cjs` (ethers.js 6.17.0 independent) |
| Cold response verification (field-by-field + recovery) | **TESTED** | `WalletCore.verifyColdSignatureDetailed`, 15 service tests |
| Cold replay protection (single-use request ID + burn list) | **TESTED** | `lib/cold_wallet_service.dart`, `test/cold_wallet_service_test.dart` |
| No private keys/seed in logs or network; clipboard copies require an explicit warning and clear after 15 s | **TESTED** | `test/log_canary_test.dart`, `test/clipboard_guard_test.dart`, `lib/screens/wallet_page.dart` |
| App-lock PIN: Argon2id (same params) + exponential backoff | **PARTLY** | `lib/security.dart`, `lib/storage.dart`; backoff persistence has no dedicated test yet |

---

## Network Privacy Claims

| Claim | Status | Evidence |
|-------|--------|----------|
| All outbound HTTP construction is in `lib/net/privacy_client.dart` | **TESTED** | `lib/net/privacy_client.dart`; `test/data_boundary_test.dart` |
| Direct HTTPS with certificate validation | **TESTED** | `test/tls_pinning_test.dart` (standard validation first) |
| TLS SPKI pinning (after standard CA/hostname validation) | **TESTED** | `test/tls_pinning_test.dart` (6/6: pin cannot bypass CA/hostname) |
| Fixed v3 cert SPKI index (was hashing extensions) | **VERIFIED WITH EVIDENCE** | Dart pin == OpenSSL `x509 -pubkey \| pkey -outform DER \| dgst -sha256` |
| HTTP/HTTPS proxy (CONNECT) with auth | **IMPLEMENTED** | `lib/net/privacy_client.dart` |
| SOCKS5 proxy (domain/IPv4/IPv6, auth, remote DNS) | **IMPLEMENTED** | `lib/net/privacy_client.dart` (via `socks5_proxy`) |
| Tor via system daemon (SOCKS5, fail-closed) | **IMPLEMENTED** | `lib/net/privacy_client.dart`, `lib/tor_manager.dart` |
| Tor bridges (obfs4, WebTunnel via Tor config) | **IMPLEMENTED** | Documented in settings; Tor handles bridges |
| Strict Privacy Mode (all traffic, no fallback) | **IMPLEMENTED** | `lib/app_state.dart` enforces route |
| Cold mode blocks all app-initiated network calls (RPC, prices, explorer, probes) | **TESTED** | `RpcService.setOffline`, `PriceService` cold gate; the binary still links network code |
| No identifying headers (User-Agent scrubbed) | **TESTED** | `test/ua_scrub_test.dart` |
| DNS leak prevention (SOCKS5h, Tor remote resolve) | **IMPLEMENTED** | `lib/net/privacy_client.dart` |
| Chain ID validated on every RPC connect | **TESTED** | `lib/rpc_service.dart`, `test/nodes_test.dart` |
| HTTP CONNECT with pins: refused before socket | **TESTED** | `test/tls_pinning_test.dart` (pins not enforced on CONNECT) |

---

## Storage Security Claims

| Claim | Status | Evidence |
|-------|--------|----------|
| Vault file atomic write (tmp → rename, fsync, 0600) | **TESTED (Linux)** | `lib/storage.dart::atomicWrite`, `test/filesystem_security_test.dart` (23 focused tests, 2026-11-04); Linux refuses native-helper unavailability rather than silently using the portable pipeline. |
| Vault has two AEAD wrappers (password KEK + device KEK); either opens the shared DEK | **TESTED** | `lib/vault.dart`, `test/vault_test.dart` |
| Device secret in platform secure storage | **TESTED** | `lib/storage.dart` (flutter_secure_storage) |
| Desktop: device secret in owner-only drawer file (0600) | **TESTED** | `lib/storage.dart::atomicWrite` for drawer; staged `.deb` first-run |
| Erase-all removes every vault, log, temp and the device secret; a retained vault copy plus the password is still decryptable | **TESTED** | `lib/storage.dart`, `test/erase_flow_test.dart` |
| Best-effort overwrite before unlink | **TESTED** | `lib/storage.dart::_shredAndUnlink`, `test/filesystem_security_test.dart` |
| Preferences: public config only (no secrets) | **TESTED** | `lib/storage.dart` (SharedPreferences) |
| Secure storage: only device_secret, PIN hash, backoff, BscScan key | **TESTED** | `lib/storage.dart` |
| Activity logs encrypted at rest (BNBLOG01) | **TESTED** | `lib/encrypted_log_store.dart`, `test/encrypted_log_store_test.dart` |
| Receipts encrypted at rest (BNBRCPT1, capped 200) | **TESTED** | `lib/receipt_store.dart`, `test/receipt_store_test.dart` |
| No cloud sync, no telemetry, no analytics | **IMPLEMENTED** | No network calls for these features |

---

## Filesystem Security Claims (Linux)

| Claim | Status | Evidence |
|-------|--------|----------|
| Errno-aware symlink classification (lstat/fstatat AT_SYMLINK_NOFOLLOW) | **TESTED** | `lib/posix_fs.dart`, `test/filesystem_security_test.dart` cases 1–7 |
| `atomicWrite` destination classification independent of `exists()` | **TESTED** | `lib/storage.dart::atomicWrite`; valid & broken symlinks refused; missing = expected fresh case |
| Descriptor-based operations (openat, O_NOFOLLOW, O_CREAT|O_EXCL, dirfds) | **TESTED** | `lib/posix_fs.dart`, `lib/storage.dart::atomicWrite` Linux pipeline |
| Temporary files created on same filesystem as destination | **TESTED** | `mkstempSecure` in destination dir; `renameat` replace/NOREPLACE |
| Atomic replacement via `renameat` (RENAME_NOREPLACE + ENOSYS fallback) | **TESTED** | `PosixFs.renameCommit`, `test/filesystem_security_test.dart` case 11c |
| Post-rename destination identity check | **TESTED (bounded)** | `fstatat(AT_SYMLINK_NOFOLLOW)` compares destination device/inode to the still-open committed descriptor; case 11d detects a deterministic replacement. This proves identity only at the check boundary, not against a later same-UID replacement. |
| Device-secret drawer writes | **TESTED (bounded)** | Drawer rejects every result except `committedVerified`; it does not represent durability uncertainty as successful key persistence. |
| Encrypted activity-log persistence | **PARTIALLY TESTED** | Base64-wrapped `BNBLOG01` envelopes are written via `atomicWrite` and read/delete no-follow. Linux wraps each read/append/delete cycle in a shared nonblocking `flock(2)` advisory lock; independent-process append/rotation/delete races remain unverified. |
| Use-time recheck closes validate→use race window | **TESTED** | `StorageDebugHooks.beforeCommit` drives cases 11a/11b/11c |
| Creation-time 0600 permissions (mkstemp mode argument; umask cannot add bits) | **TESTED** | `test/filesystem_security_test.dart` mechanism test under umask 0002 |
| Temp file cleanup on failure; never touches destination on error | **TESTED** | `test/filesystem_security_test.dart` cleanup test |
| Vault operation locking | **PARTIALLY TESTED** | `withVaultOperationLock` orders the VM lock before a shared Linux `flock(2)` lock. Contention fails closed and descriptor close releases it; full independent-process vault-operation coverage remains required. |
| Process umask(077) set before Flutter init protects plugin-created files/dirs | **TESTED** | Staged `.deb` first-run under desktop umask 0002 → dirs 0700, files 0600 |
| Rollback after a post-commit verification failure | **TESTED** | `test/rollback_injection_test.dart`: valid replacement reaches rename, then a controlled verification failure invokes the actual rollback and restores exact original bytes. |
| Rollback-write failure is distinguishable from successful restore | **TESTED** | `test/rollback_injection_test.dart`: explicit rollback-boundary failure returns non-committed result; replacement remains valid and unrelated/source files are preserved. |
| Non-Linux platforms: dart:io `FileSystemEntity.type(followLinks:false)` ambiguity documented | **DOCUMENTED** | "notFound" conflates missing + lookup errors; fail-closed where possible |

---

## Cold Wallet Claims

| Claim | Status | Evidence |
|-------|--------|----------|
| Cold signer: no network (RpcService offline, connect fails) | **TESTED** | `lib/app_state.dart::setWalletMode(1)` |
| Online companion: no keys (wipes keys, opens watch address) | **TESTED** | `lib/app_state.dart::setWalletMode(2)` |
| Pairing: public addresses + fingerprint only | **TESTED** | `lib/cold_wallet_protocol.dart`, 15 protocol tests |
| Request: unsigned EIP-1559, versioned, checksummed, expiry | **TESTED** | 15 protocol tests, 15 service tests |
| Offline signing: account-index aware (not always index 0) | **TESTED** | `ColdWalletService.signRequest` derives matching index |
| Response: strict verify-before-broadcast | **TESTED** | `ColdWalletService.verifyResponse` + `verifyColdSignatureDetailed` |
| Replay protection: single-use ID, pending required, burn list | **TESTED** | 15 service tests |
| Independent ethers.js verification of signed bytes | **VERIFIED WITH EVIDENCE** | `verification/verify.cjs` (8 substitutions rejected) |
| Request lifetime 30 min default, 24h max, 5 min clock skew | **IMPLEMENTED** | `lib/cold_wallet_service.dart`, `lib/cold_wallet_protocol.dart` |
| QR/file/paste transport (no camera on Linux) | **IMPLEMENTED** | `lib/screens/cold_wallet_dialogs.dart` |
| Camera QR scanning on Linux | **NOT SUPPORTED** | File/paste/QR display only |

---

## Memory/Process Hardening Claims (Linux)

| Claim | Status | Evidence |
|-------|--------|----------|
| `prctl(PR_SET_DUMPABLE, 0)` — prevents same-UID ptrace/core | **TESTED** | `test/memory_protection_test.dart` reads kernel state |
| `setrlimit(RLIMIT_CORE, 0)` — no core dumps | **TESTED** | `test/memory_protection_test.dart` reads kernel state |
| `mlockall(MCL_CURRENT \| MCL_FUTURE)` — best-effort memory lock | **PARTIAL** | Called; may fail under low RLIMIT_MEMLOCK; not asserted |
| No `sh -c ulimit` no-op | **VERIFIED** | Old code removed; FFI direct kernel calls |

---

## Release Security Claims

| Claim | Status | Evidence |
|-------|--------|----------|
| No committed keystore (`.jks`, `.keystore`, `.p12`, `.pfx`) | **VERIFIED** | `scripts/secret-scan.sh` passes; `.gitignore` blocks |
| No hardcoded release passwords | **VERIFIED** | `secret-scan.sh` checks for old `BnbWalletRelease-*` pattern |
| `build-apk.sh` requires env vars (BNB_KEYSTORE, etc.) | **IMPLEMENTED** | `scripts/build-apk.sh` fails closed if missing |
| `build-apk.sh` refuses tracked keystore | **IMPLEMENTED** | Checks `git ls-files` |
| GPG detached signatures on release artifacts | **IMPLEMENTED** | `build-deb.sh`, `build-apk.sh` create `.asc` if key provided |
| SHA-256 checksums on release artifacts | **IMPLEMENTED** | Build scripts generate `.sha256` |
| SBOM committed and current (deterministic from lockfile) | **VERIFIED** | `scripts/sbom.py`, `docs/SBOM.json`, CI check |
| Token source links verified in CI | **IMPLEMENTED** | `scripts/check_token_sources.py` |

---

## Explicit Non-Claims (What We Do NOT Promise)

| Non-Claim | Reason |
|-----------|--------|
| Perfect security | Impossible; software carries risk |
| Guaranteed anonymity | Tor hides IP from RPC, not on-chain linkage |
| Complete invisibility from ISP/DPI | ISP sees Tor/proxy traffic; timing analysis possible |
| Guaranteed protection vs compromised OS | Keyloggers, rootkits, malicious keyboard defeat local protections |
| Guaranteed physical erasure of SSD data | Wear-leveling, snapshots, filesystem copies prevent guarantee |
| Hardware wallet support | Outside the 1.x scope; no support claim is made |
| Guaranteed safe storage of arbitrary amounts | **Testnet-ready self-assessed only**; production requires third-party audit |
| OS-enforced air gap (no INTERNET permission) | Runtime offline only; APK still carries INTERNET |
| Reproducible builds verified | Toolchain pin not finalized; marked NOT TESTED |
| Third-party audit completed | **No** — internal self-audit only (SECURITY_AUDIT.md) |
| Crash safety / persistent recovery journal | **No** — atomic write + fsync is best-effort; power loss between fsync and directory fsync can lose data; no write-ahead log |
| `renameat` ENOSYS fallback on old kernels | **Documented residual** — `rename` used as fallback; atomic directory update not guaranteed |

---

## Verification Evidence Locations

| Evidence Type | Location |
|---------------|----------|
| Automated test results | `docs/evidence/test-results-*.log` (to be generated) |
| Build metadata | `docs/evidence/build-*.log` (to be generated) |
| Packet captures (network leaks) | `docs/evidence/pcap-*.pcapng` (to be generated) |
| Cryptographic vectors | `verification/fixture.json`, `verification/verify.cjs` |
| Secret scan logs | `docs/evidence/secret-scan-*.log` (to be generated) |
| Static analysis logs | `docs/evidence/analyze-*.log` (to be generated) |

---

## How to Verify Independently

```bash
# 1. Cryptographic vectors (cold signing)
cd verification && npm ci && node verify.cjs

# 2. TLS pinning (generates ephemeral certs, compares with OpenSSL)
flutter test test/tls_pinning_test.dart

# 3. Memory hardening (reads real kernel state)
flutter test test/memory_protection_test.dart

# 4. Full test suite (sequential, all files)
bash scripts/test-suite.sh

# 5. Production KDF (native reference + independent cross-check)
flutter test test/kdf_production_test.dart

# 6. Secret scan (current tree)
bash scripts/secret-scan.sh

# 7. Static analysis and formatting
flutter analyze --no-pub
dart format --output=none --set-exit-if-changed lib test tool

# 8. Release gate summary
python3 scripts/release-gate.py

# 9. Build verification (when .deb exists)
dpkg -c x-wallet-*.deb | grep -E '\.jks|\.keystore|\.p12|\.pfx|private' && echo "FAIL" || echo "PASS"
```

---

*This document distinguishes implementation from verification. Internal self-audit ≠ independent third-party audit. All claims are qualified with their verification status.*
