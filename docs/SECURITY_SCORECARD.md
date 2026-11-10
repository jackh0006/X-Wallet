# Security Scorecard

**Date:** 2026-11-07
**Release:** X Wallet `1.4.2+11`
**Tested source commit:** `7e153548c150ba4df7a6bb3945437a3bf58e388a`
**Status:** provisional, internal self-assessment. **This is not an independent
audit.** A score never overrides a release blocker.

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

## Internal self-assessment: 90 / 100

| Category | Weight | Score | Evidence |
|---|---:|---:|---|
| Cryptography and key protection | 20 | 17 | Native Argon2id 64 MiB/t=3/p=4 with pure-Dart cross-check; double-wrapped XChaCha20-Poly1305 vault; device-bound layer; tamper, wrong-password, wrong-device, truncation, and v1-migration tests; legacy pre-1.2 data-directory migration; any-length password with confirmation and strength score; key modules have no network path (`data_boundary_test`) |
| Transaction and blockchain security | 15 | 14 | Exact ERC-20 calldata; chain-ID validation; EIP-1559 codec; fee/nonce/zero-address checks; freeze signing, recipient allowlist, and per-transaction limit; hold-to-confirm; multi-wallet vault with one password; private-key cold signing with replay protection; independent ethers.js cold-signature oracle; real Anvil native and ERC-20 tests |
| Testing, fuzzing and reliability | 15 | 15 | 59 files / 342 declarations; 58/58 default suite pass; deterministic fuzz/property tests; mock-RPC adversarial tests; real Anvil integration; mutation score 5/5; backup E2E; localization, data-boundary, multi-wallet, password-strength, default-token, migration, public-default, and private-key cold tests; hosted CI green |
| Supply chain and CI/CD | 10 | 10 | Pinned action SHAs; CodeQL; OpenSSF Scorecard; secret scan; dependency advisory audit; license inventory; CycloneDX SBOM; least-privilege workflows; signed checksums; published public key |
| Reproducible builds and release integrity | 10 | 9 | Fixed-path reproducible archive and identical file manifests; deterministic gzip; SBOM; release identity validator; signed `SHA256SUMS` verified in a clean keyring; public fingerprint |
| Backup, recovery and operational safety | 10 | 9 | Atomic writes; rollback injection; encrypted backup create/wipe/restore E2E; wrong-password, tamper, and truncation rejection; v1 migration; documented recovery drill |
| Privacy and network security | 5 | 4 | HTTPS-only policy; SPKI pinning after CA/hostname validation; Tor/SOCKS/HTTP proxy with fail-closed routing; User-Agent scrubbing; single HTTP choke point |
| Platform compatibility and performance | 5 | 3 | Ubuntu 24.04 build, `.deb` package smoke, install/launch/upgrade/uninstall, data preservation; KDF measured at 344 ms |
| UI, accessibility and user safety | 5 | 4 | Keyboard hold-to-confirm; semantics; 200% text scale; full-address review; donation separation; spending-safety settings |
| Documentation, transparency and governance | 5 | 5 | Threat model; self-audit; risk-control and data-control records; generated status; manifest; SBOM; PR and CI evidence; signed release; AI review guide; test evidence |
| **Total** | **100** | **90** | |

### What the remaining ten points represent

These are the only uplift areas left in this rubric. They are not defects.

- An independent professional audit (a separate engagement, not claimed).
- Independent-machine build attestation and a second-path build.
- Debian and other distribution package smoke tests.
- A full interactive screen-reader and display session.
- Coverage-guided fuzzing and a long-running soak test.

## OpenSSF Scorecard (automated)

The workflow is `.github/workflows/scorecard.yml`; the badge in the README
links to the live OpenSSF viewer. The score and per-check details are updated
by the workflow on `main` after each release commit.

Recorded prior baseline: **7.1 / 10**. Strong checks at the maximum score
include CI-Tests, SAST (CodeQL), Vulnerabilities, License, Security-Policy,
Binary-Artifacts, Dangerous-Workflow, Dependency-Update-Tool,
Token-Permissions, and Pinned-Dependencies.

## Evidence pointers

- [Test evidence](TEST_EVIDENCE.md)
- [AI and human review guide](AI_REVIEW.md)
- [Final self-audit](FINAL_SELF_AUDIT.md)
- [Risk controls](RISK_CONTROLS.md)
- [Data control and AI boundary](DATA_CONTROL.md)
- [Release evidence](RELEASE_EVIDENCE.md)
- [Signing key](keys/README.md)
- `release/evidence.json`, `release/manifest.json`, `docs/SBOM.json`

## Release blockers regardless of score

1. Android historical signing key not rotated
   (`docs/security/INCIDENT_2026-11-KEYSTORE.md`).
2. Full interactive clean-desktop test and non-Ubuntu installs not yet run.
3. No independent security audit is claimed.
4. Startup/RSS benchmark not measured on a runner with a Secret Service
   provider.

## What raised the score honestly

- Owner-signed artifact with a published fingerprint and verified detached
  signature.
- Fixed-path reproducible archive with identical file manifests.
- Real-EVM Anvil integration tests.
- Mutation testing and a complete test inventory.
- CodeQL, OpenSSF Scorecard, SBOM, dependency review, secret scan, and pinned
  actions.
- Data-boundary tests proving no telemetry/AI SDK and no network path inside
  key-handling modules.
- Spending safety controls and cold/offline signing guidance.

## What would raise the score further

- Independent professional security audit.
- Independent-machine rebuild and a published build-provenance attestation.
- Clean-install CI on Debian 12 and a full interactive desktop session.
- Coverage-guided fuzzing and a long-running soak test.
- Android key rotation and denylist verification.

## What would not raise the score

- Re-labeling the same tests.
- Removing a failing check.
- Claiming a platform works because it compiles.
- Claiming an audit that did not happen.
- Lowering KDF parameters for speed.
- Claiming a score without citing evidence.
