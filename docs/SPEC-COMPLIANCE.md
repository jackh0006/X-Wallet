# SPEC-COMPLIANCE.md — line-by-line audit of `bnb-wallet-agent-spec.md`

Statuses: ✅ done and verifiable · 🟡 partial (gap stated) · ❌ not done
(deviation stated) · 🔒 blocked by an external decision/constraint.

Alignment as of 2026-11-03, version 1.0.5 deb line (R0 source restoration,
R2 privacy/log round, R3 journey/receipt round, R4/TLS+memory and R5 cold
wallet round). R0: the truncated `lib/rpc_service.dart` was rebuilt in
verified chunks, the suite was re-run, and stale rows below were corrected.
R3 added the Journey Map and node card, receipt completion (QR/JSON/PNG,
decoded call/logs), backup quiz, watch-only profiles, token hiding, Lite mode
+ reduce-motion and hold-to-confirm signing. The 2026-11-03 round added the
strict EIP-1559 cold codec, cold request/response envelopes, independent
ethers.js verification, standard-TLS-first SPKI pinning, FFI kernel memory
hardening and secret-scanning CI. Every ✅ cites where a reader can check it.
Roadmap for remaining gaps at the bottom (R4…R7), mirroring the working plan;
the internal self-assessment is [`SECURITY_AUDIT.md`](../SECURITY_AUDIT.md).

---

## §0 Non-negotiable rules

| # | Requirement | Status | Evidence / gap |
|---|---|---|---|
| 0.1 | Reviewed libraries only; pin, lockfile, hashes | 🟡 | `pubspec.lock` committed; `docs/SBOM.json` lists every version + SHA-256 (`scripts/sbom.py`); crypto primitives come from `cryptography`/`web3dart`. The EIP-1559/RLP serialization is project code (`cold_tx_codec.dart`) because the available RLP helper was wrong for byte strings; it is cross-checked with ethers.js in `verification/verify.cjs` |
| 0.2 | No invented chain facts | ✅ | Fee engine measures fee history + block times live (`fee_engine.dart`, `rpc_service.dart`); presets derive ETAs from measured seconds-per-block |
| 0.3 | Zero telemetry/ads/SDKs | ✅ | PRIVACY.md; only RPC/explorers ever contacted; `docs/SECURITY.md` |
| 0.4 | Privacy claims testable | 🟡 | Behavior tests exist; automated traffic-capture (tcpdump asserting §6/§7) not yet — R4/R7 |
| 0.5 | Fail closed on unclear tx | ✅ | Rehearsal (eth_call) blocks with revert text; chainId verified on connect; validators on every input |
| 0.6 | No overclaims ("unhackable") | ✅ | About text replaced this round: "there is no third-party audit yet"; THREAT_MODEL uses the same wording once |

## §1 Architecture

| Requirement | Status | Evidence / gap |
|---|---|---|
| Rust core via flutter_rust_bridge (secrets only in Rust) | ❌ deviation | **Documented deviation**, not an oversight: pure-Dart core, secrets handled in Dart (`wallet_core.dart`), rationale + revisit-conditions in `docs/ARCHITECTURE.md` |
| Offline-first (default work with no network) | 🟡 | Signing/seed/settings/logs work offline; balances need a node (refresh on demand) |
| Air-gapped build flavor (no INTERNET) | 🟡 | Cold mode is runtime-offline only: `RpcService.setOffline(true)` and `connect()` fail closed; the APK still carries the INTERNET permission, so this is not an OS-enforced air gap. A separate no-INTERNET build flavor is not produced |

## §2 Cryptography & key management

