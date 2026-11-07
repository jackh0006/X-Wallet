# Security Scorecard

**Date:** 2026-11-07
**Release source commit:** `1b4800757ce953b3af400680b2a12da348314a1c`
**Reviewed main:** `80d441d29a5b04e830c128ee269155d961d93603`
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

## Provisional score: 83 / 100

| Category | Weight | Score | Evidence | Why not full |
|---|---:|---:|---|---|
| Cryptography and key protection | 20 | 16 | Native Argon2id + pure-Dart cross-check; fixed 64 MiB/t=3/p=4; double-wrapped vault; tamper/wrong-password/v1-migration tests; no plaintext logs | No independent audit; no hardware-backed key; Dart memory cannot be securely erased; same-UID malware remains out of scope |
| Transaction and blockchain security | 15 | 12 | Exact ERC-20 calldata; chain-ID validation; EIP-1559 codec; fee/nonce/zero-address checks; signature verification; independent ethers.js check; real Anvil native/ERC-20 tests | No token-approval UI (scope); RPC data is not light-client verified |
| Testing, fuzzing and reliability | 15 | 14 | 51 files / 313 declarations; deterministic fuzz/property; mock-RPC adversarial; real Anvil integration; mutation score 5/5; backup E2E; UI/a11y; hosted CI green | No coverage-guided fuzzing; no long-running soak |
| Supply-chain and CI/CD | 10 | 9 | Pinned action SHAs; CodeQL; OpenSSF Scorecard; secret scan; dependency review; license inventory; SBOM; least-privilege workflows | Dependabot PRs remain maintainer-reviewed; no independent rebuild |
| Reproducible builds and release integrity | 10 | 8 | Fixed-path and cross-runner reproducible archives; deterministic gzip; SBOM; release gate; signed `SHA256SUMS`; public signing key | Different absolute paths differ; no independent-machine proof; no published build-provenance attestation |
| Backup, recovery and operational safety | 10 | 8 | Atomic writes; rollback; encrypted backup create/wipe/restore E2E; wrong-password/tamper/truncation; v1 migration | No clean-machine UI restore; disk-full/power-loss coverage incomplete |
| Privacy and network security | 5 | 4 | HTTPS-only policy; SPKI pinning after CA validation; Tor/SOCKS fail-closed; UA scrubbing | No light-client proof; traffic analysis and compromised OS remain out of scope |
| Platform compatibility and performance | 5 | 3 | Ubuntu 24.04 build + `.deb`; package-smoke install/launch/upgrade/uninstall; KDF measured (344 ms) | No startup/RSS; Debian/Fedora/ARM64/Windows/macOS untested |
| UI, accessibility and user safety | 5 | 4 | Keyboard hold-to-confirm; semantics; 200% text scale; full address review; donation separation | No screen-reader session or real display test; warning UX not independently evaluated |
| Documentation, transparency and governance | 5 | 5 | Threat model; known limitations; incident record; generated status; manifest; PR evidence; signed release; AI review guide; test evidence | — |
| **Total** | **100** | **83** | | |

## OpenSSF Scorecard (automated)

Run: `2026-11-07` on commit `af13e45b828559e975d372da3ff566ac3a16dd86`.

**Score: 7.1 / 10**

Strong checks at the maximum score:

- CI-Tests
- SAST (CodeQL)
- Vulnerabilities
- License
- Security-Policy
- Binary-Artifacts
- Dangerous-Workflow
- Dependency-Update-Tool
- Token-Permissions
- Pinned-Dependencies

The workflow, SARIF report, and per-check details are in
`.github/workflows/scorecard.yml` and the repository's code-scanning results.
The badge in the README links to the live OpenSSF viewer.

## Evidence pointers

- [Test evidence](TEST_EVIDENCE.md)
- [AI and human review guide](AI_REVIEW.md)
- [Final self-audit](FINAL_SELF_AUDIT.md)
- [Release evidence](RELEASE_EVIDENCE.md)
- [Signing key](keys/README.md)
- `release/evidence.json`, `release/manifest.json`, `docs/SBOM.json`

## Blockers regardless of score

1. Android historical signing key not rotated (`docs/security/INCIDENT_2026-11-KEYSTORE.md`).
2. Full interactive clean-desktop test and non-Ubuntu installs not tested.
3. No independent security audit.
4. Hardware wallet and multisignature custody not implemented.
5. Startup/RSS benchmark not measured on a runner with a Secret Service provider.

## What raised the score honestly

- Owner-signed artifact with a published fingerprint and verified detached signature.
- Cross-runner reproducibility at a fixed path.
- Anvil/real-EVM integration tests.
- Mutation testing and a complete test inventory.
- CodeQL, Scorecard, SBOM, dependency review, secret scan, and pinned actions.
- Consolidated, current documentation and an AI/human review guide.

## What would raise the score further

- Independent professional security audit.
- Independent rebuild and published build-provenance attestation.
- Clean-install CI on Ubuntu 24.04 and Debian 12.
- Coverage-guided fuzzing and a long-running soak test.
- Android key rotation and denylist verification.
- Hardware-wallet and reviewed multisignature custody.

## What would not raise the score

- Re-labeling the same tests.
- Removing a failing check.
- Claiming a platform works because it compiles.
- Claiming an audit that did not happen.
- Lowering KDF parameters for speed.
- Claiming a score without citing evidence.
