# Security scorecard — X Wallet 1.6.0

**Date:** 2026-11-12
**Release:** X Wallet `1.6.0+18`
**Status:** internal self-assessment. **This is not an independent audit.**
A score never overrides a release blocker.

## Scoring rules

- Every point must cite evidence.
- No credit for unimplemented features.
- Mock-only tests are not real-network integration.
- A failed reproducibility check gets no reproducibility credit.
- A missing or incorrect signature gets no signed-release credit.
- A self-audit gets no independent-audit credit.
- An untested platform gets no compatibility credit.
- Any critical/high unresolved finding blocks production approval regardless of
  score.

## Internal self-assessment: 70 / 100

| Category | Weight | Score | Evidence |
|---|---:|---:|---|
| Cryptography and key protection | 20 | 13 | Argon2id 64 MiB/t=3/p=4, XChaCha20-Poly1305, authenticated header, KDF floors, v1 read, portable backups. The device secret is defense-in-depth, not a required second factor; no zeroisation; official BIP-32/39 vector files are still missing. |
| Transaction and blockchain security | 15 | 11 | Exact review binding now includes nonce and sender, chain ID, EIP-1559, hold-to-confirm, ERC-20 spender/unlimited decoding, cancel fix, uncertain-broadcast persistence, BNB/Ethereum chain binding. The cold path still does not consult the spending policy; Ethereum has no live-node run yet. |
| Testing, fuzzing and reliability | 15 | 12 | 73 test files / 395 declarations, deterministic fuzz/property tests, real Anvil integration, vault tamper and backup tests, new hardening regressions. No coverage-guided fuzzer or 30–60 min soak. |
| Supply chain and CI/CD | 10 | 8 | Pinned action SHAs, CodeQL (no Dart), secret scan, dependency advisory audit, licence inventory, CycloneDX SBOM, least privilege, strict source gate and post-release asset verification. Android CI still uses a debug signing config. |
| Reproducible builds and release integrity | 10 | 6 | Signed `.deb`/APKs and matching hashes. Strict `--require-source` gate, post-release asset verifier, fixed-path reproducibility only; no independent-machine rebuild. |
| Backup, recovery and operational safety | 10 | 8 | Portable `BNBBKP01` backup restores on a fresh device; wrong-password/tamper/truncation tests; atomic writes and rollback. No crash/ENOSPC fault injection. |
| Privacy and network security | 5 | 3 | Startup transport rebuild, cold-mode gate, prices off by default, node credentials in secure storage, 2 MiB cap and method allowlist, stricter custom-header rejection. No packet capture or OS-enforced air gap in CI. |
| Platform compatibility and performance | 5 | 2 | Ubuntu 24.04 build and package smoke. Android 1.6.0 APK is signed but not run on a device; no Debian/Fedora clean-install CI. |
| UI, accessibility and user safety | 5 | 3 | Hold-to-confirm, full-address review, donation separation, vault manager. No real screen-reader session and no anti-phishing phrase. |
| Documentation, transparency and governance | 5 | 4 | Claim register, proof matrix, honest limitations, threat model, SBOM, release evidence. Some older documents still contain stale counts and claims. |
| **Total** | **100** | **70** | |

The previous 91/100 was not supportable: it counted unproven offline,
device-binding and backup claims, stale test counts, and a non-strict release
gate. The evidence-backed score before this release was approximately 58. The
1.6.0 adds Ethereum and per-chain configuration; the total stays
70/100 because no independent audit, independent rebuild or physical-device
test was added.

## Release blockers regardless of score

1. No independent professional security audit.
2. No independent-machine rebuild or external attestation.
3. No physical two-device cold-signing test.
4. No real screen-reader/assistive-technology session.
5. Android 1.5.3 has not been run on a physical device (only built and
   signature-verified).
6. Cold-path spending-policy enforcement remains open.
7. The release gate is strict, but Android CI still uses a debug signing config
   and the release assets are built locally, not by CI.

## What would raise the score further

- Independent audit and a published remediation record.
- Independent rebuild with matching hashes.
- Physical cold-signing and Android device tests.
- Coverage-guided fuzzing, a soak test, and crash/ENOSPC fault injection.
- Strict release gate, Dart SAST, and release-signed Android CI.
- Packet-capture evidence for the privacy claims.

## What would not raise the score

- Re-labelling the same tests.
- Removing a failing check.
- Claiming a platform works because it compiles.
- Claiming an audit that did not happen.
- Lowering KDF parameters for speed.
- Claiming a score without citing evidence.
