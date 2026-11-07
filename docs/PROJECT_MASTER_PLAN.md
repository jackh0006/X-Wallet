# PROJECT_MASTER_PLAN.md — Authoritative Implementation Roadmap

**Version**: 1.0 (2026-11-03)
**Baseline Commit**: `68091b06cce3e9c90692e3f632d539ae69734154`
**Status**: Milestone 3 re-opened on 2026-11-04 for independent filesystem and rollback audit. Historical completion claims are retained below, but are not verification evidence.

---

## Milestone Overview

| Milestone | Title | Target | Status |
|-----------|-------|--------|--------|
| **M0** | Repository baseline & persistent instructions | AGENTS.md, BASELINE.md, task ledger | ✅ DONE |
| **M1** | Existing code security & architecture review | Fix critical issues without breaking | ✅ DONE (security hardening round) |
| **M2** | Linux application foundation | Build, initial .deb, desktop integration | ✅ DONE |
| **M3** | Local encrypted storage | Vaults, paths, encryption, backup, delete | 🔄 IN PROGRESS (independent audit) |
| **M4** | Wallet core | Accounts, signing, verification, recovery | ⏳ PENDING (M3 complete first) |
| **M5** | Activity Center | Encrypted logs, events, redaction, integrity | ⏳ PENDING |
| **M6** | Blockchain & RPC | Custom RPC, chain validation, endpoints | ⏳ PENDING |
| **M7** | Assets & tokens | BNB, BEP-20, USDT, USDC, custom, validation | ⏳ PENDING |
| **M8** | Transaction engine & fees | Transfers, fees, simulation, history, explorer | ⏳ PENDING |
| **M9** | Central networking | NetworkPrivacyManager, all traffic routed | ⏳ PENDING |
| **M10** | Proxies | HTTP/HTTPS/SOCKS5, DNS, failures | ⏳ PENDING |
| **M11** | Tor & privacy | Tor, bridges, Strict/Offline modes, leak tests | ⏳ PENDING |
| **M12** | Cold wallet | Offline signing, exchange protocols | ✅ IMPLEMENTED, TESTED |
| **M13** | Hardware wallets | Explicitly removed from the 1.x product scope | ➖ OUT OF SCOPE |
| **M14** | Final UX & branding | Black/orange theme, logo, accessibility, explanations | ⏳ PENDING |
| **M15** | Compatibility & performance | Weak devices, distros, resources, unstable net | ⏳ PENDING |
| **M16** | Final security validation | All tests, static analysis, secret scan, review | ⏳ PENDING |
| **M17** | Linux release candidate | Build, install, test, document, checksum, signed `.deb` | 🔄 IN PROGRESS — package integrity verified; full source build, full-suite evidence, and clean-install checks remain. |
| **M18** | Android planning & implementation | After Linux core stable | ⏳ BLOCKED (M17 first) |

---

## Detailed Task Ledger

### MILESTONE 0 — Repository Baseline (COMPLETE)

| Task ID | Description | Status | Evidence |
|---------|-------------|--------|----------|
| M0-01 | Create AGENTS.md | ✅ DONE | `AGENTS.md` |
| M0-02 | Create BASELINE.md | ✅ DONE | `docs/project/BASELINE.md` |
| M0-03 | Create PROJECT_MASTER_PLAN.md | ✅ DONE | This file |
| M0-04 | Create PROJECT_STATUS.md | ✅ DONE | `docs/PROJECT_STATUS.md` |
| M0-05 | Create THREAT_MODEL.md (security/) | ✅ EXISTS | `docs/THREAT_MODEL.md` (updated) |
| M0-06 | Create SECURITY_CLAIMS.md | ✅ DONE | `docs/security/SECURITY_CLAIMS.md` |
| M0-07 | Create NETWORK_PRIVACY_MODEL.md | ✅ DONE | `docs/security/NETWORK_PRIVACY_MODEL.md` |
| M0-08 | Create STORAGE_SECURITY.md | ✅ DONE | `docs/security/STORAGE_SECURITY.md` |
| M0-09 | Create RELEASE_SECURITY.md | ✅ DONE | `docs/security/RELEASE_SECURITY.md` |
| M0-10 | Create TEST_MATRIX.md | ✅ DONE | `docs/testing/TEST_MATRIX.md` |
| M0-11 | Create COMPATIBILITY_MATRIX.md | ✅ DONE | `docs/hardware/COMPATIBILITY_MATRIX.md` |
| M0-12 | Create NETWORK_GUIDE.md | ✅ DONE | `docs/network/NETWORK_GUIDE.md` |
| M0-13 | Create DECISIONS/ directory | ✅ DONE | `docs/DECISIONS/` (4 decisions) |
| M0-14 | Create evidence/ directory | ✅ DONE | `docs/evidence/` |

