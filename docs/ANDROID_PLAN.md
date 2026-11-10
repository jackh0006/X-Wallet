# Android Plan — X Wallet

**Date:** 2026-11-10
**Input:** `docs/ANDROID_AUDIT.md` (audit baseline `9eac76d`)
**Status:** Phase A plan, followed by the 1.5.0 implementation noted in the
addendum. The remaining items are still proposals and must not be treated as
shipped security claims.

---

## 1. Goal

Make X Wallet the simplest safe self-custodial wallet on Android for a
first-time user, while keeping the existing security invariants and the Linux
build working.

The target user can:

1. open the app and understand the main screen without help;
2. receive funds;
3. see the balance;
4. send a small amount through a guided, reviewed flow;
5. recover the wallet from paper if the phone is lost.

Security stays strong by default and becomes visible only when it matters.
Simplicity must never weaken the vault, the review, the confirmation, or the
network policy.

## 2. Non-goals for this pass

- No new blockchain beyond BNB Smart Chain mainnet (56) and testnet (97).
- No hardware-wallet support claim.
- No independent audit claim.
- No custody, account, cloud sync, analytics, ads, or remote configuration.
- No production keystore generation, rotation, or secret handling by the coding
  agent.
- No claim that a screen works on a real phone until it has been run there.

## 3. Target architecture

```
lib/
  core/                 pure Dart, no Flutter widgets, no dart:io UI calls
    vault/              envelope, KDF, device-secret abstraction
    wallet/             BIP-39/44, keys, addresses, send intent
    tx/                 fee engine, lifecycle, cold codec/protocol
    policy/             spending policy, address checks
    net/                RPC contracts, URL policy, privacy config
    receipts/           receipt model and store interface
  platform/             platform bindings behind interfaces
    android/            Keystore, biometrics, FLAG_SECURE, file picker, links
    linux/              libsecret, POSIX FS, managed Tor, notifications
    shared/             secure storage, preferences, path provider
  ui/
    theme/              design tokens: color, type, spacing, radius, motion
    widgets/            PrimaryButton, HoldToConfirm, AmountField, AssetTile,
                        StatusChip, SecureScreen, PinPad, SeedWordGrid, ...
    screens/            onboarding, home, receive, send, activity, settings,
                        permissions, contacts, advanced
    state/              feature controllers
  app.dart              root app and navigation
```

Rules:

- `core/` remains testable in plain Dart and keeps all existing tests passing.
- UI never constructs raw HTTP, file paths, or Keystore calls.
- `platform/` exposes narrow interfaces; Android and Linux implementations are
  separate.
- No business logic in widgets.
- Keep `ChangeNotifier` for this release unless the owner chooses Riverpod in
  D5; split `app_state.dart` into feature controllers either way.

## 4. Phase B — Android security foundation

Do this before the UI rewrite. Each item has an acceptance criterion.

### B1. Native Argon2id on Android (critical)

- Initialize the existing `dargon2_flutter` mobile implementation, or use the
  bundled reference library through `dargon2_core`, at app startup.
- Confirm the release APK contains the native Argon2 library.
- Keep 64 MiB / t=3 / p=4. Do not lower parameters.
- Measure create/unlock time on a low-end Android profile and a real device.
- If a device cannot complete the KDF safely, fail closed with a clear message;
  do not silently fall back to weaker parameters.

**Acceptance:** APK contains the native library; a production-parameter vault
round-trip completes on Android; measured time recorded; no pure-Dart fallback
in the normal release path.

### B2. Keystore-bound device secret

- Use `AndroidOptions.biometric` or equivalent only if it preserves the current
  envelope and migration path.
- Prefer StrongBox when available, fall back to TEE, and record which was used
  in a non-secret diagnostic.
- Set `setUserAuthenticationRequired(true)` only for the biometric-unlock path.
- Ensure a new biometric enrollment invalidates the protected key, with a clear
  recovery path.
- Replace `resetOnError=true` with fail-closed behavior that never silently
  erases the only device factor. A Keystore error must not orphan the vault.
- Keep a migration path for existing `device_secret_v2` values.

