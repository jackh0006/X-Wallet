# CHANGELOG.md

All notable changes to this wallet. Dates in 2026; releases identify their
supported artifacts explicitly.

## 1.5.5+17 — hardening and verifiable release

- `SendIntent.verify` compares the reviewed nonce and sender with the exact
  transaction object before signing.
- `WalletCore.computeFingerprint` covers the chain and every paired address;
  a substituted address changes the fingerprint.
- Erase-all includes legacy Linux application-data directories and their
  plaintext secret.
- Android `MainActivity` caps imported files at 8 MiB.
- `privacy_client` rejects tracking/credential/cookie/framing headers and
  CR/LF or oversized values.
- `release-gate.py --require-source`, `release-verify.yml` and
  `verify-release-assets.sh` make the published assets re-checkable.
- Version `1.5.5+17`; regression tests for nonce/sender and fingerprint.

## 1.4.0+9 — Android release, same wallet everywhere

- **Android arm64 and universal APKs** with the same logo, label, colors,
  languages, vault, tokens, spending controls, and cold-signing protocol as
  Linux.
- **Android identity aligned:** `com.jackh0006.xwallet`, X Wallet label,
  regenerated launcher icons, biometric `FlutterFragmentActivity`, and
  `USE_BIOMETRIC`.
- **Android-specific correctness:** Android Keystore device secret, app-sandbox
  storage, Storage Access Framework file picker for backups and cold payloads,
  screenshot blocking, no broad storage permission.
- **Tor on Android via Orbot:** external SOCKS on 127.0.0.1:9050, fail closed,
  with a plain-language guide.
- **Linux application name fixed to X Wallet.**
- **New Android release signer** generated outside the repository; the
  historical compromised signer is denylisted.
- **Token display improvements:** canonical BSC names and symbols, BNB · BSC,
  and an unverified warning for lookalike contracts.

## 1.3.1+8 — vault unlock and About version fix

- **Vault unlock root cause fixed:** a private key stored with an insignificant
  leading `00` byte (66 hex characters) decrypted correctly but then failed
  account parsing, and the UI reported it as a wrong password. Vault keys are
  now normalized on read and save; the exact failing vault unlocks.
- **Precise vault errors:** a decryption failure and an invalid account record
  are no longer both shown as "wrong password".
- **About panel fixed:** the version is now 1.3.1, read from a single
  `lib/app_version.dart` source and checked against `pubspec.yaml`.
- Regression tests cover the leading-zero key, normalization, and the real
  vault round-trip.

## 1.3.0+7 — multi-wallet vault, any password, default assets

- **Multiple wallets in one encrypted vault:** add, switch, rename, and remove
  wallets from the Wallet manager. One vault password protects every account.
- **Unlock fix:** the pre-1.2 Linux application-support directory is migrated
  automatically, so a vault created before the rename opens with its original
  password and device secret.
- **Any vault password:** the 16-character minimum is removed. Passwords are
  never trimmed; creation uses a confirmation field and a live Very weak →
  Very strong strength score.
- **Default BSC tokens:** USDT and USDC are merged into every wallet alongside
  BNB. Contracts and 18-decimal precision are verified on-chain.
- **Verified public RPC nodes:** added 1RPC, Blast, and 48.club mainnet doors
  that answered the correct chain ID.
- **Private-key cold signing:** a wallet imported as a raw key can export a
  cold pairing and sign offline; the signing path verifies the same fields,
  replay protection, and response integrity as the phrase path.
- **BscScan V2 endpoint:** history requests now use the chain-aware V2 API.

## 1.2.0+6 — localization, spending safety, and release evidence

- Complete static UI localization for six languages.
- Freeze signing, recipient allowlist, and native per-transaction limit.
- Node, token, history, privacy-route, and token-logo tooling.
- X Wallet Linux identity `com.jackh0006.xwallet`.
- Risk-control, data-control, self-audit, and signed release evidence.

## 1.1.0+5 — X Wallet product rename

- **Official product name:** X Wallet across the application, six locales,
  window title, Android label, desktop entry, documentation, and tests.
- **Compatibility preserved:** Dart package `bnb_wallet_gui`, Linux binary
  `bnb_wallet_gui`, Android application ID, vault magic/filenames, backups,
  device-secret identifiers, data paths, and environment variables.