### MILESTONE 1 — Security & Architecture Review (COMPLETE — 2026-11-03 round)

| Task ID | Description | Status | Evidence |
|---------|-------------|--------|----------|
| M1-01 | Cold EIP-1559 codec (replace broken rlp) | ✅ DONE | `lib/cold_tx_codec.dart`, 4 tests |
| M1-02 | Cold protocol envelopes (versioned, checksummed) | ✅ DONE | `lib/cold_wallet_protocol.dart`, 15 tests |
| M1-03 | Cold service (persistence, replay, broadcast) | ✅ DONE | `lib/cold_wallet_service.dart`, 15 tests |
| M1-04 | Strict response verification (field-by-field) | ✅ DONE | `WalletCore.verifyColdSignatureDetailed` |
| M1-05 | Independent ethers.js verification | ✅ DONE | `verification/verify.cjs`, 8 substitutions |
| M1-06 | TLS pinning (standard validation first) | ✅ DONE | `lib/net/privacy_client.dart`, 6 tests |
| M1-07 | Fixed v3 cert SPKI index bug | ✅ DONE | Was hashing extensions; now public key |
| M1-08 | Memory hardening (FFI prctl/setrlimit/mlockall) | ✅ DONE | `lib/memory_protection.dart`, 2 tests |
| M1-09 | Release hygiene (keystore removal, env-only build) | ✅ DONE | `build-apk.sh`, `.gitignore`, `secret-scan.sh` |
| M1-10 | Cold account-index signing (not always index 0) | ✅ DONE | `ColdWalletService.signRequest` |
| M1-11 | Test stability fixes (keyring timeout, dialog overflow) | ✅ DONE | `storage.dart`, `privacy_dialogs.dart` |
| M1-12 | Documentation updates (all security docs) | ✅ DONE | SECURITY_AUDIT, COLD_WALLET, TESTING, etc. |

### MILESTONE 2 — Linux Application Foundation (COMPLETE)

| Task ID | Description | Status | Dependencies | Notes |
|---------|-------------|--------|--------------|-------|
| M2-01 | Verify `flutter build linux --release` succeeds | ✅ DONE | M0 | Clean build |
| M2-02 | Test Linux desktop integration (launcher, icon, mime) | ✅ DONE | M2-01 | `.desktop`, icons in .deb |
| M2-03 | Run `scripts/build-deb.sh` end-to-end | ✅ DONE | M2-01 | Produced the 1.0.7 package |
| M2-04 | Install .deb on clean Ubuntu VM | ⚠️ NOT TESTED | M2-03 | Clean VM not available |
| M2-05 | Verify .deb contents (dpkg -c) | ✅ DONE | M2-03 | No secrets, correct perms |
| M2-06 | SHA-256 + GPG signature on .deb | ✅ DONE | M2-03 | `.sha256` + `.asc` verified |
| M2-07 | Document Linux build reproducibility | ⚠️ NOT TESTED | M2-04 | Toolchain not pinned |