**Acceptance:** tests prove wrong device, missing key, and reset error fail
closed; existing vaults still open after upgrade; biometric invalidation is
detected and explained.

### B3. Lock and lifecycle

- Lock the vault on background **regardless of PIN configuration**.
- Idle lock must always work; PIN only gates the unlock UI.
- Default: lock on background, 60 s idle.
- Add a clear "Lock now" action on Home and Settings.
- Keep manual lock behavior.

**Acceptance:** widget/lifecycle test proves keys are cleared after background
and after idle without a PIN; no signing is possible while locked.

### B4. PIN and biometrics

- Minimum 6 digits; reject repeated (`000000`), sequential (`123456`), and
  trivial PINs.
- Optional biometrics: `BIOMETRIC_STRONG` only, explicit toggle, no automatic
  prompt on every launch.
- Persist failed attempts; exponential backoff stays.
- Optional wipe-after-N failures (default on, user-configurable, clear warning).
- Migrate existing 4-digit PINs with a forced "set a new 6-digit PIN" step.
- Add `enableIMEPersonalizedLearning: false` to every secret field.
- Clipboard clear at 60 s for addresses; never copy seed/key.

**Acceptance:** tests for weak PIN rejection, backoff persistence, wipe-after-N,
biometric-only policy, and migration.

### B5. Screen and tapjacking protection

- Keep `FLAG_SECURE` on secret and signing screens; decide D7 for all screens.
- Add `filterTouchesWhenObscured` to confirm, reveal-secret, erase, and send
  buttons.
- Add a plain warning when an overlay or accessibility service is detected if a
  safe platform API is available; do not silently block.
- Add haptic feedback on hold start, success, and error.

**Acceptance:** a test harness proves obscured touches are rejected; the APK
contains the attribute; haptics are optional.

### B6. Manifest, backup, and network hardening

- Keep `allowBackup=false`, `dataExtractionRules`, `usesCleartextTraffic=false`.
- Add explicit trust anchors (system only) in `network_security_config.xml`.
- Keep only `INTERNET` unless camera is added for QR; request camera at use.
- Keep only `MainActivity` exported.
- Add Android lint with security-relevant warnings as errors.
- Add a test that reads the built manifest and asserts these properties.

**Acceptance:** APK/manifest tests pass; no new permissions without a documented
reason.

### B7. Release build hardening

- Add a release signing config only when the owner's keystore is supplied; never
  commit it.
- Enable R8 minify + resource shrink and `--obfuscate --split-debug-info`.
- Make CI build **unsigned** APKs and label them clearly; keep signed builds on
  the owner's machine.
- Keep the signer allowlist/denylist gate.
- Update `docs/ANDROID_RELEASE.md` with the current verified signer, the
  historical denylist, and the rotation evidence. Reconcile the incident record
  with the owner's confirmation.
- Do not touch or generate the production keystore.

**Acceptance:** release build is reproducibly signed by the owner; CI artifacts
are unsigned and clearly named; signer verification passes; incident docs match
reality.

### B8. Android environment checks

- Warn (not block) on rooted device, emulator, debugger, and overlay risk where
  a stable API exists.
- Do not add Play Integrity unless the owner chooses D8.
- Never send a device fingerprint anywhere.

**Acceptance:** warnings are local-only and documented.

### B9. Tor, links, notifications

- Keep Orbot SOCKS5 with fail-closed behavior.
- Replace Android `xdg-open` fallbacks with `url_launcher` for explorer/source
  links.
- Add a local Android notification for confirmation only if it contains no
  amounts or addresses; do not add a push service.
- Remove or hide desktop-only storage controls on Android.

**Acceptance:** links open in the system browser; confirmation notification is
local and privacy-preserving; Android Settings has no unusable path controls.

## 5. Phase C — beginner-simple UX

### 5.1 Design system

Create `lib/ui/theme/` with:

- color tokens for light/dark/high-contrast
- type scale (caption, body, title, display) with 200% scale rules
- spacing scale (4/8/12/16/24/32)
- radius tokens (12/16/24)
- elevation/shadow tokens
- motion durations (150–250 ms)
- one accent color; calm neutral background