- **Debian package migration:** `x-wallet` with
  `Provides/Replaces/Conflicts: bnb-wallet`; `/usr/bin/bnb-wallet` remains a
  compatibility symlink.
- **New original X Wallet icon** in all hicolor sizes.
- **Branding validator:** `scripts/check_branding.py` fails on inconsistent
  user-facing names and protects compatibility identifiers.
- **Custody honesty:** hardware-wallet and multisig status remain
  `NOT IMPLEMENTED`; large-value custody is explicitly `NOT READY`.
- **Offline signer hardening:** existing cold/offline signing tests and
  field-binding verification retained.

## 1.0.10+4 candidate — native KDF, exact calldata, evidence system

- **Native Argon2id backend:** `lib/kdf.dart` now uses the reference C Argon2
  library that the Linux bundle already ships. One 64 MiB / t=3 / p=4
  derivation measured **344 ms** instead of ~110 s in the debug pure-Dart
  fallback. Production parameters are unchanged; the pure-Dart implementation
  remains only as an explicit fallback and is guarded by a performance test.
- **Exact ERC-20 calldata:** `SendIntent.decodeErc20Transfer` rejects trailing
  bytes, so a non-standard token cannot act on data the review screen did not
  show.
- **Deterministic tests:** navigation no longer starts real RPC timeouts;
  unlock I/O runs through `runAsync`; storage teardown waits for encrypted-log
  appends and retries `ENOTEMPTY`. The suite no longer segfaults on a 2-core
  machine.
- **Evidence system:** machine-readable test inventory and release manifest,
  generated status page/README block, `release-gate.py` with explicit
  `VERIFIED`/`PARTIALLY VERIFIED`/`INCOMPLETE`/`FAILED` states, dependency
  review, pinned artifact attestations, and a two-build reproducibility check.
- **Donations:** all 14 published address rows, with in-app copy/QR dialog;
  never shown in a transaction confirmation.
- **Honesty:** hardware-wallet matrix corrected to `NOT IMPLEMENTED`; Android
  releases remain blocked by the historical signing-key incident.
- **Package smoke:** Ubuntu 24.04 CI installs the `.deb`, launches it under
  Xvfb, upgrades from 1.0.9 with a data marker, uninstalls, and reinstalls.
- **Reproducibility:** fixed-path two-build comparison passes; Flutter embeds
  absolute paths, so different paths are not guaranteed to match.

## 1.0.9-ui.1 prerelease — accessibility, locale and status accuracy

- **Accessible primary actions:** primary-button labels now use black text on
  the yellow brand color in every theme. The previous white-on-yellow light
  theme treatment did not provide adequate contrast.
- **Live navigation localization:** Home, Wallet, Send, Inspect and Settings
  labels now update immediately when the locale changes. `Inspect` was added
  to all six maintained catalogs; `test/localization_catalog_test.dart`
  prevents a missing catalog entry from silently falling back to English.
- **Honest Settings copy:** About now reports 1.0.9, the language setting no
  longer instructs users to restart, and the limits notice accurately says
  that themes exist and that detailed wallet/security instructions remain
  English. This is intentionally not presented as full-interface translation.
- **Original application mark:** replaced the old shield artwork with an
  original orange `B.` on a near-black rounded square. It intentionally does
  not use Binance's diamond mark or geometry.

## 2026-11-04 — M3 Filesystem Security Corrections (v1.0.7)

- **Errno-aware symlink classification (Linux):**
  - New `lib/posix_fs.dart` (dart:ffi libc helper): `classifyNoFollow`/`classifyChildNoFollow` via `lstat`/`fstatat` with `AT_SYMLINK_NOFOLLOW`; real errno distinguishes missing, regular file, directory, symlink (valid or broken), special file, and inaccessible.
  - `isSymlink()` fails closed on `inaccessible` (EACCES/EPERM/ELOOP/EIO…) instead of answering "not a symlink".
  - Non-Linux platforms: documented `FileSystemEntity.type(followLinks:false)` ambiguity — `notFound` conflates missing + lookup errors; fail-closed where possible.