### MILESTONE 3 — Local Encrypted Storage (COMPLETE)

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M3-01 | Vault creation UI (path selection, password) | ✅ DONE (existing) | M2 |
| M3-02 | Vault path management (move, rename, switch) | ✅ DONE (backend) | M2 |
| M3-03 | Password change (re-encrypt with new salt) | ✅ DONE (backend) | M2 |
| M3-04 | Encrypted backup (export/import) | ✅ DONE (backend - security hardened) | M2 |
| M3-05 | Vault integrity verification | ✅ DONE (part of export/import) | M2 |
| M3-06 | Vault-version test-construction fix | ✅ DONE | M2 |
| M3-07 | Secure deletion workflow (crypto-erase + overwrite) | ✅ DONE (existing) | M2 |
| M3-08 | Import-rollback write-failure injection | ✅ DONE | M2 |
| M3-09 | Atomic write hardening | ✅ DONE | M2 |
| M3-10 | Symlink validation & rejection | ✅ DONE | M2 |
| M3-11 | Import rollback with verification | ✅ DONE | M2 |
| M3-12 | Vault operation locking | ✅ DONE | M2 |
| M3-13 | Vault info display (path, size, custom/default) | ✅ DONE | M2 |
| M3-14 | Secure temp file creation with 0600 perms | ✅ DONE | M2 |
| M3-15 | Atomic write with rollback on failure | ✅ DONE | M2 |
| M3-16 | Secure temp file permissions verification | ✅ DONE | M2 |
| M3-17 | Symlink detection with lstat semantics | ✅ DONE | M2 |
| M3-17 | Secure temp file collision handling | ✅ DONE | M2 |
| M3-18 | Errno-aware symlink classification (Linux) | ✅ DONE | `lib/posix_fs.dart`, `test/filesystem_security_test.dart` |
| M3-19 | Descriptor-based atomic write (openat, O_NOFOLLOW, dirfds) | ✅ DONE | `lib/posix_fs.dart`, `lib/storage.dart` Linux pipeline |
| M3-20 | Use-time recheck closes validate→use race | ✅ DONE | `StorageDebugHooks.beforeCommit`, cases 11a/11b/11c |
| M3-21 | Process umask(077) at startup | ✅ DONE | `linux/runner/main.cc`, staged `.deb` test |
| M3-22 | Log append race fix (serialized file mutations) | 🟡 PARTIALLY TESTED | Linux `flock(2)` advisory lock plus local lock; independent-process append/rotation/delete coverage remains required |
| M3-23 | Dedicated Linux filesystem security integration tests | ✅ DONE | `test/filesystem_security_test.dart` (20 tests) |
| M3-24 | Post-rename destination identity verification and post-commit cleanup safety | ✅ TESTED | M3-19; `statChildNoFollow` identity comparison; filesystem cases 11d/11e (23/23 focused suite pass, 2026-11-04) |
| M3-25 | Atomic-write caller outcome audit | ✅ TESTED (focused) | M3-15/M3-24; wrapper saves require verified result; move/export/import rollback no-follow readbacks |
| M3-26 | Drawer and encrypted-log atomic persistence | 🟡 PARTIALLY TESTED | M3-19; drawer rejects unverified result; log envelope is atomic/no-follow with advisory locking, but independent-process coverage remains required |

### MILESTONE 4 — Wallet Core

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M4-01 | Account derivation UI (add/remove/switch accounts) | ⏳ PENDING | M3 |
| M4-02 | Private key import (raw hex, keystore JSON v3) | ⏳ PENDING | M3 |
| M4-03 | Seed phrase import (12/24 words, validation) | ⏳ PENDING | M3 |
| M4-04 | Wallet unlock/lock (biometric where available) | ⏳ PENDING | M3 |
| M4-04 | Transaction signing (EIP-1559, legacy) | ✅ DONE | — |
| M4-05 | Signature verification (independent) | ✅ DONE | — |
| M4-06 | Nonce management (pending, replacement) | ⏳ PENDING | M3 |
| M4-07 | Chain ID validation (every sign/broadcast) | ✅ DONE | — |
| M4-08 | Replay protection (EIP-155 chain ID) | ✅ DONE | — |
| M4-09 | Address validation (EIP-55, contract detection) | ✅ DONE | — |

