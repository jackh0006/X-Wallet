# PROJECT_STATUS.md — Current Project State

> **Historical snapshot — not current.** The current release is
> **X Wallet 1.6.0+18** (`v1.6.0`). Use `docs/GENERATED_STATUS.md`,
> `release/evidence.json`, `docs/releases/1.6.0.md` and
> `IMPLEMENTATION_STATUS.md` for the current state. The text below is kept as
> an audit trail from earlier milestones.

**Last Updated**: 2026-11-06
**Current release line**: `1.1.0+5` on `release/1.0.10`
**Current milestone**: release-candidate verification
**Status**: **PARTIALLY VERIFIED / NOT RELEASABLE** — hosted CI and the
Ubuntu package smoke pass, and reproducibility passes at a documented fixed
path, but the package is unsigned and no independent audit exists.

## 2026-11-06 candidate update

| Item | Status | Evidence |
|---|---|---|
| Native Argon2id backend | DONE | `lib/kdf.dart`; one 64 MiB/t=3/p=4 derivation measured at 344 ms, down from ~110 s pure-Dart debug fallback |
| KDF test stability | FIXED LOCALLY | `vault_test` 9/9 in 10 s; KDF-tagged suites 4/4 in 48 s; no segfault when tests run serially |
| Exact ERC-20 calldata | FIXED | `SendIntent.decodeErc20Transfer` rejects trailing bytes; regression test |
| Test suite | LOCAL + HOSTED PASS | 47/47 files, 0 failed, 0 timed out; hosted CI on `773f0db` PASS |
| Linux build | PASS | `flutter build linux --release` 2m03s |
| `.deb` package | PARTIAL | the 1.0.10 package built unsigned; SHA-256 `e19917d3c50d8c3c36a13b3e0f154ae09ff15958e5d05826649124ce314dd9b1`; not publishable |
| Machine-readable evidence | IMPLEMENTED | `release/manifest.json`, `docs/testing/test-inventory.json`, `docs/GENERATED_STATUS.md`, `release-gate.py` |
| Release gate | INCOMPLETE / BLOCKED | Source checks pass; `.deb` is unsigned and install is untested |
| Android | BLOCKED | Historical signing key rotation `NOT VERIFIED`; denylist empty |
| Independent audit | NOT AVAILABLE | None has been performed |

The historical sections below are retained for audit trail. Do not treat their
older "DONE" rows as evidence for the 1.0.10 candidate.

---

**Last Updated**: 2026-11-05
**Baseline Commit**: `dc8732f` (working-tree audit in progress)
**Current Milestone**: M3 — Local Encrypted Storage (re-opened for independent audit)
**Previous Milestone**: M3 was previously declared complete; that declaration is not accepted as verification evidence.

## 2026-11-04 Independent M3 Audit Update

| Requirement | Status | Evidence / finding |
|---|---|---|
| M3-08 rollback write-failure injection | **TESTED** | `test/rollback_injection_test.dart`: two valid, decryptable vaults; replacement rename is observed; forced post-commit verification failure reaches real rollback; both rollback success and rollback-write failure assert exact final bytes. |
| M3-09 Linux fail-closed native storage | **TESTED** | `atomicWrite` now refuses a portable fallback when `PosixFs` is unavailable on Linux; filesystem case 00 proves destination bytes remain untouched. |
| M3-15 post-commit outcome handling | **IMPLEMENTED, TESTED** | `AtomicWriteState` distinguishes verified commit, durability uncertainty, and verification failure. Import rolls back only on the latter; directory-fsync uncertainty remains an explicit warning. |
| M3-24 post-rename destination identity verification | **IMPLEMENTED, TESTED** | `fstatat(AT_SYMLINK_NOFOLLOW)` under the pinned parent compares destination device/inode with the open committed descriptor. Filesystem cases 11d/11e prove a post-rename pathname replacement is not reported as success and reused temp names are preserved. |
| M3-25 atomic-write caller outcome audit | **IMPLEMENTED, TESTED (focused)** | Vault/account/password/receipt wrappers use `getOrThrow` (verified-only). Move and export now require verified commit and no-follow readback; import rollback requires a verified rollback and no-follow readback. Broader interruption/concurrency coverage remains open. |
| M3-26 drawer and encrypted-log persistent-state audit | **IMPLEMENTED, TESTED (focused)** | Drawer now requires `committedVerified`. Encrypted logs use atomic base64 envelopes, no-follow reads/deletes, and a process-local append lock; `log_canary_test.dart` verifies same-process concurrent append retention. |
| M3 overall | **IN PROGRESS** | Failure modes such as rename/cleanup/interruption and all callers still require independent review. Do not treat historical “COMPLETE” rows below as current verification. |