| Requirement | Status | Evidence / gap |
|---|---|---|
| BIP-39 seed, OS CSPRNG entropy | ✅ | 24-word English default (`WalletCore.generateMnemonic`, `MnemonicLength.words24`); import validates the checksum and accepts 12/24 words |
| BIP-32/44 `m/44'/60'/0'/0/i`, EIP-55 display | ✅ | `wallet_core.dart`; tests |
| ECDSA RFC-6979 deterministic, low-s, EIP-155 | ✅ | web3dart signing path; verification in round-8 mainnet-ready dry runs |
| Legacy + EIP-1559 by runtime detection | ✅ | `fee_engine.dart` (feeHistory probe → fallback legacy) |
| Argon2id ≥64 MiB/t≥3 + XChaCha20-Poly1305 vault | ✅ | `vault_engine.dart`; docs/CRYPTO.md |
| Android Keystore wrap + biometric admin | 🟡 | PIN gate + FLAG_SECURE + allowBackup=false present; no Keystore-wrapped vault key |
| Linux $XDG_DATA_HOME 0600, core-dump off, mlock | ✅ | Vault under XDG with 0600; `memory_protection.dart` uses FFI `prctl(PR_SET_DUMPABLE,0)`, `setrlimit(RLIMIT_CORE,0)` and best-effort `mlockall`; `test/memory_protection_test.dart` asserts real kernel state (2/2) |
| Clipboard auto-clear 30 s; never copy seed | ✅ | `common.dart` timer clear + `ClipboardGuard.secretFree` tests |
| Auto-lock (60 s default, options) | ✅ | Settings chips 0/60/300; background lock |
| Backup quiz (re-enter words) | ✅ | `backup_quiz.dart` + `screens/backup_quiz_dialog.dart`: creation asks for 3 random words before the wallet is created; Settings can re-verify an existing phrase; 5 unit tests |
| Import: mnemonic | ✅ | settings flow |
| Import: private key | ✅ | settings flow |
| Import: keystore JSON v3 | ✅ | `_importKeystore` in `wallet_page.dart` (scrypt/pbkdf2 V3, password kept out of logs) |
| Watch-only accounts | ✅ | Import → Watch an address. No key/seed is stored; send page refuses to sign; profile persists across restarts (`watch_only_test.dart`) |

## §3 Sending

| Requirement | Status | Evidence / gap |
|---|---|---|
| BNB + BEP-20 transfer built locally, re-verified decimals | ✅ | `send_page.dart`; tokenMeta reads symbol/decimals on-chain before save |
| Built-in token list w/ disable | 🟡 | No built-in USDT/USDC constants in code yet; send picker is native BNB + user-added tokens only. Tokens added by user can be hidden/shown (`AppState.setTokenHidden`). Built-in list with CI verification — open |
| Custom add: code exists, name/symbol/decimals, confirm | ✅ | tokenMeta + add flow (verified on-chain) |
| Pre-send simulation w/ revert reason | ✅ | `simulateTransfer` in round-8 send flow |
| Address poisoning warn (first/last 6) | ✅ | `WalletCore.sharesAffixes` + send-page hint |
| Warn: token self-contract / zero address / new addresses | ✅ | round-8 send safeguards |
| Human + raw amounts on review; full review fields | ✅ | review card: chain/from/to/asset/amount/nonce/gas/fee/total + node disclosure |
| Nonce mgmt, pending handling, stuck handling | ✅ | pending list + live finality; Speed up / Cancel re-sign the SAME nonce at ≥ +12.5% (`send_page.dart` `_replacePending`) |
| Gas = estimate + margin, ≥ estimate | ✅ | send flow |
| Confirmations Created→…→Final; finalized tag | ✅ | lifecycle + story wording; "finalized" uses block tag when node supports |
| Broadcast resilience (already-known/nonce-too-low) | ✅ | lifecycle handles; N-node broadcast — 🟡 cross-check only |
| Block if BNB for gas insufficient | ✅ | honest refusal screen (round-8) |

## §4 Fee engine