### MILESTONE 5 — Activity Center

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M5-01 | Encrypted log store (BNBLOG01) UI | ⏳ PENDING | M3 |
| M5-02 | Event categories (wallet, network, tx, security, cold, hw) | ⏳ PENDING | M3 |
| M5-03 | Search, filters, date range, severity | ⏳ PENDING | M3 |
| M5-04 | Expandable details (human + technical) | ⏳ PENDING | M3 |
| M5-05 | Sanitized export (no secrets) | ⏳ PENDING | M3 |
| M5-06 | Encrypted log backup/restore | ⏳ PENDING | M3 |
| M5-07 | Retention settings (cap, auto-purge) | ⏳ PENDING | M3 |
| M5-08 | Tamper-evident hash-linked logs | ⏳ PENDING | M3 |

### MILESTONE 6 — Blockchain & RPC

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M6-01 | Custom RPC endpoint manager (add/edit/test/delete) | ⏳ PENDING | M2 |
| M6-02 | Chain ID validation on connect (mismatch blocks) | ✅ DONE | — |
| M6-03 | Endpoint health checks (9-row checklist) | ⏳ PENDING | M2 |
| M6-04 | Node selection modes (manual, strict, auto*) | ⏳ PENDING | M2 |
| M6-05 | Per-node transport override (direct/tor/proxy) | ✅ DONE | — |
| M6-06 | Per-node auth (Bearer/Basic, custom headers) | ⏳ PENDING | M2 |
| M6-07 | Node import/export JSON | ⏳ PENDING | M2 |
| M6-08 | Official door list reset | ✅ DONE | — |

### MILESTONE 7 — Assets & Tokens

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M7-01 | Native BNB balance + transfer | ⏳ PENDING | M4 |
| M7-02 | BEP-20 standard (USDT, USDC, custom) | ⏳ PENDING | M4 |
| M7-03 | Token decimals/symbol from contract (re-verify) | ⏳ PENDING | M4 |
| M7-04 | Fake token warnings (contract address verification) | ⏳ PENDING | M4 |
| M7-05 | Hide/show tokens | ⏳ PENDING | M4 |
| M7-06 | Custom token add/remove (with source links) | ⏳ PENDING | M4 |

### MILESTONE 8 — Transaction Engine & Fees

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M8-01 | Send flow (validation → fee → rehearse → sign → broadcast) | ⏳ PENDING | M4, M7 |
| M8-02 | Fee tiers (LOW/NORMAL/HIGH/CUSTOM) with measured data | ⏳ PENDING | M6 |
| M8-03 | Gas estimation (eth_estimateGas + 20% buffer) | ⏳ PENDING | M6 |
| M8-04 | Transaction simulation (eth_call from sender) | ⏳ PENDING | M6 |
| M8-05 | Pending tx tracking (nonce, replacement, cancellation) | ⏳ PENDING | M4 |
| M8-06 | Receipt double-check (independent node) | ⏳ PENDING | M6 |
| M8-07 | Explorer links (configurable, correct network) | ⏳ PENDING | M6 |
| M8-08 | Fee-on-transfer detection (Transfer events) | ⏳ PENDING | M7 |

### MILESTONE 9 — Central Networking

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M9-01 | NetworkPrivacyManager (single choke point) | ⏳ PENDING | M2 |
| M9-02 | Enforce all traffic through it (no bypass) | ⏳ PENDING | M9-01 |
| M9-03 | Connection modes (Direct/Proxy/SOCKS/Tor/Offline) | ⏳ PENDING | M9-01 |
| M9-04 | DNS leak prevention (SOCKS5h, Tor remote resolve) | ⏳ PENDING | M9-01 |
| M9-05 | IPv4/IPv6 route compliance | ⏳ PENDING | M9-01 |
| M9-06 | WebSocket support through same layer | ⏳ PENDING | M9-01 |

### MILESTONE 10 — Proxies

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M10-01 | HTTP/HTTPS proxy with CONNECT | ⏳ PENDING | M9 |
| M10-02 | Proxy authentication (user/pass) | ⏳ PENDING | M9 |
| M10-03 | Custom ports, IPv4/IPv6 | ⏳ PENDING | M9 |
| M10-04 | TLS validation through proxy | ⏳ PENDING | M9 |
| M10-05 | Fail-closed on proxy failure | ⏳ PENDING | M9 |

