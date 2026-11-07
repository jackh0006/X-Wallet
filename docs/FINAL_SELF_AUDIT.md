# X Wallet — Final Internal Self-Audit

**Scope:** X Wallet `1.2.0+6`, release tree at the `v1.2.0` tag.
**Date:** 2026-11-07
**Audit type:** internal self-audit performed by the project's AI-assisted
engineering process. **This is not an independent external audit.**

## Executive assessment

No unresolved Critical or High **code** defect was found in the Linux wallet
release scope. The release is internally approved for ordinary Linux use with
the controls in `RISK_CONTROLS.md`. Owner-directed large-value use is permitted
under those controls; this internal audit is not an independent certification.

**Ordinary Linux wallet use:** internally approved. **Large-value use:**
owner-directed under `RISK_CONTROLS.md`, with split balances, freeze signing,
allowlist, per-transaction limits, and cold/offline signing.

## Components reviewed

- `lib/kdf.dart` — native Argon2id, fallback, parameter integrity.
- `lib/vault.dart` — v2 double-wrapped envelope, AAD, v1 migration.
- `lib/storage.dart`, `lib/posix_fs.dart` — atomic writes, no-follow, locks.
- `lib/wallet_core.dart` — BIP-39/32/44, EIP-55, signing/verification.
- `lib/send_intent.dart` — exact calldata and pre-sign field binding.
- `lib/cold_tx_codec.dart` — canonical EIP-1559 RLP, low-s, bounds.
- `lib/cold_wallet_protocol.dart`, `lib/cold_wallet_service.dart` — pairing,
  request/signature envelopes, expiry, replay, broadcast.
- `lib/rpc_service.dart`, `lib/net/privacy_client.dart` — chain ID, TLS, proxy,
  timeouts, ambiguous broadcast.
- `lib/screens/*` — review, warnings, hold-to-confirm, donation separation.
- `.github/workflows/*`, `scripts/*` — pins, permissions, release identity,
  signing, package smoke, reproducibility.
- `docs/*` — threat model, risk register, recovery, limitations, branding.

## Tests actually executed

| Check | Result |
|---|---|
| Branding validator | PASS |
| Formatting / analyzer | PASS |
| Default suite | 52/52 files, 0 failed, 0 timed out, 575 s |
| Real EVM (Anvil, chain 97) | 3/3 PASS |
| Mutation testing | 5/5 killed |
| Backup/restore E2E | 4/4 PASS |
| Release signing tools | 6/6 PASS (disposable test key) |
| Release identity negative tests | 15/15 PASS |
| Localization | PASS |
| Spending safety | 5/5 PASS |
| Data boundary (no telemetry/AI SDK; no network in key modules) | 4/4 PASS |
| Android signer inventory | PASS (synthetic keystore) |
| Package smoke | PASS: install, upgrade from `bnb-wallet` 1.0.9, launch, uninstall, reinstall (GitHub Actions `package-smoke`) |
| Reproducibility | PASS: fixed path, archive `dffb5b35…`, identical file manifests |
| Startup/RSS benchmark | Not applicable to the release gate; a keyring-backed desktop session is required |
| Secret scan / dependency / license / SBOM | PASS |
| Release identity validator | PASS |
| Release gate | VERIFIED — all required source and release checks recorded |

## Findings

| ID | Severity | Finding | Status |
|---|---|---|---|
| FA-01 | High | Historical Android release keystore exposed; rotation not verified | Open owner action; Android blocked; Linux `.deb` unaffected |
| FA-02 | High | Release `.deb` initially unsigned | **Resolved**: signed with owner key `CC819EF5E109A1518E840379D8C0CEC84BCCE06B`; `SHA256SUMS.asc` verified in a clean keyring (2026-11-07) |
| FA-03 | High | Independent external audit is a separate engagement | Not claimed; the internal self-audit and test evidence are published |
| FA-06 | Medium | Reproducibility and startup-RSS evidence were incomplete | Reproducibility PASS with identical file manifests; startup/RSS remains NOT TESTED on keyring-less CI (see FA-11) |
| FA-07 | Medium | Real-chain test uses a local Anvil node, not an independent BSC provider | Local EVM PASS; provider trust remains a residual |
| FA-08 | Medium | Branding rename could miss technical/user-facing strings | `scripts/check_branding.py` passes; compatibility identifiers preserved |
| FA-09 | Medium | Debian package identity migration could break upgrades | CI package smoke upgrades from `bnb-wallet` 1.0.9 and preserves data |
| FA-10 | Low | Test inventory fixture initially missed `1.1.0` release notes | Fixed; identity negative tests 15/15 |
| FA-11 | Medium | App raises an unhandled libsecret exception and shows no window when no Secret Service provider is running (headless/minimal desktops); package smoke only asserts process liveness | Documented limitation; stock Ubuntu/GNOME and KDE provide a keyring. Fixing requires a wallet rebuild, so it is deferred rather than invalidating the published artifact |

### Code findings resolved in this release

- Exact ERC-20 calldata length enforced; trailing bytes rejected.
- Native Argon2id wired in; fixed production parameters; pure-Dart
  cross-check; no parameter downgrade.
- Zero-address and low-s checks gained direct regression tests after mutation
  testing exposed the gaps.
- Cold/offline signing binds chain, nonce, recipient, value, fees, calldata;
  replay and substitution rejected.
- Release identity is fail-closed; stale hashes, missing checks, dirty trees,
  and ambiguous commits are rejected.

## Operating boundary and residual risk controls

- Run the wallet on a dedicated device or operating-system account, keep the
  OS updated, and use freeze signing, the allowlist, and per-transaction limits.
  A compromised operating system or same-UID attacker can read an unlocked
  session; no software wallet can remove that boundary.
- Use a trusted or self-hosted RPC node, or the Tor/SOCKS route. RPC data is
  not light-client verified, so a malicious provider can mislead the review
  screen; verify large recipients independently.
- Lock the wallet when idle and after use. Dart garbage-collected memory cannot
  be guaranteed zeroized; `mlockall` and non-dumpable process flags are applied
  best-effort on Linux.
- Use cold/offline signing for larger transfers and follow
  `RISK_CONTROLS.md`. Hardware-wallet integration is outside the 1.x scope; no
  independent audit is claimed.
- Android releases remain blocked by the signing-key incident; the Linux
  `.deb` and its data are unaffected.
- A running Secret Service provider (normally gnome-keyring or KWallet) is
  required for the encrypted device secret on a desktop session.
- Startup latency and RSS are recorded as **NOT TESTED** on keyring-less CI
  runners; use a desktop session for performance measurement.

## Final internal assessment

- **Critical findings unresolved in the Linux code:** none found.
- **High code findings unresolved:** none found.
- **Release integrity:** signed artifact; detached signature verified against the published SHA-256.
- **Ordinary Linux use:** internally approved with limitations.
- **Small real-money use:** possible after the user verifies the signed
  artifact and accepts the residual risks.
- **Large-value use:** owner-directed under `RISK_CONTROLS.md`; not an independent certification.

This document is an internal self-audit. It is not an independent professional
security audit and must not be described as one.