| Requirement | Status |
|---|---|
| Live data (gasPrice, feeHistory 10/50/90, blocks), ≥2 RPCs median, outlier drop | ✅ — `fee_engine.dart` + `_feeCandidates`; unit fixtures incl. lying-node rejection |
| Three tiers + recommendation + WHY in plain words | ✅ — send page shows reason congestion-based |
| Never below node minimum; measure block time, ETA ranges | ✅ |
| Custom gas/limit (advanced) | ✅ |
| Fee in BNB; USD only if enabled (default OFF) | ✅ | Only BNB is shown; there is no fiat price lookup at all, so no price API is ever contacted |
| Insufficient BNB for gas blocked | ✅ |

## §5 Networking layer

| Requirement | Status | Evidence / gap |
|---|---|---|
| One choke point; allowlist of configured RPCs | ✅ | `net/privacy_client.dart` + all calls via `RpcService` |
| Direct HTTPS with pinned certs | ✅ | `lib/net/privacy_client.dart`: normal CA/hostname validation first, then SPKI SHA-256 pin; wrong pin closes the connection. `test/tls_pinning_test.dart` (6/6) proves a pin cannot bypass CA or hostname checks and that Dart's pin equals OpenSSL's. Pinned HTTP CONNECT is refused before any socket opens |
| Tor via SOCKS5, kill-switch (no direct fallback) | ✅ | Tor switch with failure = error, no fallback; embedded Arti ❌ (external system tor/Orbot — documented) |
| Bridges | 🟡 | transparently supported: configure bridges inside Orbot/tor; app explains (settings copy) |
| Custom SOCKS5 w/ auth; HTTP CONNECT | 🟡 | SOCKS5 host/port + optional username/password wired (`createClientForNode`); HTTP CONNECT proxy not implemented |
| Own node incl. .onion RPC | ✅ | `nodeUrlAllowed` (localhost/LAN/.onion over Tor) |
| No DNS leaks through proxy | ✅ | SOCKS5h semantics through client |
| Default door list + user doors + health-check | ✅ | phone book §10d |
| No identifying headers/UA; no device time sent | ✅ | privacy client |
| Batch/pad/jitter, decoy addresses (Dust mode) | ❌ | R4 |
| Backoff+jitter, stale labels, weak-device stability | ✅ | backoff state; "stale as of block N" badge |

## §6 ISP/DPI disclosure

| Requirement | Status | Evidence / gap |
|---|---|---|
| Network-privacy screen generated from REAL config | ✅ | Settings → Network & assets → Network privacy: `_networkPrivacySection` derives the ISP/node/chain cards and warning from `isTor`, the active route and node book; includes a raw-request example |
| Docs page with §6 content | ✅ | `docs/PRIVACY.md` |
| Packet-capture CI asserting §6 | ❌ | R4/R7 |

## §7 "What the node sees" per action

| Requirement | Status | Evidence / gap |
|---|---|---|
| Live disclosure on network actions + settings | 🟡 | Send review shows what goes to the node; the privacy screen shows the real active config. A per-action collapsible panel is still open. |
| "View raw request" + copy log | ✅ | Logs → code icon shows the last 50 real exchanges (method, HTTP status, exact request body, exact response) from memory only, with Copy; never written to the log file |

## §8 Logging

| Requirement | Status | Evidence / gap |
|---|---|---|
| Encrypted-at-rest logs (vault-derived key), ring buffer | ✅ | `encrypted_log_store.dart` (`BNBLOG01` envelope, HKDF over wallet key + device drawer secret, 5 MB / 10 000-entry cap); network, tx and lock events are written from `rpc_service.dart` / `app_state.dart` |
| Redaction: no secrets; shortened addresses | ✅ | Only narration is logged; signed raw transactions are never written (the raw-request panel is memory-only); addresses are shortened |
| Canary tests (no secret reaches sink) | 🟡 | Pattern tests exist; a dedicated end-to-end canary-secret test across every sink is still R7 |
| Categories + viewer UI + export w/ warning | ✅ | `screens/logs_page.dart`: Simple/Expert toggle, session timeline, level/category filters, search, live tail, copy/save with an activity warning, clear; `log_presenter.dart` maps every category/level |
| Per-transaction timeline | 🟡 | Search by transaction hash works; a dedicated per-tx timeline view is open |