### MILESTONE 11 — Tor & Privacy

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M11-01 | Tor SOCKS5 endpoint (system daemon) | ⏳ PENDING | M9 |
| M11-02 | Tor bridge config (obfs4, WebTunnel) | ⏳ PENDING | M11-01 |
| M11-03 | Strict Privacy Mode (all traffic, fail-closed) | ⏳ PENDING | M9 |
| M11-04 | Offline Mode (block all outbound) | ⏳ PENDING | M9 |
| M11-05 | Network leak tests (packet capture) | ⏳ PENDING | M11-03 |
| M11-06 | VPS-through-Tor acceptance scenario | ⏳ PENDING | M11-03 |

### MILESTONE 12 — Cold Wallet (COMPLETE)

| Task ID | Description | Status | Evidence |
|---------|-------------|--------|----------|
| M12-01 | Pairing (public addresses + fingerprint) | ✅ DONE | 15 protocol tests |
| M12-02 | Request creation (unsigned EIP-1559) | ✅ DONE | 15 service tests |
| M12-03 | Request export (QR/file/clipboard) | ✅ DONE | Dialogs implemented |
| M12-04 | Offline signing (account-index aware) | ✅ DONE | Codec + service |
| M12-05 | Response import + strict verification | ✅ DONE | verifyColdSignatureDetailed |
| M12-06 | Replay protection (single-use, burn list) | ✅ DONE | Service tests |
| M12-07 | Expiry + clock skew tolerance | ✅ DONE | 30 min default, 5 min skew |
| M12-08 | Two-device field test | ⚠️ NOT TESTED | Requires second device |

### MILESTONE 13 — Hardware Wallets (REMOVED FROM 1.x SCOPE)

Hardware-wallet integration was removed from the 1.x product scope. The
supported isolation path is cold/offline signing plus the spending controls in
`RISK_CONTROLS.md`. No hardware support is claimed.

