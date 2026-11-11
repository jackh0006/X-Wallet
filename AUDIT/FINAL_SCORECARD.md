# Final scorecard

This is an **internal self-audit**, not an independent audit. Scores are
evidence-capped; blocked/not-run tests earn no credit. The holding-real-money
score is lower than the engineering score by design.

| Category | Weight | Tests performed | Passed | Failed | Blocked | Coverage | Score |
|---|---:|---:|---:|---:|---:|---:|---:|
| Cryptography | 15 | 24 | 24 | 0 | 2 | 80% | 10 |
| Key management | 12 | 18 | 18 | 0 | 3 | 65% | 7 |
| Privacy | 12 | 12 | 12 | 0 | 2 | 70% | 8 |
| Network security | 8 | 9 | 9 | 0 | 2 | 65% | 5 |
| Transaction security | 12 | 28 | 28 | 0 | 1 | 80% | 8 |
| Storage and backups | 8 | 15 | 15 | 0 | 2 | 70% | 5 |
| Android security | 7 | 6 | 6 | 0 | 3 | 45% | 3 |
| Linux security | 5 | 4 | 4 | 0 | 2 | 55% | 3 |
| Dependencies and supply chain | 5 | 5 | 5 | 0 | 1 | 75% | 4 |
| Testing and code quality | 6 | 69 files / 391 decl | 391 | 0 | 1 | 78% | 4 |
| Documentation consistency | 4 | 12 | 10 | 0 | 2 | 60% | 2 |
| Production and release integrity | 6 | 7 | 5 | 0 | 2 | 45% | 2 |
| **TOTAL** | **100** | | | | | | **61** |

## Why points are withheld

- Crypto: no Argon2 RFC 9106/BIP-32 official/Wycheproof vectors; no zeroisation; format is not 2-of-2.
- Key management: Linux device secret is a same-user drawer; mobile keyring behavior is code-fixed but platform-untested; PIN backoff is wall-clock.
- Privacy/network: no packet capture; BscScan key in URL; custom headers not strictly allowlisted; web3dart paths bypass the full RPC choke point.
- Transaction: nonce/`from` not in `SendIntent.verify`; speed-up/cancel unknown outcomes; cold pairing/derivation limits.
- Storage: legacy app-ID dirs survive erase; registry atomicity/concurrency; shared receipts/log.
- Android: no physical-device run; APK debug-signing in CI (upload removed in this branch); native KDF timing unverified.
- Linux: no clean apt install/upgrade/uninstall; no Wayland isolation (X11 forced).
- Dependencies: no Dart SAST; unpinned 1.0.9 deb in CI; gate not strict.
- Testing: 69 files/391 declarations pass, but no coverage-guided fuzzer/soak; some tests use the fast KDF.
- Documentation: tag/evidence/main are not one commit; stale package-smoke/README rows.
- Release: tag ≠ tested code; gate returns 0 for PARTIALLY VERIFIED; artifact hashes not checked in identity CI.

## Scores

- **Overall self-audit: 61/100.**
- **Engineering quality (build/tests/docs/structure): 74/100.**
- **Security assurance for holding real money: 50/100** (unaudited, no independent rebuild, no physical device/cold test).
- **Production status: C (release candidate) not met; F (large amounts) NOT granted.**

No score inflation. A perfect score is not a security guarantee.
