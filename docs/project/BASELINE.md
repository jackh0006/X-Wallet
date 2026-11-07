# BASELINE.md — Repository Baseline Report

> **Historical baseline (2026-11-03).** Current release-candidate evidence for
> `1.0.10+4` is in [`../GENERATED_STATUS.md`](../GENERATED_STATUS.md),
> `release/manifest.json`, and [`../releases/1.0.10.md`](../releases/1.0.10.md).
> Do not use this baseline's test counts or statuses for a new release.

**Date**: 2026-11-03
**Commit**: `68091b06cce3e9c90692e3f632d539ae69734154`
**Branch**: `main` (up to date with `origin/main`)
**Safety Branch**: `safety/pre-reaudit-19e03c8` (merged via fast-forward)

---

## Existing Working Features

| Feature | Status | Evidence |
|---------|--------|----------|
| **Vault Encryption (v2 BNBVL004)** | IMPLEMENTED, TESTED | `lib/vault.dart`, `test/vault_test.dart` (7 KDF tests) |
| **Vault v1 Migration (BNBVL003)** | IMPLEMENTED, TESTED | `lib/vault.dart`, `test/vault_test.dart` |
| **BIP-39/44 Wallet Core** | IMPLEMENTED, TESTED | `lib/wallet_core.dart`, `test/wallet_core_test.dart` |
| **EIP-55 Address Display** | IMPLEMENTED, TESTED | `lib/wallet_core.dart` |
| **Argon2id KDF (64 MiB, t=3, p=4)** | IMPLEMENTED, TESTED | `lib/vault.dart`, `lib/workers.dart`, `test/workers_test.dart` |
| **Worker Isolate KDF (off UI thread)** | IMPLEMENTED, TESTED | `lib/workers.dart`, `test/workers_test.dart` (3 tests) |
| **XChaCha20-Poly1305 AEAD** | IMPLEMENTED, TESTED | `lib/vault.dart`, `lib/receipt_store.dart`, `lib/encrypted_log_store.dart` |
| **Device-Bound Secret (double-wrapped DEK)** | IMPLEMENTED, TESTED | `lib/vault.dart`, `lib/storage.dart` |
| **App Lock PIN (Argon2id + backoff)** | IMPLEMENTED, TESTED | `lib/security.dart`, `lib/storage.dart` |
| **Auto-Lock (idle + background)** | IMPLEMENTED | `lib/app_state.dart` |
| **Erase All Data (crypto-erasure + overwrite)** | IMPLEMENTED, TESTED | `lib/storage.dart`, `test/erase_flow_test.dart` |
| **Cold Wallet Protocol (envelopes)** | IMPLEMENTED, TESTED | `lib/cold_wallet_protocol.dart`, `test/cold_wallet_protocol_test.dart` (15) |
| **Cold Wallet Service (persistence, replay, broadcast)** | IMPLEMENTED, TESTED | `lib/cold_wallet_service.dart`, `test/cold_wallet_service_test.dart` (15) |
| **Cold Transaction Codec (EIP-1559 canonical RLP)** | IMPLEMENTED, TESTED | `lib/cold_tx_codec.dart`, `test/cold_tx_codec_test.dart` (4) |
| **Cold Wallet UI Dialogs** | IMPLEMENTED | `lib/screens/cold_wallet_dialogs.dart` |
| **Wallet Mode Transitions (hot/cold/online)** | IMPLEMENTED | `lib/app_state.dart` |
| **RPC Service (node book, pools, health checks)** | IMPLEMENTED, TESTED | `lib/rpc_service.dart`, `test/nodes_test.dart`, `test/node_manager_test.dart` |
| **Fee Engine (EIP-1559 + legacy, multi-node merge)** | IMPLEMENTED, TESTED | `lib/fee_engine.dart`, `test/fee_engine_test.dart`, `test/fee_parity_test.dart` |
| **Send Lifecycle (rehearse→sign→broadcast→receipt)** | IMPLEMENTED, TESTED | `lib/tx_lifecycle.dart`, `test/send_intent_test.dart`, `test/tx_lifecycle_test.dart` |
| **Receipt Store (BNBRCPT1, capped 200)** | IMPLEMENTED, TESTED | `lib/receipt_store.dart`, `test/receipt_store_test.dart` |
| **Encrypted Activity Logs (BNBLOG01)** | IMPLEMENTED, TESTED | `lib/encrypted_log_store.dart`, `test/encrypted_log_store_test.dart` |
| **Tor / SOCKS5 Proxy (fail-closed)** | IMPLEMENTED, TESTED | `lib/net/privacy_client.dart`, `test/privacy_dialogs_test.dart` |
| **TLS SPKI Pinning (standard validation first)** | IMPLEMENTED, TESTED | `lib/net/privacy_client.dart`, `test/tls_pinning_test.dart` (6) |
| **Memory Protection (FFI prctl/setrlimit/mlockall)** | IMPLEMENTED, TESTED | `lib/memory_protection.dart`, `test/memory_protection_test.dart` (2) |
| **Clipboard Guard (secret detection + auto-clear)** | IMPLEMENTED, TESTED | `lib/screens/common.dart`, `test/clipboard_guard_test.dart` |
| **Backup Quiz (3-word verification)** | IMPLEMENTED, TESTED | `lib/backup_quiz.dart`, `test/backup_quiz_test.dart` |
| **Watch-Only Accounts** | IMPLEMENTED, TESTED | `lib/app_state.dart`, `test/watch_only_test.dart` |
| **Token Sources (official links + user links)** | IMPLEMENTED, TESTED | `lib/screens/settings_page.dart`, `test/token_sources_test.dart` |
| **Journey Map / Hold-to-Confirm Widgets** | IMPLEMENTED, TESTED | `lib/widgets/`, `test/journey_map_test.dart`, `test/hold_to_confirm_test.dart` |
| **Build Scripts (.deb, .apk env-only)** | IMPLEMENTED | `scripts/build-deb.sh`, `scripts/build-apk.sh` |
| **Secret Scan CI** | IMPLEMENTED, TESTED | `scripts/secret-scan.sh` |
| **Independent ethers.js Verification** | IMPLEMENTED, TESTED | `verification/verify.cjs` (ethers 6.17.0) |

