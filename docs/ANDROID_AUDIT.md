# Android Audit — X Wallet

**Date:** 2026-11-10
**Audit baseline:** branch `release/1.4.3`, commit `9eac76d`
**Audience:** project owner and the engineer/AI continuing the work
**Scope:** `lib/`, `android/`, `test/`, `scripts/`, `.github/`, and the current
project documentation. This is a static, file-level audit plus the existing
local test history. It is **not** an independent audit and **not** a physical
device test.

---

## 0. Read this first: the brief is partly out of date

The supplied master prompt assumes X Wallet has no Android release. That is no
longer true. The repository and public releases show:

- Android 1.4.0, 1.4.1, and 1.4.2 APKs exist.
- `v1.4.2` is the current GitHub **Latest** release and publishes
  `x-wallet-1.4.2-android-arm64.apk` and
  `x-wallet-1.4.2-android-universal.apk`.
- The current Android certificate in the signed 1.4.2 and 1.4.3 preview APKs is
  `db12869c9127914ff2b8f64cc0a14ddc9be481bf8b4713fb26bb0bd0bd9748d3`.
- The historical certificate
  `10c13aa91cc14288df995095c6b620ff60f3c10e77fd6615635b150463e25b85`
  is present in `release/android-signer-denylist.txt`.
- The incident record still says rotation is not done and the denylist is
  empty. That is stale documentation and is listed as a finding below.

So the work is not "add Android from zero". It is: **turn a working but
desktop-shaped Android app into a hardened, beginner-simple Android-first
wallet without weakening the existing vault, signing, or network controls.**
Linux must keep working unless the owner explicitly decides otherwise.

---

## 1. Method and limits

Inspected:

- `AGENTS.md`, `README.md`, `IMPLEMENTATION_STATUS.md`, `SECURITY.md`
- `docs/SECURITY_SCORECARD.md`, `docs/THREAT_MODEL.md`, `docs/CRYPTO.md`,
  `docs/COLD_WALLET.md`, `docs/network/NETWORK_GUIDE.md`,
  `docs/security/INCIDENT_2026-11-KEYSTORE.md`, `docs/ANDROID.md`
- every file under `android/`
- `lib/main.dart`, `lib/app_state.dart`, `lib/storage.dart`, `lib/kdf.dart`,
  `lib/security.dart`, `lib/workers.dart`, `lib/vault.dart`,
  `lib/privacy_client.dart`, `lib/platform_files.dart`, `lib/tor_manager.dart`,
  and every screen/widget
- `test/` inventory and the Android-related tests
- `.github/workflows/` and the release/signing scripts

The current tree at `9eac76d` has a clean `flutter analyze` result. The last
local full suite on the 1.4.3 line passed 60/60 non-integration files (793 s),
with 14 focused re-runs after the final UI edits. Those results are evidence
for the Dart/desktop surface, **not** for Android runtime behavior.

Not done in this phase:

- no physical Huawei Y9 2019 run
- no emulator run
- no Android Keystore/StrongBox/biometric test
- no camera/QR test
- no TalkBack or 200% text walkthrough on a device
- no Android performance measurement
- no independent audit

---

## 2. Current architecture

### 2.1 Layers

```
lib/
  main.dart, app_state.dart           app shell and ChangeNotifier state
  screens/                            Home, Wallet, Send, Inspect, Settings,
                                      Logs, Receipt, and dialogs
  widgets/                            hold-to-confirm, seed picker, journey map
  vault.dart, kdf.dart, workers.dart  vault and Argon2id
  wallet_core.dart, send_intent.dart  keys, addresses, transaction intent
  cold_*                              cold/offline signing protocol
  rpc_service.dart, fee_engine.dart   node pool, chain calls, fees
  net/privacy_client.dart             single HTTP choke point, TLS/proxy/Tor
  storage.dart, posix_fs.dart         prefs, secure storage, atomic writes
  receipt_store.dart                  encrypted receipts
  encrypted_log_store.dart            encrypted activity log
  price_service.dart                  public USD prices (CoinGecko)
```

This is a **feature-first**, not a layered, codebase. UI imports core modules
directly. There is no `lib/core/`, `lib/ui/`, or `lib/platform/` boundary yet.
`app_state.dart` is a 2,000+ line god object. `send_page.dart` is 2,363 lines,
`wallet_page.dart` 2,874 lines, and `settings_page.dart` 3,243 lines.

