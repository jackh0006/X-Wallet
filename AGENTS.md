# AGENTS.md — Persistent Instructions for All OpenCode Sessions

## MANDATORY: change-scoped re-verification

Before any version update, read
[docs/UPDATE_PLAYBOOK.md](docs/UPDATE_PLAYBOOK.md). It is the required,
remembered procedure.

- Verify the **changed surface completely**; reuse recorded evidence only for
  files, dependencies, and build inputs that did not change.
- Always run the cheap global gates (format, analyze, branding, free-use,
  inventory, release evidence, manifest, docs sync, secret scan, dependency
  audit, identity, release gate).
- Run the full suite **once** for a release candidate or a shared-core or
  dependency change — not repeatedly for every small edit.
- Never publish `PENDING` results, an unsigned artifact, or a hash copied from
  an older build.
- Bind every result to the exact commit and state that the audit is internal,
  not independent. Do not claim a guaranteed safety score.

The 1.2.0 heavy verification path was about 40–50 minutes; the two-hour figure
came from repeated full-suite runs. Follow the playbook to avoid that cost.

## Product Mission

**X Wallet** — A complete, professional, highly secure, privacy-focused, self-custodial, open-source EVM wallet with:

- Local encrypted storage (vaults)
- Tor and proxy support (HTTP, HTTPS, SOCKS5)
- Cold-wallet offline signing (hardware-wallet integration is **outside the 1.x scope**)
- Comprehensive EVM blockchain functionality (BNB Smart Chain enabled in 1.2.0; more networks planned)
- Transparent, encrypted local activity logs
- Beautiful, exceptionally easy user experience (black/dark theme, orange/yellow accent)
- Releases: Android APK (arm64 + universal) and Ubuntu Linux amd64 `.deb`

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          X Wallet (Flutter/Dart)                  │
├─────────────────────────────────────────────────────────────────────────┤
│  UI Layer (lib/screens/, lib/widgets/)                                  │
│  ├── Dashboard / Home                                                   │
│  ├── Wallets / Vault Management                                         │
│  ├── Assets / Token Management                                          │
│  ├── Send / Receive / Fee Selection                                     │
│  ├── Transaction History / Explorer                                     │
│  ├── Cold Wallet (offline signing; hardware wallets out of scope)                      │
│  ├── Network Settings / Tor / Proxy                                     │
│  ├── Storage / Backup / Password                                        │
│  ├── Activity Center / Security Center                                  │
│  └── Settings                                                           │
├─────────────────────────────────────────────────────────────────────────┤
│  Core Services (lib/)                                                   │
│  ├── app_state.dart         — Central state (ChangeNotifier)            │
│  ├── wallet_core.dart       — Pure crypto/validation (BIP-39/44, EIP-55)│
│  ├── vault.dart             — Encrypted vault (Argon2id + XChaCha20)    │
│  ├── kdf.dart               — Native Argon2id + pure-Dart fallback      │
│  ├── storage.dart           — Preferences + secure storage              │
│  ├── cold_wallet*.dart      — Cold wallet protocol & service            │
│  ├── rpc_service.dart       — RPC engine, node management               │
│  ├── fee_engine.dart        — Fee estimation (EIP-1559 + legacy)        │
│  ├── tx_lifecycle.dart      — Send journey (rehearse→sign→broadcast)    │
│  ├── receipt_store.dart     — Encrypted receipt archive                 │
│  ├── encrypted_log_store.dart — Encrypted activity logs                 │
│  ├── net/privacy_client.dart — Central network layer (TLS, proxy, Tor)  │
│  ├── memory_protection.dart — FFI kernel hardening (Linux)              │
│  └── workers.dart           — Isolate-based KDF (Argon2id off UI thread)│
├─────────────────────────────────────────────────────────────────────────┤
│  Platform                                                               │
│  ├── Linux: flutter build linux → .deb (build-deb.sh)                   │
│  └── Android: flutter build apk → .apk (build-apk.sh, env-only signing) │
└─────────────────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
/home/mhh06/X-Wallet/
├── AGENTS.md                    # This file
├── pubspec.yaml / pubspec.lock
├── analysis_options.yaml
├── dart_test.yaml
├── README.md
├── SECURITY_AUDIT.md
├── LICENSE (AGPL-3.0-or-later)
├── .gitignore
├── .github/workflows/verify.yml
├── scripts/
│   ├── build-apk.sh        # Android (requires env vars, no committed keystore)
│   ├── build-deb.sh        # Linux .deb release
│   ├── test-suite.sh       # Sequential test runner (KDF tests separate)
│   ├── secret-scan.sh      # CI secret scanning
│   ├── check_token_sources.py
│   └── sbom.py
├── lib/                    # All Dart source
├── test/                   # Flutter tests (unit + widget)
├── verification/           # Independent ethers.js cold-signature verification
├── docs/
│   ├── project/            # BASELINE.md, etc.
│   ├── security/           # THREAT_MODEL, SECURITY_CLAIMS, etc.
│   ├── testing/            # TEST_MATRIX.md
│   ├── hardware/           # COMPATIBILITY_MATRIX.md
│   ├── network/            # NETWORK_GUIDE.md
│   ├── DECISIONS/          # Architectural decisions
│   ├── evidence/           # Test reports, build metadata (NO SECRETS)
│   └── *.md                # Existing docs (ARCHITECTURE, CRYPTO, etc.)
├── assets/
│   ├── icon/               # App icons
│   └── token_sources.json
├── linux/                  # Flutter Linux config
├── android/                # Flutter Android config
└── build/                  # Build outputs (gitignored)
```

## Coding Conventions

- **Dart**: Follow `analysis_options.yaml` (flutter_lints + custom rules)
- **No `dart:io` in pure logic** — use platform-agnostic interfaces
- **No direct `http`/`HttpClient` in business logic** — all network via `RpcService`/`privacy_client.dart`
- **Secrets never in logs, URLs, or SharedPreferences** — only `flutter_secure_storage`
- **Worker isolates for Argon2id** — `workers.dart` via `compute()`
- **Immutable data classes** — `@immutable`, `final` fields, `const` constructors
- **Fail closed** — any validation error stops the operation
- **Explicit error types** — custom exceptions with stable messages
- **Documentation comments** on all public APIs

## Security Invariants

1. **Seed/private keys never leave local signing boundary**
   - No network transmission, no clipboard, no logs, no URLs
   - `ClipboardGuard.secretFree()` blocks seed-shaped text
2. **Vault encryption**: Argon2id (64 MiB, t=3, p=4) + XChaCha20-Poly1305, double-wrapped (password + device-bound secret)
3. **Cold wallet**: Offline signer has no network; online companion has no keys; pairing/request/response envelopes are versioned, checksummed, field-allowlisted
4. **TLS pinning**: Standard CA/hostname validation FIRST, then SPKI pin; never bypass validation
5. **Memory hardening (Linux)**: `prctl(PR_SET_DUMPABLE,0)`, `setrlimit(RLIMIT_CORE,0)`, best-effort `mlockall` via FFI
6. **No committed secrets**: `secret-scan.sh` runs in CI; `.gitignore` blocks keystores, `.jks`, `.p12`, `.pfx`, `key.properties`
7. **Offline mode enforced at network layer**: `NetworkPrivacyManager` blocks all outbound
8. **Strict privacy mode**: All traffic through configured route (Tor/proxy); fail closed; no silent fallback

## Network Invariants

1. **Single choke point**: All outbound via `lib/net/privacy_client.dart` → `RpcService`
2. **Supported transports**: Direct HTTPS, HTTP/HTTPS proxy (CONNECT), SOCKS5 (with auth), Tor (system daemon), Tor bridges
3. **DNS leak prevention**: SOCKS5h / Tor remote resolution; no local DNS before proxy
4. **Certificate validation never disabled**: Even with pins, standard validation runs first
5. **HTTP CONNECT with pins**: Refused before socket opens (not silently downgraded)
6. **No identifying headers**: `User-Agent` scrubbed; only `Content-Type`/`Accept`
7. **RPC chain ID validated on every connect**: Mismatch blocks the node

## Storage Invariants

1. **Vault location**: `$XDG_DATA_HOME/bnb-wallet/` (Linux), app documents (Android)
2. **Vault format**: `BNBVL004` (v2) — double AEAD, authenticated header, atomic write (tmp→rename), 0600 perms
3. **Legacy v1 (`BNBVL003`)**: Read-only migration on next save
4. **Secrets only in secure storage**: `device_secret_v2`, `app_lock_pin_hash`, `app_lock_backoff`, `bscscan_api_key`
5. **Preferences only public config**: Network, RPC nodes, tokens, profiles, auto-lock, Tor settings
6. **Activity logs encrypted at rest**: `BNBLOG01` envelope, wallet key + device secret
7. **Receipts encrypted at rest**: `BNBRCPT1` envelope, capped at 200 entries
8. **Erase all data**: Crypto-erasure (delete device secret) + best-effort overwrite + preference wipe

## Test Commands

```bash
# Full test suite (sequential-aware)
bash scripts/test-suite.sh