---

## Missing Features

| Feature | Status | Notes |
|---------|--------|-------|
| **Hardware Wallet Integration** | OUT OF SCOPE | Removed from the 1.x product scope; cold/offline signing is the isolation path |
| **Camera QR Scanning (Linux)** | NOT SUPPORTED | File/paste/QR display only; requires camera plugin |
| **WalletConnect / DApp Browser** | NOT STARTED | Not in current scope |
| **NFT Support** | NOT STARTED | Not in current scope |
| **Android Platform-Specific Features** | NOT STARTED | Biometrics, Keystore, background networking, USB/BT HW wallet |
| **Light / AMOLED Themes** | NOT SUPPORTED | Dark theme only |
| **Full i18n (beyond 6 locales)** | PARTIAL | en, fa, ar, zh, ru, es only |
| **Per-Node HTTP Auth / Custom Headers** | NOT STARTED | SOCKS5 auth only |
| **Node Selection Modes (auto/random/quorum)** | NOT STARTED | Manual + strict only |
| **Access List Transaction Support** | NOT SUPPORTED | Cold codec rejects access lists |
| **OS-Enforced Air Gap Build (no INTERNET)** | NOT SUPPORTED | Runtime offline only |
| **Reproducible Build Verification** | NOT TESTED | Toolchain pin not finalized |

---

## Known Vulnerabilities / Concerns

| ID | Concern | Severity | Status |
|----|---------|----------|--------|
| BLK-06 | Old release keystore in Git history (compromised) | CRITICAL | **Must rotate**; cannot rewrite public history |
| BLK-01 | KDF tests OOM on 2-core 4GB machine | HIGH | Documented; tests pass individually with generous timeouts |
| BLK-02 | No two-device physical cold-wallet test | MEDIUM | File/paste/QR tested in code only |
| BLK-03 | No local Anvil integration test | MEDIUM | `anvil` not installed; fake RPC used |
| BLK-05 | Linux QR camera scanning not implemented | LOW | File/paste/QR display only |
| BLK-07 | `mlockall` best-effort; may fail under low RLIMIT_MEMLOCK | LOW | Kernel test asserts dumpable=0, core=0 only |
| BLK-08 | HTTP CONNECT with pins refused, not enforced | LOW | Documented limitation |

---

## Build Status

| Platform | Status | Notes |
|----------|--------|-------|
| **Linux amd64 (debug)** | BUILDS | `flutter build linux --debug` works |
| **Linux amd64 (release)** | BUILDS | `flutter build linux --release` works |
| **Linux .deb package** | NOT TESTED | `scripts/build-deb.sh` exists; clean-environment test needed |
| **Android arm64 (debug)** | BUILDS | `flutter build apk --debug` works |
| **Android arm64 (release)** | NOT TESTED | `scripts/build-apk.sh` requires external keystore via env |

---

## Test Status