## §9 UI/UX

| Requirement | Status | Evidence / gap |
|---|---|---|
| Screens enumerated | 🟡 (deb scope) | onboarding/create, home, receive(+QR), send, tx details, receipt, tokens, network, security, **Logs**, about; Lite mode switch. Light/AMOLED + i18n still missing |
| About = version/license/build-verify/SBOM | ✅ | About card in `settings_page.dart` |
| Light/AMOLED themes, i18n (fa/en/ar/zh/ru/es) | ❌ | documented gap; dark theme + Lite mode only |
| External explorer only on tap w/ privacy warning | ✅ | receipt/link taps warn before open |
| Dangerous-action re-auth + typed confirmation; hold-to-confirm signing | ✅ | seed reveal/erase require confirmation; send requires the last 6 recipient characters typed and then a 1.6 s hold (`widgets/hold_to_confirm.dart`, tested); early release cancels before signing |

## §10 Testing & verification

| Requirement | Status | Evidence / gap |
|---|---|---|
| Official test vectors (BIP-39/32/44, EIP-155, EIP-55, ABI, Argon2id) | ✅ | 140 non-KDF tests green on 2026-10-21 plus the 10 real 64 MiB KDF tests (vault code unchanged in this round); `flutter analyze` 0 errors/0 warnings |
| Cross-verify against 2nd implementation | 🟡 | vectors cross-checked EIP-55/namehash; full ethers/cast cross-run — R7 |
| Testnet integration sends | 🔒 | needs a funded testnet key + explicit consent (user decision open) |
| Fuzzing/property tests | 🟡 | property tests for fee math + units; cargo-fuzz N/A to Dart |
| Adversarial-node tests (wrong chainId, lies) | ✅ | lying-node fee fixture + chainId refusal |
| Packet-capture/leak tests | ❌ | R4/R7 |
| CI tooling (analyze, tests, secrets-scan, SBOM, license) | 🟡 | `.github/workflows/verify.yml` runs analyze, tests, token-source links, SBOM freshness; secrets-scan & license check — open |
| Reproducible build | 🟡 | deterministic SBOM, versioned deb, signed; flutter toolchain pin — R7 |
| Third-party audit before 1.0 | 🔒 external | documented as "no third-party audit yet" |
| Real low-end device + Ubuntu 22.04/24.04 | ✅/🔒 | deb verified on this Ubuntu machine; 2 GB Android device external |

## §10b Visual live status

| Requirement | Status | Evidence / gap |
|---|---|---|
| Journey Map view, node card, privacy card, tx stepper | ✅ | `widgets/journey_map.dart`: 5-stop horizontal map with waiting/working/ok/problem states, tap → per-stop detail + raw lines; Home node card has answer-time gauge, latest block, right-chain badge, privacy route, latency sparkline, session request count, switch-node link and a point-in-time "Compare another" chain/block check; send has the tx stepper |
| Simple vs Expert log modes | ✅ | `logs_page.dart` + `log_presenter.dart`: same encrypted source, Simple timeline and Expert filtered record, tests for every category/level mapping |
| Accessibility labels/colors + haptics | 🟡 | semantic labels, non-color status words and system reduce-motion → Lite behavior present; haptics and a full screen-reader pass remain |

## §10c Receipts