**Current test evidence (2026-11-04, Linux, Flutter 3.47.6/Dart 3.13.5):**
`bash scripts/test-suite.sh` passed: 239 non-KDF tests in 1m09s and 22
KDF-tagged tests in 2m00s. This is local evidence, not CI validation.

---

## Completed Tasks (with Evidence)

| Task | Status | Evidence Location |
|------|--------|-------------------|
| **M0-01**: AGENTS.md | ✅ DONE | `AGENTS.md` |
| **M0-02**: BASELINE.md | ✅ DONE | `docs/project/BASELINE.md` |
| **M0-03**: PROJECT_MASTER_PLAN.md | ✅ DONE | `docs/PROJECT_MASTER_PLAN.md` |
| **M0-05**: THREAT_MODEL.md (updated) | ✅ DONE | `docs/THREAT_MODEL.md` |
| **M1-01**: Cold EIP-1559 codec | ✅ DONE | `lib/cold_tx_codec.dart`, `test/cold_tx_codec_test.dart` (4/4) |
| **M1-02**: Cold protocol envelopes | ✅ DONE | `lib/cold_wallet_protocol.dart`, `test/cold_wallet_protocol_test.dart` (15/15) |
| **M1-03**: Cold wallet service | ✅ DONE | `lib/cold_wallet_service.dart`, `test/cold_wallet_service_test.dart` (15/15) |
| **M1-04**: Strict response verification | ✅ DONE | `lib/wallet_core.dart::verifyColdSignatureDetailed` |
| **M1-05**: Independent ethers.js verification | ✅ DONE | `verification/verify.cjs` (ethers 6.17.0) |
| **M1-06**: TLS SPKI pinning (standard first) | ✅ DONE | `lib/net/privacy_client.dart`, `test/tls_pinning_test.dart` (6/6) |
| **M1-07**: Fixed v3 cert SPKI index bug | ✅ DONE | Was hashing extensions (idx 7), now public key (idx 6) |
| **M1-08**: Memory hardening (FFI) | ✅ DONE | `lib/memory_protection.dart`, `test/memory_protection_test.dart` (2/2) |
| **M1-09**: Release hygiene (keystore, env-only) | ✅ DONE | `scripts/build-apk.sh`, `.gitignore`, `scripts/secret-scan.sh` |
| **M1-10**: Cold account-index signing | ✅ DONE | `ColdWalletService.signRequest` derives matching index |
| **M1-11**: Test stability fixes | ✅ DONE | Keyring timeout, dialog `isExpanded=true` |
| **M1-12**: Security documentation updates | ✅ DONE | `SECURITY_AUDIT.md`, `COLD_WALLET.md`, `TESTING.md`, etc. |
| **M3-01** | Vault creation UI (path selection, password) | ✅ DONE (existing) | `lib/screens/wallet_page.dart` |
| **M3-02** | Vault path management (move, rename, switch) | ✅ DONE | `lib/app_state.dart` (`moveVault`, `resetVaultPath`) |
| **M3-03** | Password change (re-encrypt with new salt) | ✅ DONE | `lib/app_state.dart` (`changeVaultPassword`) |
| **M3-04** | Encrypted backup (export/import) | ✅ DONE | `lib/app_state.dart` (`exportVault`, `importVault`) |
| **M3-05** | Vault integrity verification | ✅ DONE | `lib/app_state.dart` (`getVaultInfo`, `importVault` validation) |
| **M3-06** | Vault-version test-construction fix | ✅ DONE | `test/vault_import_rollback_kdf_test.dart` |
| **M3-07** | Secure deletion workflow (crypto-erase + overwrite) | ✅ DONE (existing) | `lib/storage.dart` (`eraseAllData`) |
| **M3-08** | Import-rollback write-failure injection | ✅ DONE | `test/vault_import_rollback_kdf_test.dart` (10/10 pass) |
| **M3-09** | Atomic write hardening | ✅ DONE | `lib/storage.dart` (`atomicWrite`, `_createSecureTempFile`) |
| **M3-10** | Symlink validation & rejection | ✅ DONE | `lib/storage.dart` (`_isSymlink`, `atomicWrite`, `_validateRegularFile`) |
| **M3-11** | Import rollback with verification | ✅ DONE | `lib/app_state.dart` (`importVault` rollback logic) |
| **M3-12** | Vault operation locking | 🟡 PARTIALLY TESTED | `withVaultOperationLock` uses local ordering plus Linux nonblocking advisory `flock(2)`; independent-process coverage remains required. |
| **M3-13** | Vault info display (path, size, custom/default) | ✅ DONE | `lib/app_state.dart` (`getVaultInfo`) |
| **M3-14** | Secure temp file creation with 0600 perms | ✅ DONE | `lib/storage.dart` (`_createSecureTempFile`) |
| **M3-15** | Atomic write with rollback on failure | ✅ DONE | `lib/app_state.dart` (`importVault` rollback) |
| **M3-16** | Secure temp file permissions verification | ✅ DONE | `lib/storage.dart` (`_createSecureTempFile` verification) |
| **M3-16** | Symlink detection with lstat semantics | ✅ DONE | `lib/storage.dart` (`_isSymlink` using `FileStat.stat`) |
| **M3-17** | Secure temp file collision handling | ✅ DONE | `lib/storage.dart` (`_createSecureTempFile` with 10 attempts) |
| **M3-18** | Errno-aware symlink classification (Linux) | ✅ DONE | `lib/posix_fs.dart`, `test/filesystem_security_test.dart` cases 1–7 |
| **M3-19** | Descriptor-based atomic write (openat, O_NOFOLLOW, dirfds) | ✅ DONE | `lib/posix_fs.dart`, `lib/storage.dart` Linux pipeline |
| **M3-20** | Use-time recheck closes validate→use race | ✅ DONE | `StorageDebugHooks.beforeCommit`, cases 11a/11b/11c |
| **M3-21** | Process umask(077) at startup | ✅ DONE | `linux/runner/main.cc`, staged `.deb` test |
| **M3-22** | Log append race fix (serialized file mutations) | 🟡 PARTIALLY TESTED | Local lock plus Linux advisory lock; independent-process append/rotation/delete coverage remains required. |
| **M3-23** | Dedicated Linux filesystem security integration tests | ✅ DONE | `test/filesystem_security_test.dart` (20 tests) |
| **M3-24** | Post-rename destination identity verification and safe post-commit cleanup | ✅ TESTED | `lib/posix_fs.dart`, `lib/storage.dart`; `filesystem_security_test.dart` cases 11d/11e (2026-11-04, 23/23 pass) |
| **M3-25** | Atomic-write caller outcome audit | ✅ TESTED (focused) | `lib/app_state.dart`, `lib/storage.dart`; all `atomicWrite` callers inventoried with `rg`; focused filesystem and rollback suites pass (2026-11-04) |
| **M3-26** | Drawer and encrypted-log atomic persistence | 🟡 PARTIALLY TESTED | Drawer behavior has focused evidence; encrypted-log cross-process coverage remains required. |
| **M2-02**: Linux desktop integration (launcher, icon) | ✅ DONE | `.desktop` file in .deb, icon in assets |
| **M2-03**: Run `scripts/build-deb.sh` end-to-end | ✅ DONE | Produced the 1.0.7 package |
| **M2-04**: Install .deb on clean Ubuntu VM | ⚠️ NOT TESTED | Clean VM not available |
| **M2-05**: Verify .deb contents (no secrets, perms) | ✅ DONE | `dpkg -c` — no secrets, correct perms |
| **M2-06**: SHA-256 + GPG signature on .deb | ✅ DONE | `.sha256` + `.asc` (verified good) |
| **M2-07**: Document build reproducibility | ⚠️ NOT TESTED | Toolchain not pinned |