| Suite | Count | Result | Notes |
|-------|-------|--------|-------|
| **Non-KDF (flutter test --exclude-tags kdf)** | 209 | ✅ PASS | All light suites + cold/TLS/memory/widget/privacy |
| **KDF (flutter test --tags kdf)** | 10 | ⚠️ RESOURCE EXHAUSTION | 7 vault + 3 workers; OOM after ~2.5h on 2-core 4GB |
| **vault_test.dart (individual)** | 7 | ✅ PASS | Each passes with 8-min timeout |
| **workers_test.dart (individual)** | 3 | ✅ PASS | Each passes with 8-15 min timeout |
| **cold_tx_codec_test.dart** | 4 | ✅ PASS | |
| **cold_wallet_protocol_test.dart** | 15 | ✅ PASS | |
| **cold_wallet_service_test.dart** | 15 | ✅ PASS | |
| **cold_wallet_test.dart** | 8 | ✅ PASS | |
| **tls_pinning_test.dart** | 6 | ✅ PASS | |
| **memory_protection_test.dart** | 2 | ✅ PASS | Linux only |
| **privacy_dialogs_test.dart** | 2 | ✅ PASS | |
| **widget_test.dart** | 3 | ✅ PASS | |
| **verification/verify.cjs (ethers.js)** | 1 script | ✅ PASS | 8 substitution cases rejected |
| **secret-scan.sh** | 1 scan | ✅ PASS | No tracked keystores/private keys |
| **flutter analyze --no-pub** | — | ✅ NO ERRORS | 1 unused_element warning only |

---

## Dependencies (Key)

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter` | 3.47.6 (stable) | UI framework |
| `dart` | 3.13.5 | Language |
| `web3dart` | ^3.0.3 | Ethereum/EVM interaction, secp256k1 |
| `wallet` | ^0.0.18 | HD wallet, BIP-32/44, signing |
| `bip39_mnemonic` | ^4.1.0 | BIP-39 seed phrases |
| `bip32_plus` | ^1.0.0 | BIP-32 derivation |
| `cryptography` | ^2.9.0 | Argon2id, XChaCha20-Poly1305, HKDF, SHA-256 |
| `dargon2_flutter` | ^3.3.0 | Argon2id (platform-optimized) |
| `socks5_proxy` | ^2.1.1 | SOCKS5 CONNECT for Tor/proxy |
| `flutter_secure_storage` | ^11.2.0 | Platform secure storage (Keystore/Keychain/libsecret) |
| `local_auth` | ^3.0.2 | Biometric auth (Android/iOS) |
| `qr_flutter` | ^4.1.0 | QR code generation |
| `asn1lib` | ^1.6.8 | Certificate parsing (TLS pinning) |
| `ffi` | ^2.2.0 | Linux kernel calls (prctl/setrlimit/mlockall) |
| `ethers` | 6.17.0 | Independent verification (Node.js) |

---

## Architecture

See `docs/ARCHITECTURE.md` and `AGENTS.md` for module map.

**Core principle**: All network traffic through `lib/net/privacy_client.dart` → `RpcService`. No direct `http`/`HttpClient` in business logic.

**Crypto boundary**: `wallet_core.dart` + `cold_tx_codec.dart` + `vault.dart` + `workers.dart`. No secrets in UI layer.

**State**: `app_state.dart` (ChangeNotifier) is single source of truth.

---

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Ubuntu Linux amd64 (X11/Wayland)** | PRIMARY | First release target; .deb package |
| **Other Linux (Debian, Fedora, Arch)** | UNTESTED | Should work; .deb may need conversion |
| **Android (arm64)** | PLANNED | Second release target; APK via env-only signing |
| **Windows** | NOT SUPPORTED | No build config; FFI memory protection Linux-only |
| **macOS** | NOT SUPPORTED | No build config; FFI memory protection Linux-only |
| **iOS** | NOT SUPPORTED | No build config |

---

## Existing Release Artifacts

| Artifact | Status | Location |
|----------|--------|----------|
| **Linux .deb** | NOT BUILT | `scripts/build-deb.sh` outputs to `/home/mhh06/Downloads/X Wallet/` |
| **Android APK** | NOT BUILT | `scripts/build-apk.sh` outputs to `./dist/` (requires keystore env) |
| **GPG Signatures** | NOT CREATED | `build-deb.sh` and `build-apk.sh` create `.asc` if GPG key provided |
| **SHA-256 Checksums** | NOT CREATED | Build scripts generate `.sha256` files |
| **SBOM** | COMMITTED | `docs/SBOM.json` (deterministic from `pubspec.lock`) |

---

## Summary Status Legend

- **IMPLEMENTED** — Code exists and compiles
- **TESTED** — Automated tests pass
- **NOT TESTED** — No automated test + no manual verification
- **BLOCKED** — Explicit dependency preventing progress
- **NOT SUPPORTED** — Intentionally out of scope
- **REQUIRES INVESTIGATION** — Unknown status, needs research

> **Note**: This baseline reflects the state at commit `68091b0`. Do not confuse implementation with verification. Internal self-audit ≠ independent third-party audit.