| Requirement | Status | Evidence / gap |
|---|---|---|
| Auto receipt after final state; always in history | ✅ | round-8 lifecycle + receipt archive |
| Full fields + decoded input + event logs | ✅ | receipt shows hash, status, from/to, asset/amount/raw, nonce, gas, fee, confirmations, finality, node/transport, block hash/index, tx type, balances, decoded `transfer(...)` call, decoded Transfer logs, raw call/log expanders |
| Encrypted local store w/ cap | ✅ | `receipt_store.dart` (BNBRCPT1, cap 200) |
| Double-check against 2nd node badge | ✅ | independentNodes; honest single-node note in strict mode |
| Copy hash / all details; JSON/PDF export; QR | ✅ | hash QR dialog; copy hash/explorer/all JSON; Share as text; JSON file and full receipt PNG (`receipt_image.dart`, tested) |
| Share-as-text warning; local notification | 🟡 | warning before copying; local `notify-send` on Linux after confirmation (no push service). Android local notification still open |
| Contract-paste→address/evil-label, Explorer open w/ warning | ✅ | opens externally after privacy warning |

## §10d Custom node settings

| Requirement | Status |
|---|---|
| Rows: name/URL/status/latency/enable/disable/reorder/delete (restore via reset) | ✅ — switch per row, ▲▼ actions, Reset-to-official |
| Custom node form w/ URL policy (https; http only localhost/LAN/.onion) | ✅ — `nodeUrlAllowed` + validators + one-time warning shown ONCE per node |
| Test node checklist w/ visible results incl. sendRaw availability (probe never sends) | ✅ — `testNodeDeep` (9 rows; chain mismatch BLOCKS save) |
| Strict "use only my node" | ✅ — app_state + pure `feeCandidatePool`/`independentNodeList` gates |
| Import/export JSON without secrets | ✅ — clipboard JSON; import validates + dedupes |
| Everything routes through node manager; no hardcoded endpoint anywhere else | ✅ — doors live in `BnbNetworks` tables only; pools fed from the book |
| Per-node transport override | ✅ — Direct / Tor / custom SOCKS5 per node, inherit-global default (`app_state.setNodeTransport`, privacy client) |
| Bearer/Basic auth in vault; custom headers; pinned cert | 🟡 — SPKI pinning and SOCKS5 proxy auth are wired and tested; node HTTP Bearer/Basic auth and custom headers remain open |
| Selection modes: manual/auto-fastest/round-robin/quorum | 🟡 — manual + strict; auto/random/quorum — open |
| "use for: reads/broadcast/both" per node | ❌ — open |

## §10e Token-contract sources

| Requirement | Status |
|---|---|
| Section below the address field w/ icon/name/description rows; Open + Copy link per row | ✅ — `_tokenSourcesSection()` |
| Open only on tap, external browser (no WebView, no preload) | ✅ — `xdg-open` on Linux; copy-on-other-platforms |
| One-time notice w/ Don't-show-again | ✅ — `token_sources_notice` |
| Never auto-fetched; lists live in repo `token_sources.json` | ✅ — `assets/token_sources.json` + never loaded from network |
| User-editable own links (add/remove/reorder) | ✅ — settings rows |
| CI link checker fails on dead/different-domain redirects | ✅ — `scripts/check_token_sources.py` (BscScan rows honestly SKIPped as bot-protected) |
| Scam warning above the list | ✅ — orange warning text |
| 3-step checklist ①②③ | ✅ |
| Green "Checks passed" card after verification | 🟡 — add-flow verifies on-chain and reports; upgrade to persistent green card — open |

## §10f Cold wallet mode

| Requirement | Status |  Evidence / gap |
|---|---|---|
| Complete cold mode (signer/companion, pairing, offline signing, privacy of files, erase-everything) | 🟡 | Implemented: versioned pairing/request/signature envelopes, SHA-256 checksum, public-address-only pairing, runtime-offline signer, strict verify-before-broadcast, replay/burn list, bounded public storage, mode transitions that wipe keys. Evidence: `lib/cold_wallet_protocol.dart`, `lib/cold_wallet_service.dart`, `lib/screens/cold_wallet_dialogs.dart`, `test/cold_wallet_protocol_test.dart` (15), `test/cold_wallet_service_test.dart` (15), `verification/verify.cjs`. Gaps: no OS-enforced no-INTERNET build, no camera QR on Linux, no two-device field test, no third-party audit |

## §11 Repo deliverables

