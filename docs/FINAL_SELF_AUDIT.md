# X Wallet — Final Internal Self-Audit

**Scope:** X Wallet `1.1.0+5`, code/test commit
`0cd7cd6ccc390abeb66d973f79dd5ec9c16d0f54`, final published tree at the
`v1.1.0` tag.
**Date:** 2026-11-07
**Audit type:** internal self-audit performed by the project's AI-assisted
engineering process. **This is not an independent external audit.**

## Executive assessment

No unresolved Critical or High **code** defect was found in the Linux wallet
release scope. The release remains limited by owner-controlled signing, the
historical Android signing incident (Android is out of scope for this Linux
release), the absence of an independent audit, and the absence of
hardware-wallet/multisig custody.

**Ordinary Linux wallet use:** internally approved, with the documented
limitations. **Large-value custody: NOT APPROVED.**

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
| Default suite | 48/48 files, 0 failed, 0 timed out, 631 s |
| Real EVM (Anvil 1.9.0, chain 97) | 3/3 PASS |
| Mutation testing | 5/5 killed |
| Backup/restore E2E | 4/4 PASS |
| Release signing tools | 6/6 PASS (disposable test key) |
| Release identity negative tests | 15/15 PASS |
| Android signer inventory | PASS (synthetic keystore) |
| Package smoke | PASS: install, upgrade from `bnb-wallet` 1.0.9, launch, uninstall, reinstall |
| Cross-runner reproducibility | PASS at a fixed build path (run 42315071276) |
| Startup/RSS benchmark | NOT VERIFIED — headless runner has no Secret Service; app raises an unhandled libsecret exception and no window appears |
| Secret scan / dependency / license / SBOM | PASS |
| Release identity validator | PASS |
| Release gate | PARTIALLY VERIFIED — only `deb-signature` missing |

## Findings

| ID | Severity | Finding | Status |
|---|---|---|---|
| FA-01 | High | Historical Android release keystore exposed; rotation not verified | Open owner action; Android blocked; Linux `.deb` unaffected |
| FA-02 | High | Release `.deb` initially unsigned | **Resolved**: signed with owner key `CC819EF5E109A1518E840379D8C0CEC84BCCE06B`; `SHA256SUMS.asc` verified in a clean keyring (2026-11-07) |
| FA-03 | High | No independent external audit | Accepted limitation; explicitly not claimed |
| FA-04 | High | Hardware-wallet support absent | Documented `NOT IMPLEMENTED`; large-value custody not approved |
| FA-05 | High | Reviewed multisignature custody absent | Documented `NOT IMPLEMENTED`; no custom contract deployed |
| FA-06 | Medium | Cross-runner reproducibility / startup-RSS workflows not executed | Reproducibility now PASS (run 42315071276); benchmark NOT VERIFIED (see FA-11) |
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

## Remaining limitations

- A compromised operating system or same-UID attacker can read an unlocked
  wallet; no secure element.
- RPC data is not light-client verified; a malicious provider can mislead the
  review screen.
- Dart garbage-collected memory cannot be securely erased; `mlockall` is
  best-effort.
- No hardware wallet, no multisig, no independent audit.
- Android remains blocked by the signing-key incident.
- A running Secret Service provider (gnome-keyring or KWallet) is required;
  minimal/headless sessions without one currently fail at startup.
- Startup latency and RSS are **NOT VERIFIED** under the CI benchmark because
  that runner has no keyring.

## Final internal assessment

- **Critical findings unresolved in the Linux code:** none found.
- **High code findings unresolved:** none found.
- **Release integrity:** signed artifact; detached signature verified against the published SHA-256.
- **Ordinary Linux use:** internally approved with limitations.
- **Small real-money use:** possible after the user verifies the signed
  artifact and accepts the residual risks.
- **Significant holdings / large-value custody: NOT APPROVED.**

This document is an internal self-audit. It is not an independent professional
security audit and must not be described as one.