Create `lib/ui/widgets/`:

- `PrimaryButton`, `SecondaryButton`, `DangerButton`
- `HoldToConfirmButton` (touch + haptics; keep keyboard support on desktop)
- `AmountField` with Max and fiat line
- `AddressField` with paste/scan/contacts
- `AssetTile`, `StatusChip`, `SecureScreen`
- `InfoBanner`, `EmptyState`, `ErrorState`
- `PinPad` (large keys, optional shuffle, no key sounds)
- `SeedWordGrid`
- `StepHeader` for wizards

Keep the current logo and icon. Add adaptive, themed/monochrome, and splash
variants derived from the same artwork.

### 5.2 Screens and flows

1. **Welcome** (max 3 slides, skippable)
   - "Your money. Only you hold the keys."
   - Create new wallet / I already have a wallet.
2. **Create wallet**
   - set 6-digit PIN
   - optional biometrics
   - show secret words in groups, `FLAG_SECURE`, paper warning
   - quiz at 3 random positions
   - success
   - "Back up later" with a persistent reminder and a soft warning above a
     small amount
3. **Import wallet**
   - paste/type with per-word validation and in-app BIP-39 suggestions
   - 12/24 words; private key behind Advanced
   - show resulting address and confirm
4. **Home**
   - huge total balance with honest "price unavailable" state
   - fiat off by default (D2)
   - three large actions: Send / Receive / Scan
   - asset list with logos and USD only if enabled
   - recent activity preview
   - pull-to-refresh
   - testnet badge in warning color
5. **Receive**
   - large QR, short address, copy/share
   - "Only send BNB Smart Chain assets to this address"
6. **Send wizard**
   - asset → address (scan/paste/contacts) → amount (Max, fiat) → review →
     confirm
   - review summary in plain words on top, full fields under "Details"
   - keep address-poisoning, first-time, large-amount, allowlist, limit,
     wrong-chain, uncertain-broadcast controls
   - hold-to-confirm + biometric/PIN
   - success screen with status
7. **Scan**
   - camera permission at use
   - QR for addresses and cold frames
   - clear denied state and manual paste fallback
8. **Activity**
   - encrypted local history, filter chips
   - status: Pending / Done / Failed / Unknown
   - detail page with explorer link opening the system browser after a warning
9. **Settings** (grouped, plain)
   - Security: PIN, biometrics, auto-lock, wipe-after-N, backup check
   - Network: default/custom RPC, proxy, Orbot
   - Assets: tokens, hidden tokens
   - Contacts
   - Advanced: cold wallet, limits, logs, export
   - About
   - Erase all data (type-to-confirm)
10. **Permissions**
    - list active ERC-20 allowances
    - flag unlimited approvals in red
    - one-tap Revoke through the normal reviewed send flow
11. **Contacts**
    - save name + address + chain
    - address-poisoning check against contacts
12. **Cold signing**
    - animated multi-frame QR
    - file/paste fallback
    - optional offline build flavor without `INTERNET` (owner decision)

### 5.3 Copy and visual rules

- No jargon on the main path. Use "network fee", "secret words", "recovery
  words".
- Every error says what happened, whether money is safe, and what to do next.
- Icons + text + color; never color alone.
- Minimum 48 dp targets; primary actions 56 dp.
- Bottom-reachable primary actions on phones.
- Skeleton loaders; no blank screens.
- Test at 200% text, landscape, tablet, and 320 dp width.

### 5.4 What stays on Linux

Keep the desktop build working. Use responsive layouts rather than a separate
fork. Desktop keeps keyboard shortcuts, managed Tor, libsecret, POSIX writes,
and notifications behind `platform/linux`.

## 6. Phase D — architecture and quality

1. Extract `lib/core/` from the existing files without behavior changes.
2. Introduce `lib/platform/` interfaces for secure storage, files, biometrics,
   links, notifications, and Tor.
3. Split `app_state.dart` into feature controllers: vault, balances, send,
   settings, cold wallet.
4. Keep `ChangeNotifier` for this release; a Riverpod/Bloc migration is a
   separate decision (D5).