### 2.2 Navigation

There are five bottom tabs and no named routes:

| Index | Screen | Current role |
|---:|---|---|
| 0 | `HomePage` | node status, connection story, balances, quick actions |
| 1 | `WalletPage` | create/import, vault wallets, balances, history, secrets |
| 2 | `SendPage` | send form, fee selection, review, cold request/response |
| 3 | `InspectPage` | look up any public address |
| 4 | `SettingsPage` | one long page with 19 sections and jump chips |

Android starts on tab 1 (Wallet). Linux opens on the last saved tab. There is no
onboarding, no dedicated Activity tab, and no QR scanner route.

### 2.3 Platform split

Linux-specific work is guarded with `Platform.isLinux`:

- `memory_protection.dart` — no-op on Android.
- `posix_fs.dart` / descriptor-based atomic writes — Android uses the portable
  `dart:io` fallback.
- `tor_manager.dart` — managed Tor child process is Linux-only; Android uses
  Orbot through the external SOCKS5 settings.
- `Process.run('xdg-open' | 'zenity' | 'notify-send')` — Linux-only; several
  buttons call these unconditionally or fall back to copying text.
- `kdf.dart` native library candidates — Linux, macOS, Windows only.

Android-specific bridges:

- `platform_files.dart` uses a `MethodChannel` to the Android Storage Access
  Framework for backup/cold files.
- `MainActivity.kt` is a `FlutterFragmentActivity` (required by `local_auth`),
  adds `FLAG_SECURE` globally, and implements save/open document pickers.

---

## 3. Android build, manifest, and release audit

| ID | Severity | Finding | Evidence |
|---|---|---|---|
| A1 | High | The Gradle `release` build type uses the **debug signing config**. `flutter build apk --release` produces a debug-signed APK. Only `scripts/build-apk.sh` re-signs it with the approved key. | `android/app/build.gradle.kts:42` |
| A2 | High | R8 minification, resource shrinking, and obfuscation are all off. No `--obfuscate --split-debug-info` in the release build. | `build.gradle.kts:43-44`; `scripts/build-apk.sh` |
| A3 | Medium | `android-build.yml` uploads APKs but runs no Android unit/widget/instrumentation tests, no lint, and no emulator. The uploaded files are debug-signed by A1. | `.github/workflows/android-build.yml` |
| A4 | Medium | There is no Android release workflow with signer verification; release signing is local/manual. That is safe, but the process is not CI-attested. | `.github/workflows/`; `scripts/build-apk.sh` |
| A5 | Low | The Gradle wrapper JAR is not tracked in `git ls-files android`. A clean checkout depends on Flutter regenerating it. | `git ls-files android` |
| A6 | Low | No adaptive icon, no themed/monochrome icon, and no Android 12+ splash API. The launch screen is plain white/black. | `android/app/src/main/res/` |
| A7 | Info | `minSdk = 26`, `compileSdk = 36`, `targetSdk = flutter.targetSdkVersion`. API 26 covers the Huawei Y9 2019 (Android 8.1, API 27). | `android/app/build.gradle.kts` |
| A8 | Good | Only `INTERNET`, `USE_BIOMETRIC`, and `USE_FINGERPRINT` are declared. | `AndroidManifest.xml` |
| A9 | Good | `allowBackup="false"`, `fullBackupContent="false"`, `dataExtractionRules` excludes root, and `usesCleartextTraffic="false"`. | manifest + `res/xml/` |
| A10 | Good | Only `MainActivity` is exported (launcher). No deep links, no background services, no providers, no receivers. | manifest |
| A11 | Low | `network_security_config.xml` lists a few BSC hosts but does not declare explicit trust anchors. Global cleartext is already false, so this is defense-in-depth, not a hole. | `res/xml/network_security_config.xml` |
| A12 | Medium | No `filterTouchesWhenObscured`, no overlay detection, and no tapjacking check on confirm/sensitive buttons. | repo-wide search |
| A13 | Medium | No root/emulator/debugger/overlay/accessibility-service warnings. | repo-wide search |
| A14 | Medium | No `android:enableOnBackInvokedCallback`, no predictive-back handling. Back behavior is default Flutter. | manifest |
| A15 | Good | `FLAG_SECURE` is added in `MainActivity.onCreate`. It hides the app in recents and blocks screenshots/recording. | `MainActivity.kt:65` |

---

## 4. Security audit