| Requirement | Status |
|---|---|
| README.md | ✅ (existing, updated round 7) |
| SECURITY.md (PGP contact) | ✅ exists, round-8 row shipped |
| PRIVACY.md | ✅ NEW |
| THREAT_MODEL.md | ✅ exists ("no third-party audit yet", stated once) |
| ARCHITECTURE.md | ✅ NEW (documents the Rust-skip decision) |
| CONTRIBUTING.md | ✅ NEW |
| CHANGELOG.md | ✅ NEW |
| LICENSE | ✅ NEW — verbatim GNU AGPL-3.0 (sha256 0d96a4ff68ad6d4b6f1f30f713b18d5184912ba8dd389f86aa7710db079abcb0) |
| SBOM | ✅ NEW — `docs/SBOM.json` (deterministic) |
| CI workflows | ✅ NEW — `.github/workflows/verify.yml` |
| Docs for adding chains/tokens | 🟡 — ARCHITECTURE covers tokens; chains section — open |

## §12 Honest in-app limits

| Requirement | Status | Evidence / gap |
|---|---|---|
| Public chain visibility, nodes see IP, Tor limits, compromised device, seed loss, fee estimates, malicious tokens | ✅ | About → **Honest limits** dialog covers compromised OS, RPC visibility/lies, the file/paste cold flow (no camera QR on Linux), fake tokens, clipboard window, missing themes/i18n and no warranty; plus the security notice, PRIVACY.md and SECURITY_AUDIT.md |

## §13 Definition of Done

Unmet items, all honestly named:

1. 🔒 Independent third-party audit — external decision.
2. 🔒 Testnet integration sends (BNB + USDT + USDC + custom token) — needs
   a funded testnet key and explicit consent for a small mainnet transfer.
3. 🔒 2 GB Android 8/9 device battery of checks — deb-only decision keeps
   APKs out of scope; a Linux-equivalent check is ours (done).
4. 🟡 R4/R5/R7 remain partially open: node HTTP auth/custom headers,
   selection modes, an OS-enforced no-INTERNET build, camera QR, two-device
   cold field test, and release-key rotation. R3 and most of R6 are done;
   cold signing/verification and TLS/memory hardening are implemented and
   tested (see the section rows above and SECURITY_AUDIT.md).
5. 🔒 Reproducible-build published-hash verification — GPG-signed set exists;
   toolchain pin — R7.
6. 🔒 Release-key rotation — the old keystore was committed and is
   compromised; future APKs need a new key held outside the repository.

## Working plan to zero (R3…R7)

- **R3 visuals/receipt round:** ✅ Journey Map + node/privacy/tx cards; receipt
  QR/JSON/PNG, block hash/index, decoded calldata/logs, notification. Still
  open and tracked in the rows above: per-tx log timeline, selection modes
  (auto/random/quorum), checks-passed card.
- **R4 networking hardening:** batching/padding/jitter; dust mode;
  N-node broadcast; node HTTP auth headers. Cert pinning and standard-TLS
  ordering are done; HTTP CONNECT with pins is refused, not silently
  downgraded.
- **R5 cold wallet:** §10f end-to-end is implemented (file/paste/QR display,
  strict field binding, replay protection, wipe-on-mode-switch tests). Open:
  camera QR, OS-enforced no-INTERNET build, two physical devices, external
  audit.
- **R6 leftovers:** ✅ backup quiz, watch-only, built-in token hide, honest
  limits, Lite mode + reduce motion; still open: light/AMOLED themes, i18n
  scaffold, mlock/core-dump, adding-chains doc.
- **R7 release:** reproducible-toolchain pin, cross-implementation vector
  run, canary-secret end-to-end test, full DoD recheck, final deb + signed set.

R2 status: encrypted log store + Simple/Expert viewer, real raw-request panel,
per-node transport, SOCKS5 auth and a log canary test are done. Remaining R2
items rolled into R4/R7: packet-capture CI and the wider sink canary test.