5. Tighten `analysis_options.yaml` (strict casts, unawaited futures, unnecessary
   nullable, etc.) without breaking existing code.
6. Add Android lint to CI with security-relevant checks as errors.
7. Every new dependency: license, advisory, SBOM, and owner approval. No
   analytics/ads/tracking/remote config.

## 7. Phase E — testing and evidence

### 7.1 Required tests

- All existing Dart/Flutter tests stay green.
- New unit tests: PIN rules, wipe-after-N, lock lifecycle, Keystore failure
  behavior, native KDF availability, address/contacts checks.
- Widget tests: onboarding, home, receive, send wizard, review, activity,
  settings groups, permissions, 200% text, 320 dp width.
- Golden tests: every screen in light/dark, normal/200%, phone/tablet.
- Android instrumentation/emulator:
  - create → backup quiz → lock → unlock
  - biometric enrollment/invalidation (emulator)
  - receive
  - send on testnet 97
  - history persistence
  - FLAG_SECURE and recents thumbnail
  - manifest assertions: allowBackup=false, cleartext=false, permissions,
    exported components
  - Orbot-off fail-closed (mock SOCKS)
- Performance: cold start, memory, KDF time on a low-end profile.
- Manual device checklist on the Huawei Y9 2019; mark anything not run as
  `NOT TESTED`.

### 7.2 CI

- Keep `verify.yml` as the Dart/Linux gate.
- Add an Android job that:
  - builds unsigned APKs
  - runs Android lint
  - runs unit/widget tests
  - runs emulator instrumentation tests
  - uploads test reports and golden artifacts
- Keep signed release builds local and owner-controlled.
- Keep the signer allowlist/denylist verification.

### 7.3 Evidence

- Record commands, exit codes, logs, and commit hashes with
  `scripts/record_check.py`.
- Do not call anything verified until the release gate says `VERIFIED` for the
  exact commit and artifact.
- Mark physical-device, StrongBox, TalkBack, camera, and Orbot results as
  `NOT TESTED` until actually run.

## 8. Phase F — documentation and honesty

Update:

- `README.md` — Android-first install, screenshots, simple quick start.
- `CHANGELOG.md` — user-facing changes.
- `IMPLEMENTATION_STATUS.md` — one version, one commit, real status.
- `docs/SECURITY_SCORECARD.md` — re-score with evidence.
- `docs/THREAT_MODEL.md` — Android threats: overlays, accessibility abuse,
  screen capture, backup extraction, rooted devices, clipboard sniffers,
  malicious keyboards, intent spoofing, fake APKs.
- `docs/CRYPTO.md` — Keystore layer, user-auth binding, StrongBox/TEE.
- `docs/ANDROID.md` — real flows, no false language/share claims.
- `docs/COLD_WALLET.md` — Android QR/file/paste and limits.
- `docs/security/INCIDENT_2026-11-KEYSTORE.md` — reconcile with the actual
  signer and denylist, with owner confirmation.
- `docs/ANDROID_RELEASE.md` — new file: rotation, denylist, signed build,
  Play App Signing, upgrade behavior.
- `AGENTS.md` — update the mission, blocker table, and Android status.
- `release/manifest.json`, `release/evidence.json`, SBOM, test inventory.

Do not claim an independent audit, "unhackable", "100% secure", or hardware-
wallet support.

## 9. Decisions required (same as audit §12)

| ID | Decision | Recommended |
|---|---|---|
| D1 | English-only vs 12+ languages | English-only first; extract strings to ARB now, ship translations later. |
| D2 | Fiat prices automatic vs opt-in | Opt-in, off by default; fixed coin IDs only. |
| D3 | Add QR scanner/share plugins | Yes, after review; camera at use. |
| D4 | Embedded Tor vs Orbot | Orbot for now. |
| D5 | ChangeNotifier vs Riverpod/Bloc | Keep ChangeNotifier; split controllers. |
| D6 | 6-digit PIN + wipe-after-N + migration | Yes. |
| D7 | FLAG_SECURE all screens vs secrets only | Keep all screens for now. |
| D8 | Play Integrity | Skip. |
| D9 | Linux parity | Keep Linux working. |