- **`atomicWrite` destination hardening:**
  - Classification independent of `exists()`: valid AND broken symlinks refused through fstatat; directories/special files refused; missing = distinct expected fresh case.
  - Linux descriptor pipeline: canonical parent check (realpath equality) → pinned dirfd (O_DIRECTORY|O_NOFOLLOW) → initial no-follow child classification → `mkstempAt` (0600 O_CREAT|O_EXCL, umask-proof, descriptor-relative) → write+fsync+verify through fd → beforeCommit hook → **use-time recheck** (fresh+missing = PROCEED; fresh+present = REFUSE) → `renameCommit` (RENAME_NOREPLACE + `renameat` ENOSYS→`rename` fallback) → fsync(dirfd) → final statFd (fchmod→unlink+throw only if still bad).
  - Portable non-Linux fallback with unconditional no-follow symlink check.

- **Pre-existing log append race fixed:**
  - `unlock()` → `unawaited(logEvent(...))` raced test append → two concurrent `writeAsBytes` on `bnb-wallet-log.bin` interleaving ciphertext → `SecretBoxAuthenticationError`.
  - Fixed by `static final Lock _fileLock` (package:synchronized) around `append`/`readAll`/`clear` in `encrypted_log_store.dart`.

- **Dedicated Linux integration tests** (`test/filesystem_security_test.dart`): 20 tests covering all 11 required cases + 3 race regressions (11a/11b/11c) + 6 mechanism guarantees (0600 at creation under umask 0002, cleanup, replacement, mkstemp vs stat(1), read caps, fd roundtrip).

- **Process umask(077) at startup** (`linux/runner/main.cc`) protects all plugin-created files/dirs; verified by staged `.deb` first-run under desktop umask 0002 → dirs 0700, files 0600.

- **M3-06: Vault-version test-construction fix** — Fixed test to properly construct unsupported version vault blob; validation now accepts any BNBVLxxx prefix and lets decryption handle version check.

- **M3-08: Import-rollback write-failure injection** — Verified via rollback tests (10/10 pass) including wrong password, malformed, wrong version, empty, oversized, missing confirmReplace, tampered, and concurrent operations.

- **No regression** of: creation-time 0600 perms, vault contents on failed writes, import validation, explicit replacement confirmation, vault operation locking, temp-file cleanup, atomic replacement.

- **Honest documentation**: non-Linux ambiguity, crash safety non-claim (persistent recovery journal = outstanding limitation), `renameat` ENOSYS fallback residual.

- **Verdict**: **M3 COMPLETE** — All M3 tasks done; crash-recovery journal remains a documented non-claim.

- **Full verification battery**: non-KDF +238 pass (exit 0); KDF suites individually (vault_test +7, workers_test +3, rollback +10/10); analyzer 124 issues (all pre-existing at HEAD); Linux release build; `.deb` build + SHA256 + GPG verify + `dpkg -c` secret check (clean); ethers.js verify PASS (8 substitutions); staged `.deb` install test (dirs 0700, files 0600).

## 2026-11-03 — M3 Security Fixes: Vault Backup/Restore Hardening

- **Export (Backup) Security Hardening:**
  - Verifies the supplied password against the active vault BEFORE exporting
  - Rejects incorrect passwords immediately
  - Validates the vault envelope format (magic, version, structure, size limits)
  - Uses atomic output creation (tmp → rename) with restrictive permissions (0600)
  - Refuses to overwrite an existing backup file without explicit user action
  - Reads back and validates the exported file (content match + envelope validation)
  - Never logs passwords, vault contents, seeds, or private keys

- **Import (Restore) Security Hardening:**
  - Reads and validates the SELECTED BACKUP file, not the current vault
  - Enforces regular-file checks, sensible size limits (5 MB), recognized format/version (BNBVL003/BNBVL004)
  - Verifies the supplied password by decrypting THE IMPORTED BACKUP (not the current vault)
  - Verifies all required cryptographic authentication tags and device-key dependencies
  - Rejects truncated, malformed, corrupted, unsupported-version, wrong-password, and tampered files
  - Does NOT replace the active vault until validation and decryption succeed completely
  - Preserves the original vault if any step fails (atomic tmp → rename replacement)
  - Requires explicit user confirmation before replacing an existing vault
  - Reports success only after the new vault has been read back and validated