---

## Tested Tasks (Automated Tests Passing)

| Suite | Count | Result | Notes |
|-------|-------|--------|-------|
| **Non-KDF full suite** | 238 | ✅ PASS | `flutter test --exclude-tags kdf --concurrency=2` |
| **filesystem_security_test** | 23 | ✅ PASS | Linux errno-aware, descriptor-based, pre/post-rename race tests (2026-11-04) |
| **cold_tx_codec_test** | 4 | ✅ PASS | Canonical EIP-1559 codec |
| **cold_wallet_protocol_test** | 15 | ✅ PASS | Envelopes, checksums, expiry, substitutions |
| **cold_wallet_service_test** | 15 | ✅ PASS | Persistence, replay, broadcast, verification |
| **cold_wallet_test** | 8 | ✅ PASS | Existing cold wallet tests |
| **tls_pinning_test** | 6 | ✅ PASS | Standard validation + pin, CONNECT refused |
| **memory_protection_test** | 2 | ✅ PASS | Kernel state: dumpable=0, core limit=0 |
| **privacy_dialogs_test** | 2 | ✅ PASS | Proxy/Tor dialogs |
| **widget_test** | 3 | ✅ PASS | App launch, home tab |
| **verification/verify.cjs** | 1 script | ✅ PASS | 8 field substitutions rejected |
| **secret-scan.sh** | 1 scan | ⚠️ DESIGNED FAIL | BLK-06 (old keystore in git history) |
| **flutter analyze** | — | ✅ NO ERRORS | 124 issues (all pre-existing at HEAD) |