## 10. Proposed commit sequence

1. `docs: add Android audit and plan` (this phase, no code)
2. `security(android): native Argon2 + KDF measurement`
3. `security(android): Keystore-bound device secret and migration`
4. `security(android): lock lifecycle, PIN policy, wipe-after-N`
5. `security(android): manifest/lint/FLAG_SECURE/tapjacking hardening`
6. `build(android): R8/obfuscation, unsigned CI, release signer docs`
7. `refactor: extract core/platform/ui layers`
8. `feat(ui): design tokens and component library`
9. `feat(ui): onboarding + create/import`
10. `feat(ui): home + receive + activity`
11. `feat(ui): send wizard + review + confirm`
12. `feat(ui): settings groups + contacts + permissions`
13. `feat(android): QR scan + cold QR + links/notifications`
14. `test(android): instrumentation, goldens, manifest, performance`
15. `docs: release evidence, scorecard, version reconciliation`

Each commit must keep `flutter analyze` and the Dart suite green. Android tests
must pass before the Android-specific commit is called complete.

## 11. Risks and mitigations

| Risk | Mitigation |
|---|---|
| KDF too slow on low-end phones | Native Argon2 first; measure; fail closed with clear message; never lower parameters silently. |
| Keystore changes orphan existing vaults | Migration path; keep old device secret readable; fail closed, never reset on error. |
| UI rewrite breaks security review | Keep review widgets and invariants; golden + widget tests for every sensitive screen. |
| Android rewrite breaks Linux | Platform interfaces; keep Linux CI and smoke tests. |
| Localization work explodes scope | Extract strings first; translations after owner decision. |
| New dependencies add supply-chain risk | Pin, audit, license-check, SBOM, owner approval. |
| Signing/documentation confusion | Reconcile incident record with owner; one version, one commit, one signer. |
| Physical device unavailable | Mark NOT TESTED; do not claim device support from compile/tests. |

## 12. Definition of done for the Android-first release

- Native KDF measured on Android; no pure-Dart fallback in release.
- Vault keys are cleared on background/idle even without a PIN.
- Keystore secret is user-auth-bound where chosen; migration tested.
- 6-digit PIN, weak-PIN rejection, backoff, optional wipe-after-N.
- FLAG_SECURE and tapjacking protection verified by tests.
- Beginner onboarding, Home, Receive, Send wizard, Activity, Scan, Settings,
  Contacts, Permissions implemented.
- Android emulator/instrumentation tests and lint pass in CI.
- At least one physical Android device run recorded, or the feature is marked
  NOT TESTED.
- Manifest/backup/network assertions pass on the built APK.
- All docs/version numbers agree; incident record matches reality.
- Release gate `VERIFIED` for the exact tagged commit and signed artifacts.
- No claim of independent audit or absolute security.

---

## Addendum — what 1.5.0 actually shipped

| Phase | Item | State |
|---|---|---|
| B1 | Native Android Argon2 | **DONE (build-verified; device timing NOT TESTED)** |
| B3 | Lock on background/idle without PIN | **DONE** |
| B4 | 6-digit PIN, weak-PIN rejection, wipe-after-N | **DONE** |
| B4 | Biometric strong-only | **DONE** |
| B2/B3 | Fail-closed secure storage | **PARTIAL** (no reset-on-error; user-auth-bound key still future) |
| B5 | FLAG_SECURE + obscured-touch rejection | **DONE (view-level)** |
| B6 | System-only trust anchors, host list | **DONE** |
| B7 | R8, shrinking, obfuscation, CI KDF assertion | **DONE** |
| C | Blue theme, Home hero, Activity tab, USD toggle, Android links | **DONE** |
| C | Onboarding wizard, Send wizard, Scan, Contacts, Approvals | **NOT DONE** |
| D | Core/platform/UI split | **NOT DONE** (deferred; current files remain feature-first) |
| E | Android emulator/instrumentation/device tests | **NOT DONE** |
| F | Version/docs reconciliation | **PARTIAL** — 1.5.0 documented; incident owner confirmation still open |

The remaining items are not silently claimed as complete. They need separate
work and, for device behavior, a real phone.