### 4.1 Vault and KDF — the most important finding

| ID | Severity | Finding | Evidence |
|---|---|---|---|
| B1 | **Critical** | Android does **not** use the native Argon2 library. `lib/kdf.dart` only looks for native libraries on Linux, macOS, and Windows. The Android APK contains no `libargon2*.so`. `dargon2_flutter` is a dependency but is never initialized. The app therefore falls back to pure-Dart Argon2id at 64 MiB/t=3/p=4. | `lib/kdf.dart:101-118`; `unzip -l` of the 1.4.3 APK; no `DArgon2Flutter` call in `lib/` |
| B2 | High | The Android device secret uses `const FlutterSecureStorage()` with default options. The Keystore key is hardware-wrapped but **not** `setUserAuthenticationRequired(true)`, not StrongBox-preferred, and not invalidated on biometric enrollment. | `lib/storage.dart:1052`; `flutter_secure_storage` 11.2 Android options |
| B3 | High | `resetOnError` defaults to `true` in `flutter_secure_storage`. A transient Keystore/read error can erase the device secret, which makes the existing vault permanently unreadable. | dependency default; `storage.dart` |
| B4 | Medium | No record of whether TEE or StrongBox is used on a given phone. No attestation or diagnostics. | no code |
| B5 | Medium | The fixed 64 MiB/t=3/p=4 parameters have never been benchmarked on a low-end Android phone. With B1 this is a likely multi-second to multi-minute unlock. | no benchmark |
| B6 | Good | The vault envelope itself is strong and must be preserved: Argon2id 64 MiB/t=3/p=4, XChaCha20-Poly1305, double wrapper, authenticated header, atomic write, v1 read compatibility. | `lib/vault.dart`, `docs/CRYPTO.md` |

The B1 impact is not a cryptographic parameter downgrade. It is an
availability/UX failure: a 64 MiB pure-Dart KDF on a low-end phone can freeze
or take extremely long. Users then choose weaker passwords or disable the lock.
The fix is to wire the existing `dargon2_flutter` mobile implementation or an
equivalent native path, then measure it.

### 4.2 App lock, PIN, and biometrics

| ID | Severity | Finding | Evidence |
|---|---|---|---|
| C1 | High | Idle auto-lock does nothing when no PIN is configured: `_checkIdle` returns if `!appState.usePin`. Background lock also only runs when `usePin` is true. Without a PIN, the vault stays unlocked in memory in the background. | `lib/main.dart:73-104` |
| C2 | High | PIN minimum is 4 digits. There is no rejection of `1234`, `0000`, repeated or sequential PINs. | `settings_page.dart:2637` |
| C3 | High | No wipe-after-N-failures. Backoff exists, but the vault is never destroyed after repeated wrong PINs. | `lib/security.dart` |
| C4 | Medium | Biometrics are attempted automatically on the lock screen. `local_auth.authenticate` is called without `biometricOnly: true`, so device credential may be accepted. There is no explicit biometric toggle and no enrollment-invalidation handling. | `security.dart:40-45`; `main.dart:427` |
| C5 | Medium | The app PIN gates the UI, but the vault password is a separate secret. A 6-digit PIN does not derive the vault key. This is acceptable, but the UI and docs must say it plainly. | `security.dart`, `vault.dart` |
| C6 | Low | PIN field does not set `enableIMEPersonalizedLearning: false`. Other secret fields disable suggestions/autocorrect but not IME learning. | `main.dart:483`; repo-wide search |
| C7 | Good | PIN verification uses Argon2id and constant-time compare. Backoff is persisted and re-anchored. | `security.dart` |

### 4.3 Screen and confirmation protection

| ID | Severity | Finding | Evidence |
|---|---|---|---|
| D1 | Good | `FLAG_SECURE` is always on, so screenshots, screen recording, and the recents thumbnail are blocked. | `MainActivity.kt:65` |
| D2 | Medium | Because it is always on, users cannot screenshot a normal receipt or address either. Decide whether to keep always-on or make it per-screen. Always-on is safer but surprising. | `MainActivity.kt` |
| D3 | High | No tapjacking/overlay protection on confirm, send, reveal-secret, or erase buttons. | repo-wide search |
| D4 | Medium | No warning for rooted devices, emulators, debugger attachment, accessibility abuse, or overlay apps. | repo-wide search |
| D5 | Medium | No Play Integrity or equivalent. This is optional and would add a Google dependency; it must not become analytics. | no code |
| D6 | Good | Hold-to-confirm exists and works with touch and keyboard. It has a semantics label. | `widgets/hold_to_confirm.dart` |
| D7 | Medium | No haptic ramp on hold-to-confirm; no success/error haptics. | no code |