# Manual phases:
flutter test --exclude-tags kdf --concurrency=2    # Light suites (2-wide)
flutter test --tags kdf --concurrency=1            # KDF suites (sequential)

# Individual suites:
flutter test test/cold_wallet_protocol_test.dart
flutter test test/cold_wallet_service_test.dart
flutter test test/tls_pinning_test.dart
flutter test test/memory_protection_test.dart
flutter test test/vault_test.dart
flutter test test/workers_test.dart

# Static analysis
flutter analyze --no-pub

# Secret scan
bash scripts/secret-scan.sh

# Independent cold-signature verification (ethers.js)
cd verification && npm ci && node verify.cjs

# SBOM generation
python3 scripts/sbom.py --out docs/SBOM.json
```

## Build Commands

```bash
# Linux .deb release
bash scripts/build-deb.sh
# Output: /home/mhh06/Downloads/X Wallet/x-wallet-<version>-amd64.deb (+ .sha256 + .asc)

# Android APK (requires external keystore via env)
export BNB_KEYSTORE=/path/to/release.keystore
export BNB_KEY_ALIAS=myalias
export BNB_STORE_PASS=storepass
export BNB_KEY_PASS=keypass
bash scripts/build-apk.sh
# Output: ./dist/x-wallet-<version>-android-arm64.apk (+ .sha256 + optional .asc)
```

## Release Procedure

1. **Version bump** in `pubspec.yaml`
2. **Run full verification**: `flutter analyze`, `bash scripts/test-suite.sh`, `bash scripts/secret-scan.sh`, `cd verification && npm ci && node verify.cjs`
3. **Update CHANGELOG.md**
4. **Regenerate SBOM**: `python3 scripts/sbom.py --out docs/SBOM.json`
5. **Build Linux .deb**: `bash scripts/build-deb.sh` (sign with GPG key)
6. **Verify .deb**: Install on clean Ubuntu, test launch, vault, send, network
7. **Tag release**: `git tag -s v1.x.y -m "Release v1.x.y"`
8. **Push**: `git push origin main --tags`
9. **Android (separate)**: Use `build-apk.sh` with env credentials; never commit keystore

## Documentation Requirements

Every meaningful change must update:
- `CHANGELOG.md` (user-facing changes)
- `docs/PROJECT_STATUS.md` (current state)
- Relevant technical doc (CRYPTO, THREAT_MODEL, SECURITY, SPEC-COMPLIANCE, etc.)
- `docs/DECISIONS/` for architectural decisions

## Current Blockers (as of 2026-11-10)

| ID | Blocker | Status |
|----|---------|--------|
| BLK-01 | KDF tests exhaust memory on 2-core 4GB machine | Documented; tests pass individually with generous timeouts |
| BLK-02 | No two-device physical cold-wallet test | Requires second device; file/paste/QR tested in code |
| BLK-03 | No local Anvil integration test | `anvil` not installed; fake RPC used in tests |
| BLK-04 | Hardware wallet compatibility unverified | No physical devices; matrix is NOT TESTED |
| BLK-05 | Linux QR camera scanning not implemented | File/paste/QR display only; camera plugin needed |
| BLK-06 | Old release keystore in Git history | **COMPROMISED, ROTATED, DENYLISTED** — old `10c13a…` in `release/android-signer-denylist.txt`; current signer `db1286…` |
| BLK-07 | `mlockall` best-effort; may fail under low RLIMIT_MEMLOCK | Kernel-state test asserts dumpable=0, core=0 only |
| BLK-08 | HTTP CONNECT with pins refused, not enforced | Documented limitation |

## Rules Against Fake Implementations

- ❌ No placeholder buttons that show "success" without real action
- ❌ No dummy success indicators (green checkmarks without verification)
- ❌ No unfinished security features presented as complete
- ❌ No invented test results — run the actual tests
- ❌ No claim a build succeeded unless it actually succeeded
- ❌ No claim hardware works unless integration tested or explicitly qualified
- ❌ No weakening security to make a test pass
- ❌ No silent downgrade of privacy/security
- ❌ No automatic bypass of failed Tor/proxy connection
- ❌ No private keys/seed phrases outside local signing boundary
- ❌ No committed secrets, credentials, private keys, wallet files, release signing keys

## Rules Against Unverified Claims

- Distinguish **IMPLEMENTED** (code exists) from **TESTED** (automated test passes) from **VERIFIED WITH EVIDENCE** (independent reproduction, packet capture, hardware test)
- **NOT TESTED** = no automated test + no manual verification
- **BLOCKED** = explicit dependency preventing progress
- **NOT SUPPORTED** = intentionally out of scope
- Internal self-audit ≠ independent third-party audit — state this clearly
- "Testnet ready" ≠ "Production ready" — distinguish explicitly

---

**At session start**: Read this file, `IMPLEMENTATION_STATUS.md`,
`docs/IMPLEMENTATION_LOG.md`, `docs/SECURITY_SCORECARD.md`,
`docs/SECURITY_RISK_REGISTER.md`, `docs/THREAT_MODEL.md`,
`docs/TEST_RESULTS.md`, `docs/RELEASE_PROCESS.md`, and the release manifest.

**At session end**: Append to `docs/IMPLEMENTATION_LOG.md`, update
`IMPLEMENTATION_STATUS.md` and `docs/SECURITY_SCORECARD.md`, and record exact
next steps. Never claim a check passed without a command, exit code, commit,
and log.

## Mandatory GitHub Publication and Version Evidence

These rules apply to every human or AI agent:

1. Do not leave a completed, validated change only in a local checkout. Before
   reporting completion, commit and push it to GitHub. If `main` is protected,
   create or update a focused pull request and report its URL and check state.
2. Do not force-push, disable protections, or claim a merge/release is
   complete when required checks are pending, canceled, or failed.
3. Treat `pubspec.yaml`'s `version:` as the source version. Every version
   change needs a matching `docs/releases/<major>.<minor>.<patch>.md` record
   naming the exact version, including its build suffix.
4. The record must contain a marked `Check / Result / Evidence` table. Mark
   incomplete work as `IN PROGRESS`, `NOT CONFIRMED`, `NOT TESTED`, or
   `NOT AVAILABLE`; never invent a `PASS` result.
5. A Linux release is confirmed only when its tagged source, `.deb`, detached
   signature, `SHA256SUMS`, SBOM, automated checks, and clean-install evidence
   all identify the same version and commit. A newer prerelease is not a
   confirmed stable release merely because it exists.
6. When adding, renaming, or removing a Flutter test file, update
   `docs/testing/TEST_MATRIX.md` in the same change. GitHub CI enforces this
   with `scripts/test_inventory.py --check`; never bypass or remove that check.

## Mandatory Release Evidence Workflow

The machine-readable source of truth is `release/manifest.json`, generated by
`scripts/release_manifest.py`. Do not hand-edit it.

1. After any source, dependency, test, SBOM, or toolchain change, run:
   `python3 scripts/test_inventory.py`, `python3 scripts/release_manifest.py`,
   and `python3 scripts/generate_docs.py`. Commit the generated files.
2. `docs/GENERATED_STATUS.md` and the README status block are generated. Do
   not edit them by hand; `docs-sync` CI rejects drift.
3. Record verification with `scripts/record_check.py` (for example
   `python3 scripts/record_check.py --id full-test-suite -- bash scripts/test-suite.sh`).
   Never write a result that a command did not produce. A timeout, OOM, or
   interrupted run is `FAILED`/`INCOMPLETE`.
4. `release/checks.json` and `release/artifacts.json` are per-build evidence
   and are gitignored. A published bundle is `release/evidence.json`, bound to
   an exact `sourceCommit`. Do not mix results from another commit.
5. `python3 scripts/release-gate.py` reports `VERIFIED`,
   `PARTIALLY VERIFIED`, `INCOMPLETE`, or `FAILED`. Do not call a release
   confirmed unless it is `VERIFIED` for the exact tagged commit and artifact.
6. Android artifacts are blocked until
   `docs/security/INCIDENT_2026-11-KEYSTORE.md` is closed, the historical
   fingerprint is in `release/android-signer-denylist.txt`, and the replacement
   signer is approved. Never generate or commit a signing key here.
7. The production KDF is native Argon2id (`lib/kdf.dart`). Never lower the
   fixed 64 MiB / t=3 / p=4 parameters. Envelope tests may use the
   assert-guarded `VaultCipher.debugKdfOverride`; a real production-parameter
   test must remain.
8. Run `dart format` before committing. Run one Flutter test process at a
   time on a small machine; concurrent `flutter test` runs have caused native
   test-device segmentation faults and are not evidence of a code failure.
9. Do not run `scripts/build-deb.sh`, tag, publish, or upload any release
   artifact unless the release gate says `VERIFIED` and the owner has approved
   the signing-key recovery plan.