---

## Incomplete Tasks (Current Milestone M4)

| Task ID | Description | Status | Blockers |
|---------|-------------|--------|----------|
| **M4-01** | Account derivation UI (add/remove/switch accounts) | ⏳ PENDING | M3 |
| **M4-02** | Private key import (raw hex, keystore JSON v3) | ⏳ PENDING | M3 |
| **M4-03** | Seed phrase import (12/24 words, validation) | ⏳ PENDING | M3 |
| **M4-04** | Wallet unlock/lock (biometric where available) | ⏳ PENDING | M3 |
| **M4-05** | Transaction signing (EIP-1559, legacy) | ✅ DONE | — |
| **M4-06** | Signature verification (independent) | ✅ DONE | — |
| **M4-06** | Nonce management (pending, replacement) | ⏳ PENDING | M3 |
| **M4-07** | Chain ID validation (every sign/broadcast) | ✅ DONE | — |
| **M4-07** | Replay protection (EIP-155 chain ID) | ✅ DONE | — |
| **M4-08** | Address validation (EIP-55, contract detection) | ✅ DONE | — |

---

## Blocked Tasks

| Task ID | Description | Blocker | Resolution Path |
|---------|-------------|---------|-----------------|
| **BLK-01** | KDF tests OOM on 2-core 4GB | Memory exhaustion | Run individually with 8-15 min timeouts; documented |
| **BLK-02** | Two-device physical cold-wallet test | No second device | File/paste/QR tested in code; mark NOT TESTED |
| **BLK-03** | Local Anvil integration test | `anvil` not installed | Install Foundry or use CI runner |
| **BLK-05** | Linux QR camera scanning | Camera plugin not integrated | Add `camera` plugin; implement scanner |
| **BLK-06** | Old release keystore in Git history | **COMPROMISED** — cannot rewrite public history | Rotate key operationally; new keystore outside repo |
| **BLK-07** | `mlockall` best-effort failure | Low RLIMIT_MEMLOCK | Test asserts dumpable=0, core=0 only |
| **BLK-08** | HTTP CONNECT with pins refused | Not enforced, only refused | Document as limitation; future: pin CONNECT |

---

## Latest Successful Build

| Metric | Value |
|--------|-------|
| **Flutter Version** | 3.47.6 (stable) |
| **Dart Version** | 3.13.5 |
| **Last Clean Build** | 2026-11-04 — `flutter build linux --release` ✅ |
| **Last .deb Build** | 2026-11-04 — the 1.0.7 package (9.5 MB) |
| **Package Verify** | `dpkg -c` — no secrets, correct perms ✅ |
| **Checksum** | `b5c6aaa4eee70f53ce7596c9da43b6129fb1391a65b510c4d9c2bc68489317dc` |
| **GPG Signature** | Verified (EDDSA key CC819EF5E109A1518E840379D8C0CEC84BCCE06B) |
| **Last Test Run** | 2026-11-04 (non-KDF: 238 pass; filesystem_security: 20 pass; KDF: vault +7, workers +3, rollback +10/10) |
| **Analyzer** | No errors (124 issues, all pre-existing) |
| **Secret Scan** | BLK-06 (designed fail: old keystore in git history) |

---

## Latest Test Results (2026-11-04)

```
flutter test --exclude-tags kdf --concurrency=2
→ 238 tests passed (0 failed, 0 skipped)
Exit code: 0

flutter test test/filesystem_security_test.dart
→ 20 tests passed (0 failed, 0 skipped)
Exit code: 0

flutter test test/vault_test.dart --timeout 600s
→ 7 tests passed (0 failed, 0 skipped)
Exit code: 0

flutter test test/workers_test.dart --timeout 900s
→ 3 tests passed (0 failed, 0 skipped)
Exit code: 0

flutter test test/vault_import_rollback_kdf_test.dart --timeout 900s
→ 10 passed, 0 failed
Exit code: 0

cd verification && npm ci && node verify.cjs
→ PASS: payload, digest, fields, r/s/yParity, hash, recovered signer
→ 8 substitution cases rejected (recipient, value, chain, nonce, gas, fees, calldata)

bash scripts/secret-scan.sh
→ FAIL (designed): BLK-06 old release keystore in git history

flutter analyze --no-pub
→ 124 issues (0 errors); all remaining in changed files pre-existing at HEAD
```