### 4.4 Clipboard, keyboard, memory

| ID | Severity | Finding | Evidence |
|---|---|---|---|
| E1 | Good | Seed entry uses a tap-based BIP-39 picker. The assembled phrase never reaches the keyboard. | `widgets/seed_picker.dart` |
| E2 | Good | Seed/private-key shaped text is blocked from the clipboard. Copied addresses clear after 30 s. | `screens/common.dart`, `security.dart` |
| E3 | Low | The master prompt asks for 60 s clipboard clear; current is 30 s. | `common.dart` |
| E4 | Medium | `enableIMEPersonalizedLearning: false` is missing on secret fields. | repo-wide search |
| E5 | Medium | Secrets are held in Dart `String` objects in several places. Dart cannot guarantee secure erasure. This must stay documented; it cannot be "fixed" with a claim. | `vault.dart`, `wallet_page.dart` |
| E6 | Good | No analytics, ads, tracking, remote config, or AI endpoint. | `test/data_boundary_test.dart`; `docs/NO_RUNTIME_ACCESS.md` |
| E7 | Medium | Android `memory_protection.dart` is a no-op. There is no equivalent of Linux `PR_SET_DUMPABLE` or core-dump blocking. | `lib/memory_protection.dart` |

### 4.5 Network and Tor

| ID | Severity | Finding | Evidence |
|---|---|---|---|
| F1 | Good | Single HTTP choke point; TLS validation then SPKI pinning; fail-closed proxy/Tor; chain-ID validation. | `lib/net/privacy_client.dart`, `rpc_service.dart` |
| F2 | Good | Android Tor uses external Orbot at `127.0.0.1:9050`, with no silent direct fallback. | `docs/ANDROID.md`, `privacy_client.dart` |
| F3 | Medium | Orbot is a separate app. If it is missing/off, the user must understand why the wallet fails. The current error text is technical. | `privacy_dialogs.dart` |
| F4 | Medium | No packet-capture/DNS-leak evidence on Android. The desktop evidence does not transfer. | no Android test |
| F5 | Low | `api.coingecko.com` and `api.ipify.org` are new runtime hosts. They are documented, but the Android network config does not list them explicitly. Global cleartext=false still applies. | `network_security_config.xml`, `price_service.dart`, `settings_page.dart` |
| F6 | Info | Price requests contain only fixed coin IDs. IP echo contains no wallet data. Both are documented. | `price_service.dart`, `docs/DATA_CONTROL.md` |

### 4.6 Release identity and signing

| ID | Severity | Finding | Evidence |
|---|---|---|---|
| G1 | High | The incident record and `release/manifest.json` still say rotation is not verified, while 1.4.0–1.4.2 APKs are public and signed by `db1286…`. The project must reconcile this before claiming a verified release identity. | `docs/security/INCIDENT_2026-11-KEYSTORE.md`; `release/manifest.json`; GitHub assets |
| G2 | Good | `build-apk.sh` requires an approved signer, an owner approval flag, a populated denylist, and verifies the certificate before emitting an APK. | `scripts/build-apk.sh`, `verify-android-signer.sh` |
| G3 | Medium | `android-build.yml` artifacts are debug-signed (A1) and could be mistaken for release files. Rename them or make the CI build unsigned and clearly labeled. | `android-build.yml` |

---

## 5. Screen and flow audit

### 5.1 Home

Current order: node card → connection story → balance card → send/receive →
notice. The first thing a new user sees is network plumbing, not money.

Missing for the "five-year-old" test:

- no huge total balance as the first element
- no fiat value on the hero (only rows)
- only Send and Receive; no Scan
- no pull-to-refresh
- no testnet warning badge
- no empty state illustration
- no recent activity
- no onboarding

The balance card is also where the only "total" is shown, but it is a long card
of rows and a nonce/block footer.

### 5.2 Wallet

Current: locked card, or a very large card with wallet label, address, save
button, Send/Receive/Lock, balances, token hide buttons, secret reveal, rename,
profile save, vault accounts, history, and Android "Recent activity".

Problems:

- mixes wallet management, secrets, balances, and activity in one scroll
- "Show recovery phrase / key" lives in a popup menu next to balances
- the Android dashboard is better but still includes a Save-to-vault button
  whose disabled state is the only feedback
- no clear separation between "my wallet" and "saved wallets"

### 5.3 Send

Current: one long form with asset dropdown, recipient, amount, available
balance, fee panel, review, journey stages, cold request/response, and a large
technical explanation.

Missing:

- no wizard steps
- no QR scan button
- no contacts/address book picker
- no "Max" button
- no human summary at the top of review ("You send 10 USDT to 0x12…ab34 on BNB
  Chain, fee about …")
- no fiat conversion line next to the amount
- no first-time-recipient visual warning beyond text
- no large-amount warning beyond policy
- hold-to-confirm exists, but no biometric/PIN step after it
- no haptics

### 5.4 Inspect

A whole tab for public address lookup. This is a power-user tool. It occupies
one of five prime navigation slots. In the new model it belongs under Advanced,
and the tab slot should go to Scan or Activity.

### 5.5 Settings

One 3,243-line page with 19 sections and a row of jump chips. It includes
Network, Nodes, Tokens, History, Storage, Spending safety, App lock, Wallet
mode, Node selection, Appearance, Privacy, Auto-lock, Erase, About, and more.

Problems:

- not grouped into plain categories
- exposes desktop-only controls (open data folder via `xdg-open`, zenity file
  picker, absolute vault path)
- technical prose in primary settings
- no "Contacts" group
- no "Permissions/approvals" group
- no "Backup check" status
- no root/overlay warning

### 5.6 Onboarding

There is no welcome flow. A first-time user lands on the Wallet tab and must
open a complex "Create wallet" dialog with wallet type, derivation path,
passphrase, and optional private-key paste. The recovery phrase is shown, but
there is no guided PIN → backup → quiz → success sequence and no persistent
"backup not verified" reminder.

### 5.7 Activity and history

Local receipts are encrypted and saved. Pending transactions are stored as
public JSON. But:

- there is no dedicated Activity screen
- explorer history requires a BscScan API key
- received transfers are not stored locally
- no status chips for Pending/Done/Failed/Unknown
- no block-explorer deep link that opens the Android browser (the link is
  copied instead)
- no local Android notification on confirmation

### 5.8 Cold signing

The protocol and verification are strong. Android gaps:

- no camera QR scanner
- no animated multi-frame QR
- no share sheet
- file/paste only
- no offline build flavor without `INTERNET`
- no physical two-device test

---

## 6. Platform assumptions that break or are untested on Android

| Assumption / call | Android reality | Status |
|---|---|---|
| `Process.run('xdg-open', …)` | No `xdg-open`; call fails or is ignored. Used for explorer links, data folder, trusted sources. | **Broken** |
| `Process.run('zenity', …)` | No zenity; backup path picker falls back to typed absolute path if not handled by `PlatformFiles` branch. | **Desktop-only** |
| `Process.run('notify-send', …)` | No notify-send; Android has no local confirmation notification. | **Missing** |
| `tor_manager.dart` managed Tor | Linux child process only; Android uses Orbot SOCKS. | **Different path, documented** |
| `memory_protection.dart` | No-op; no dumpable/core-limit equivalent. | **Not implemented** |
| `posix_fs.dart` descriptor writes | Portable fallback; no `O_NOFOLLOW`/`renameat` hardening on Android. | **Weaker fallback** |
| `kdf.dart` native loader | No Android candidate; pure-Dart fallback. | **Critical gap** |
| `FlutterSecureStorage()` | Works, but not user-auth-bound and `resetOnError=true`. | **Needs hardening** |
| `local_auth` | Works via `FlutterFragmentActivity`; default auth policy is not biometric-only. | **Needs policy** |
| Absolute vault path / "Move vault" | Android app-private paths and SAF make this confusing/unusable. | **Desktop-shaped** |
| `qr_flutter` | Displays QR; no scanner. | **Partial** |
| `url_launcher` | Present but not used for Android explorer/source links. | **Unused** |
| `flutter_secure_storage` biometric options | Available in 11.2, not used. | **Available** |
| Window sizing / keyboard shortcuts | No window manager; hold-to-confirm keyboard path is irrelevant but harmless. | **Desktop residue** |
| `SharedPreferences` | Works; public config only. | **Good** |
| `path_provider` app support dir | Works; app-private. | **Good** |
| File picker `MethodChannel` | Works; one pending operation at a time. | **Good** |
| `dargon2_flutter_mobile` | Dependency present but not initialized and not bundled. | **Unused** |

---

## 7. Test and CI audit

Existing strengths:

- 61 test files / 350 declarations (including one integration file).
- 60/60 non-integration files passed locally on the 1.4.3 line.
- KDF production-parameter test, vault tamper/migration tests, cold protocol
  tests, ethers.js oracle, Anvil integration, mutation checks, secret scan,
  dependency audit, license inventory, SBOM, release identity tests.
- `data_boundary_test.dart` proves no telemetry/AI SDK and no network in key
  modules.

Gaps for Android:

| ID | Severity | Gap |
|---|---|---|
| H1 | High | No Android instrumentation/integration tests (create, backup quiz, lock, unlock, receive, send on testnet 97, history). |
| H2 | High | No biometric/Keystore test on emulator with enrolled biometrics. |
| H3 | High | No test that `FLAG_SECURE`, `allowBackup=false`, cleartext=false, and permissions are correct in the built APK. |
| H4 | High | No physical Android device run of this release. The owner's real transfers are recorded separately, but they do not cover the new UI or security changes. |
| H5 | Medium | No golden screenshots for light/dark, 200% text, phone/tablet. |
| H6 | Medium | No performance test: cold start, memory, KDF time on a low-end profile. |
| H7 | Medium | No Android lint job; `android/**` is excluded from the Dart analyzer. |
| H8 | Medium | No test that Tor/proxy fails closed on Android with Orbot off. |
| H9 | Medium | No test that the app does not write secrets to logs/crash output on Android. |
| H10 | Medium | No QR scanner/cold-frame test. |
| H11 | Low | No local notification test. |

CI:

- `verify.yml` is strong for Dart/Linux.
- `android-build.yml` builds two APKs and checks ABIs/branding, but does not
  test behavior, lint, sign, or verify a signer.
- `release-build.yml` covers Linux only.
- `package-smoke.yml` covers Linux only.

---

## 8. Documentation and version inconsistencies

| ID | Severity | Inconsistency |
|---|---|---|
| I1 | High | `pubspec.yaml` is `1.4.3+12`; `release/manifest.json` and `docs/GENERATED_STATUS.md` say `1.4.2+11`; `IMPLEMENTATION_STATUS.md` says `1.4.2+11`; `SECURITY_SCORECARD.md` says `1.4.2+11`; README says `1.4.3+12`. |
| I2 | High | `docs/security/INCIDENT_2026-11-KEYSTORE.md` says rotation is `NOT DONE`, denylist empty, Android release `BLOCKED`. The denylist is populated and APKs are published. This must be reconciled with owner confirmation. |
| I3 | High | `release/manifest.json` says `rotationVerified: false` and `incidentStatus: OPEN — ROTATION NOT VERIFIED`, while public APKs exist. |
| I4 | Medium | `AGENTS.md` still describes a Linux-first product with Android as future; its blocker table repeats the stale key-rotation status. |
| I5 | Medium | `docs/THREAT_MODEL.md` says transaction history is "Not persisted at all"; encrypted receipts and pending transactions are persisted. |
| I6 | Medium | `docs/ANDROID.md` says "same languages" and "share it" for cold payloads; the app is English-only and has no Android share sheet. |
| I7 | Medium | `docs/CRYPTO.md` correctly says Android is Keystore-backed but does not state that the current key is not user-auth-bound or StrongBox-preferred. |
| I8 | Medium | `README.md` still opens with "desktop wallet for Linux" and "not a phone-only app", while the Android APKs are a first-class product. |
| I9 | Low | `docs/COLD_WALLET.md` says camera QR is not implemented and recommends file/paste, which is accurate for Linux but should say Android too. |

These are not cosmetic. The release gate and the incident record are part of the
security story. They must be true before the next release is called verified.

---

## 9. What must be preserved (do not weaken)

1. Argon2id 64 MiB/t=3/p=4 and XChaCha20-Poly1305 double-wrapped vault.
2. Authenticated vault header, fixed parameter policy, atomic write, v1
   migration.
3. Device-bound layer and fail-closed behavior when the device secret is
   missing.
4. Exact transaction review: chain, nonce, fees, max cost, recipient, value,
   calldata.
5. Address-poisoning checks, allowlist, per-transaction limit, freeze signing.
6. Hold-to-confirm and full address display.
7. Cold/offline signing field-by-field verification, expiry, replay protection.
8. TLS validation then SPKI pinning; SOCKS5h; fail-closed Tor/proxy.
9. Chain-ID validation and untrusted-node warnings.
10. Encrypted receipts and activity log; no plaintext secrets.
11. No analytics, ads, tracking, accounts, or remote control.
12. Signer approval/denylist gate and signed release evidence.
13. Linux build and existing desktop behavior, unless the owner explicitly
    approves dropping them.
14. The current logo and icon.

---

## 10. Top findings, in priority order

1. **Android runs the pure-Dart KDF** because the native mobile Argon2 plugin is
   not initialized or bundled. This must be fixed and measured before calling
   the Android app production-ready.
2. **The vault can stay unlocked in the background when no PIN is set.** Auto-
   lock and background lock are coupled to PIN enablement.
3. **The device secret is not user-auth-bound, not StrongBox-preferred, and
   `resetOnError` can orphan the vault.**
4. **The UI is still desktop-shaped.** Home leads with node/story cards; Settings
   is a 19-section scroll; onboarding, Scan, Activity, Contacts, and approvals
   are missing.
5. **No Android behavior evidence.** No emulator/instrumentation/lint/device
   tests, no physical run of the new UI.
6. **Documentation and release identity conflict.** The incident record says the
   opposite of the published APK state.
7. **No tapjacking/overlay/root/emulator warnings.**
8. **Localization is English-only and 318 UI strings are hardcoded**, while the
   new brief asks for 12+ languages. This is a product decision, not a bug.
9. **No QR scanner, animated cold QR, token approvals, or Android explorer
   link handler.**
10. **R8/obfuscation and release signing are not enforced in CI.**

---

## 11. Explicitly not tested

- physical Huawei Y9 2019 (Android 8.1) install and run
- StrongBox/TEE behavior
- biometric enroll/invalidate/authenticate
- TalkBack, switch access, 200% text on device
- camera permission and QR scanning (not implemented)
- Orbot fail-closed behavior on Android
- Android file picker save/open edge cases
- Android cold-start time, memory, and KDF duration
- Android app backup/extraction behavior on a real device
- Play Integrity (not implemented)
- signed release install over 1.4.2 on a real phone

---

## 12. Decisions needed before Phase B

These are conflicts or product choices that must be answered by the owner. The
plan below states a recommended default for each, but Phase B should not start
until these are confirmed.

| ID | Decision | Recommended default |
|---|---|---|
| D1 | Languages: keep English-only (earlier instruction) or implement the 12+ language structure from the new brief? | Keep English-only for the first hardening release; add localization-ready ARB extraction without shipping machine translations yet. |
| D2 | Fiat prices: automatic public CoinGecko lookup (current) or opt-in/off by default (new brief)? | Default **off** on fresh installs, with a clear "Show USD values" toggle; the request contains only fixed coin IDs. |
| D3 | Add `mobile_scanner` (camera/QR) and a share plugin? | Yes for QR scanning and share, after license/advisory review; request camera permission only at use. |
| D4 | Embedded Tor vs Orbot on Android? | Keep Orbot for now (no new network service); mark embedded Tor as future work. |
| D5 | State management: keep `ChangeNotifier` or migrate to Riverpod/Bloc? | Keep `ChangeNotifier` for the hardening release; split the god object into feature controllers. A full state-management migration is a separate PR. |
| D6 | PIN migration: move from 4 to 6 digits and add wipe-after-N? | Yes, with a forced upgrade path for existing PINs and a clear warning. |
| D7 | `FLAG_SECURE`: keep always-on or per-screen? | Keep always-on for the first release; it is safer. Revisit if users need receipt screenshots. |
| D8 | Play Integrity: add Google dependency or skip? | Skip. It conflicts with the no-Google/no-analytics promise and is not required for a sideloaded wallet. |
| D9 | Linux: keep full parity or freeze Linux during the Android rewrite? | Keep Linux building and working; use adaptive layouts, not a fork. |

---

## 13. Proposed next step

Write `docs/ANDROID_PLAN.md` (done in the same phase), then wait for the
owner's answers to D1–D9 and explicit approval to start Phase B. Phase B should
begin with the native KDF, lock defaults, and Keystore hardening, because those
are the highest-risk gaps and they do not depend on the UI redesign.