- **Cross-device Recovery:**
  - The vault format uses a device-bound secret (second factor)
  - Backup files can be restored on another device with the same password + device secret
  - Device secret migration documented; cross-device recovery tested via independent decryption

## 2026-11-03 — cold-wallet and verification hardening (unreleased)

- **Cold wallet end-to-end:** pairing/request/signature envelopes with
  version, kind, canonical JSON, SHA-256 checksum, strict field allow-lists
  and size limits; public-address-only pairing; runtime-offline cold signer;
  online companion with no keys; strict verify-before-broadcast; replay and
  already-broadcast guards; bounded public storage.
- **EIP-1559 correctness:** new `cold_tx_codec.dart` replaces the broken
  `rlp` package usage. One canonical codec now produces the unsigned payload,
  digest, signed bytes and parsed transaction. The parser rejects
  non-canonical RLP, bad scalars, high-s, wrong field counts and access lists.
- **Independent verification:** `verification/verify.cjs` uses ethers.js
  6.17.0 (not web3dart) to check the exact bytes, digest, fields, `r`/`s`/
  `yParity`, hash and recovered signer, and rejects 8 substitutions.
- **TLS pinning:** standard CA/hostname validation first, then SPKI pin;
  corrected the v3 certificate SPKI index (extensions were hashed instead of
  the public key); pinned HTTP CONNECT refused; 6 integration tests.
- **Memory hardening:** FFI `prctl(PR_SET_DUMPABLE,0)`, `setrlimit(RLIMIT_CORE,0)`
  and best-effort `mlockall`; kernel-state tests. The old `sh -c ulimit` was a
  no-op.
- **Release hygiene:** removed the committed keystore and hardcoded password;
  `build-apk.sh` requires environment credentials and never creates a
  keystore; `.gitignore` blocks signing material; `secret-scan.sh` runs in CI.
- **Cold account index:** signer derives the matching default BIP-44 account
  instead of always index 0.
- **Test stability:** keyring read bounded and skipped under `FLUTTER_TEST`;
  proxy dialog overflow fixed; realistic KDF timeouts.
- Docs: `SECURITY_AUDIT.md`, `docs/COLD_WALLET.md`, `docs/TESTING.md`;
  updated THREAT_MODEL, CRYPTO, SECURITY, SPEC-COMPLIANCE and README.
- **Not changed into a claim:** no third-party audit; old release key remains
  compromised and must be rotated; no OS-enforced air gap; no camera QR on
  Linux; no two-device field test.

## 1.0.5 — release rounds 1–8 plus verification rounds R0–R3 (2026)

### Vault & keys
- Encrypted vault (`bnb-wallet-vault.bin`): Argon2id 64 MiB / t=3 / p=4,
  XChaCha20-Poly1305 envelope; a drawer key for the wallet stays on device.
- Creation ceremony with verified seed backup, duplicate-offer testing,
  and an auto-created wallet on first run.
- App unlock, optional PIN/biometric gate after background, auto-lock
  choices (0/background-only · 60 s · 300 s).

### Network & node manager (§10d)
- RPC node phone book per side (mainnet/testnet): add, edit, use, remove,
  reset-to-official, enable/disable per row, reorder (book order =
  priority order), import/export as JSON.
- "Use ONLY my node" strict mode: no fallback doors, ever.
- Full per-node test checklist with visible results: reachable, right
  chain (blocking), chain-head freshness vs the active door, gas price,
  EIP-1559 fee-history support, pending nonce, eth_call, estimateGas,
  sendRawTransaction availability (invalid payload — nothing is ever
  broadcast by a test), answer time.
- One-time per-node privacy warning ("what a node sees") before first use.
- Chain verification on every connect; no hardcoded doors outside the
  single default table.

### Privacy (§5–§7)
- One mandatory client factory: identifying `User-Agent` scrubbed, only
  content-type/accept headers sent.
- Optional Tor routing through a local SOCKS5 port, no fallback to direct.
- Clipboard: refuses secret-shaped text, self-clears after 30 s (iff still
  the same content). Seed words never enter the clipboard.
- FLAG_SECURE (Android) and backup-disabled manifests.