---

## Outstanding Security Concerns

| ID | Concern | Severity | Mitigation |
|----|---------|----------|------------|
| **SEC-01** | Old release keystore compromised | CRITICAL | Must rotate; new keystore outside repo; users reinstall |
| **SEC-02** | No third-party audit | HIGH | Internal self-audit only (SECURITY_AUDIT.md); state clearly |
| **SEC-03** | No two-device cold test | MEDIUM | Code tested; mark NOT TESTED in claims |
| **SEC-04** | No Anvil integration test | MEDIUM | Fake RPC used; mark NOT TESTED |
| **SEC-06** | KDF resource exhaustion on weak HW | MEDIUM | Documented; tests pass individually; not a security flaw |
| **SEC-07** | `mlockall` may fail silently | LOW | Test asserts kernel state only; best-effort documented |
| **SEC-08** | HTTP CONNECT pins refused not enforced | LOW | Documented limitation; no silent downgrade |

---

## Next Exact Actions

1. Run `bash scripts/test-suite.sh` on a machine able to retain the full terminal output and zero exit status.
2. Run `bash scripts/build-deb.sh` without `SKIP_FLUTTER_BUILD` on that machine.
3. Test fresh install, launch, upgrade, uninstall, and data preservation on a clean Ubuntu desktop.
4. Complete the signing-key rotation response for the historical Android keystore exposure; Android is out of scope for this Linux-only release.
5. Do not publish or describe this as suitable for unrestricted or large-value mainnet use without an independent review and the release-gate evidence.

---

## Documentation Status

| Document | Status | Last Updated |
|----------|--------|--------------|
| `AGENTS.md` | ✅ CURRENT | 2026-11-03 |
| `BASELINE.md` | ✅ CURRENT | 2026-11-03 |
| `PROJECT_MASTER_PLAN.md` | ✅ CURRENT | 2026-11-03 |
| `PROJECT_STATUS.md` | ✅ CURRENT | 2026-11-03 |
| `SECURITY_AUDIT.md` | ✅ CURRENT | 2026-11-03 |
| `docs/COLD_WALLET.md` | ✅ CURRENT | 2026-11-03 |
| `docs/TESTING.md` | ✅ CURRENT | 2026-11-03 |
| `docs/THREAT_MODEL.md` | ✅ CURRENT | 2026-11-03 |
| `docs/CRYPTO.md` | ✅ CURRENT | 2026-11-03 |
| `docs/SECURITY.md` | ✅ CURRENT | 2026-11-03 |
| `docs/SPEC-COMPLIANCE.md` | ✅ CURRENT | 2026-11-03 |
| `docs/ARCHITECTURE.md` | ✅ CURRENT | 2026-11-03 |
| `docs/CHANGELOG.md` | ✅ CURRENT | 2026-11-03 |
| `README.md` | ✅ CURRENT | 2026-11-03 |
| **Security docs (new)** | 🔄 IN PROGRESS | See below |
| **Testing docs (new)** | 🔄 IN PROGRESS | See below |
| **Hardware/Network docs (new)** | 🔄 IN PROGRESS | See below |

---

## New Documentation In Progress (M0 deliverables)

| File | Status | Target |
|------|--------|--------|
| `docs/security/SECURITY_CLAIMS.md` | ✅ DONE | 2026-11-03 |
| `docs/security/NETWORK_PRIVACY_MODEL.md` | ✅ DONE | 2026-11-03 |
| `docs/security/STORAGE_SECURITY.md` | ✅ DONE | 2026-11-03 |
| `docs/security/RELEASE_SECURITY.md` | ✅ DONE | 2026-11-03 |
| `docs/testing/TEST_MATRIX.md` | ✅ DONE | 2026-11-03 |
| `docs/hardware/COMPATIBILITY_MATRIX.md` | ✅ DONE | 2026-11-03 |
| `docs/network/NETWORK_GUIDE.md` | ✅ DONE | 2026-11-03 |
| `docs/DECISIONS/001-pure-dart-crypto.md` | ✅ DONE | 2026-11-03 |
| `docs/DECISIONS/002-cold-wallet-protocol.md` | ✅ DONE | 2026-11-03 |
| `docs/DECISIONS/003-tls-pinning-standard-first.md` | ✅ DONE | 2026-11-03 |
| `docs/DECISIONS/004-memory-hardening-ffi.md` | ✅ DONE | 2026-11-03 |

---

*Update this file at every milestone completion. Record actual outputs, not expectations.*