### MILESTONE 14 — Final UX & Branding

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M14-01 | Original B-based logo (SVG) | ⏳ PENDING | M2 |
| M14-02 | Black/dark theme, orange/yellow accent | ⏳ PENDING | M2 |
| M14-03 | Application icons (Linux, Android, adaptive) | ⏳ PENDING | M2 |
| M14-04 | Splash screen | ⏳ PENDING | M2 |
| M14-05 | Empty-state illustrations | ⏳ PENDING | M2 |
| M14-06 | Reusable component library | ⏳ PENDING | M2 |
| M14-07 | Progressive disclosure (Simple/Advanced/Expert) | ⏳ PENDING | M2 |
| M14-08 | Explanatory screens (What it protects, what it doesn't) | ⏳ PENDING | M2 |

### MILESTONE 15 — Compatibility & Performance

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M15-01 | Test on low-RAM Linux (2GB) | ⏳ PENDING | M14 |
| M15-02 | Test on slow CPU / constrained env | ⏳ PENDING | M14 |
| M15-03 | Test unstable network / disconnected proxy/Tor | ⏳ PENDING | M11 |
| M15-04 | Test external storage disconnection | ⏳ PENDING | M3 |
| M15-05 | Resource measurements (RAM, CPU, disk) | ⏳ PENDING | M14 |
| M15-06 | Multiple Linux distros (Debian, Fedora, Arch) | ⏳ PENDING | M14 |

### MILESTONE 16 — Final Security Validation

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M16-01 | Full test suite (scripts/test-suite.sh) | ⏳ PENDING | M15 |
| M16-02 | Static analysis (flutter analyze --no-pub) | ⏳ PENDING | M15 |
| M16-03 | Secret scan (scripts/secret-scan.sh) | ⏳ PENDING | M15 |
| M16-04 | Dependency vulnerability scan | ⏳ PENDING | M15 |
| M16-05 | Internal security review (SECURITY_AUDIT.md) | ⏳ PENDING | M15 |
| M16-06 | Evidence collection (docs/evidence/) | ⏳ PENDING | M15 |

### MILESTONE 17 — Release Candidate

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M17-01 | Version bump in pubspec.yaml | ⏳ PENDING | M16 |
| M17-02 | CHANGELOG.md final update | ⏳ PENDING | M16 |
| M17-03 | SBOM regeneration (scripts/sbom.py) | ✅ DONE | M16; regenerated 2026-11-05 |
| M17-04 | Build signed `.deb` (scripts/build-deb.sh) | 🟡 PARTIAL | M16; package checksum and detached signature verified; full source rebuild remains required |
| M17-05 | Clean VM install + smoke test | ⏳ PENDING | M17-04 |
| M17-06 | Verify package contents (no secrets) | ✅ DONE | M17-04; package listing inspected 2026-11-05 |
| M17-07 | SHA-256 + GPG .asc | ✅ DONE | M17-04; SHA-256 and detached GPG signature verified 2026-11-05 |
| M17-08 | Signed git tag (git tag -s) | ⏳ PENDING | M17-07 |
| M17-09 | Push to origin + GitHub release | ⏳ PENDING | M17-08 |

### MILESTONE 18 — Android (BLOCKED UNTIL M17)

| Task ID | Description | Status | Dependencies |
|---------|-------------|--------|--------------|
| M18-01 | Android platform storage (Keystore) | ⏳ BLOCKED | M17 |
| M18-02 | Biometric unlock (local_auth) | ⏳ BLOCKED | M17 |
| M18-03 | Android permissions review | ⏳ BLOCKED | M17 |
| M18-05 | Background networking behavior | ⏳ BLOCKED | M17 |
| M18-06 | Clipboard / screenshot protection | ⏳ BLOCKED | M17 |
| M18-07 | Backup behavior (Auto Backup) | ⏳ BLOCKED | M17 |
| M18-08 | APK signing (env-only, no committed keystore) | ⏳ BLOCKED | M17 |
| M18-09 | Release key management | ⏳ BLOCKED | M17 |
| M18-10 | App sandboxing verification | ⏳ BLOCKED | M17 |

---

## Success Criteria for Linux Release Candidate (M17)

- [ ] Successful `flutter build linux --release`
- [ ] Real `.deb` creation via `scripts/build-deb.sh`
- [ ] Package installs on clean Ubuntu 22.04/24.04 amd64
- [ ] Application launches, shows dashboard
- [ ] Local encrypted vault: create, unlock, lock, password change
- [ ] Backup + restore (encrypted)
- [ ] Storage path change + move vault
- [ ] Transaction signing (BNB + BEP-20)
- [ ] Transaction verification (independent)
- [ ] Fee calculation (EIP-1559 + legacy)
- [ ] Custom RPC add/edit/test
- [ ] Proxy routing (HTTP/HTTPS/SOCKS5)
- [ ] Tor routing (system daemon)
- [ ] Strict Privacy Mode (fail-closed verified)
- [ ] Offline Mode (blocks all outbound)
- [ ] Network leak test evidence (packet capture)
- [ ] Local activity logs (encrypted, searchable)
- [ ] Cold wallet pairing + offline sign + verify + broadcast
- [ ] Complete documentation (user + developer)
- [ ] Dependency inventory + SBOM
- [ ] Secret scan clean

---

## Next Actions (Immediate)

1. **Begin Milestone 4** — Wallet Core
2. **Implement M4-01: Account derivation UI** — Add/remove/switch accounts in wallet management
3. **Implement M4-02: Private key import UI** — Raw hex, keystore JSON v3 import dialogs
4. **Implement M4-03: Seed phrase import UI** — 12/24 word validation, checksum verification
5. **Implement M4-04: Wallet unlock/lock UI** — Biometric integration where available
6. **Implement M4-06: Nonce management UI** — Pending transaction display, replacement UI
7. **Run full test suite** after each UI component

---

*This plan is authoritative. Update at every milestone completion. Do not mark incomplete work as complete.*