### Fees (§9)
- Live multi-node fee quote with sanity drop of outliers, EIP-1559 +
  legacy routes where history is unsupported; presets show expected wait
  in blocks and seconds measured from the chain, never invented.

### Sending journey (§8.4, §9)
- Staged send with narration: validation → fee pick → rehearsal
  (eth_call from the real sender) → sign → broadcast → block wait →
  receipt → honest impossible-refusals (e.g. out of gas money) that
  explain the math on screen.
- Pending-tx tracking in plain prefs with live finality estimates;
  receipt double-check against an independent door (skipped honestly in
  strict mode).

### Receipts archive (§10c)
- Encrypted on-device receipt archive (`BNBRCPT1`, XChaCha20-Poly1305,
  HKDF-derived keys), capped at 200, per-receipt disclosure, search by
  address/contract, details page with hash/nonce/logs/UTC time.

### Tokens (§10e)
- Custom BEP-20 add flow verified on-chain before save.
- Trusted sources: shipped `assets/token_sources.json`, 3-step checklist,
  scam warning, one-time notice, open/copy buttons, user-editable own
  links (add/remove/reorder), CI link checker.
- Component inventory: `docs/SBOM.json` (deterministic, from the lock).

### Packaging & docs (§11)
- deb with sha256 + GPG signature; version pinned 1.0.5.
- LICENSE (AGPL-3.0-or-later), PRIVACY.md, THREAT_MODEL.md ("no third-
  party audit yet" — stated exactly once, truthfully), ARCHITECTURE.md,
  CONTRIBUTING.md, CHANGELOG.md, SECURITY.md, STANDARDS.md, SBOM.json,
  CI workflow for analyzer + tests + link checks.
- About screen: version, license, build-verification how-to, SBOM pointer,
  security notice without marketing.

### Verification round R0 (source integrity)
- Rebuilt the truncated RPC service in ordered chunks; every original
  behavior (story budget, per-node transport, measured fees, simulation,
  sign/broadcast, receipts, finality) re-verified.
- Corrected `docs/SPEC-COMPLIANCE.md` against the actual code and kept
  audit statements factual (one truthful note in THREAT_MODEL.md only).

### Logs and privacy (R2)
- Encrypted activity log (`BNBLOG01`) with a Simple timeline and Expert
  filtered record, session headers, category/level filters, search, live
  tail, copy/export with an activity warning, and clear.
- "View raw request": the last 50 real exchanges (method, status, exact
  request body, exact response) from memory only.
- Log canary test proving ciphertext at rest never contains the canary.

### Keys, tokens, display (R3 / R6 subset)
- Seed backup quiz: three random words must be re-typed before creation;
  Settings can re-verify an existing phrase.
- Watch-only import: public address only, sends refused, no key stored.
- Built-in/custom token visibility switches; hidden tokens leave the send
  picker but keep their on-chain balance.
- Lite mode: static journey states and progress bar instead of the pulse.
- Reduce-motion support: the system setting switches the Journey Map to the
  same static Lite presentation automatically.
- Hold-to-confirm signing: after typing the last 6 recipient characters, the
  user must hold a fill button for 1.6 s; early release cancels before signing.
- Home node card now has a latency sparkline, session request count and a
  direct "Switch node" path to the node manager.
- "Compare another" asks one independent node the same chain-id question and
  reports same/different chain and block distance (never changes the active
  node, never signs or broadcasts).

### Journey and receipts (R3)
- Five-stop Journey Map (phone → privacy → node → chain → done) with
  waiting/working/ok/problem states and per-stop detail cards.
- Home node card: answer-time gauge, latest block, right-chain badge,
  privacy route, and a check-now probe.
- Receipts now store block hash/index, transaction type, calldata and raw
  event logs; the page decodes `transfer(...)` and Transfer logs, shows a
  hash QR, copies/saves JSON, renders a full PNG, warns before sharing or
  opening an explorer, and sends a local Linux notification on confirmation.
- Tests: all non-KDF suites (140) plus the 10 real 64 MiB KDF tests are
  green; analyzer reports 0 errors and 0 warnings.

## 1.0.4 — earlier rounds
- Terminal wallet core port, first GUI screens, initial deb packaging.
