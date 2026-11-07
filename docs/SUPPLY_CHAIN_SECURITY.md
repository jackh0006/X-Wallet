# Supply-Chain Security

**Last reviewed:** 2026-11-06
**Source commit:** `3aef4b908fded5e92823c76f02d4016265c8bf12`

## Controls

| Control | Implementation | Evidence |
|---|---|---|
| Dependency pinning | `pubspec.lock`, `verification/package-lock.json` | committed lockfiles; hashes in `release/manifest.json` |
| GitHub Actions pinning | Full commit SHAs for every third-party action | `.github/workflows/*` |
| Least privilege | Per-workflow `permissions:`; no write token in PR jobs | workflow files |
| Secret scanning | `scripts/secret-scan.sh` current tree + history report | CI `secret-scan` |
| Static analysis | `flutter analyze`, CodeQL (Actions/C++/JS/Python) | CI |
| Dependency review | `actions/dependency-review-action` | PR `review` |
| Advisory audit | `scripts/dependency-audit.py` | CI `flutter` job |
| License inventory | `scripts/license-check.py` | CI |
| SBOM | `scripts/sbom.py` (116 packages) | `docs/SBOM.json` |
| Provenance | `actions/attest-build-provenance` + `attest-sbom` on tag builds | `.github/workflows/release-build.yml` |
| Reproducibility | Fixed-path two-build comparison | `scripts/reproducibility-check.sh` |
| Release gate | `scripts/release-gate.py` | local/CI |
| Update automation | Dependabot for pub, npm, actions | `.github/dependabot.yml` |

## Trust boundaries

- The release signing key is not in the repository and must be held by the
  owner on an approved host.
- The Android historical keystore is compromised and denylisted; no APK may be
  published.
- A build from source is not automatically the same as the shipped binary;
  provenance and reproducibility are separate claims.
- Pinning an action SHA prevents tag movement but does not prove the action is
  vulnerability-free.

## Gaps

- Dependabot PRs #2–#6 are unreviewed.
- No published artifact attestation for the candidate `.deb`.
- Reproducibility is proven only at a fixed path on one machine; an independent
  builder is still required.
- No independent audit of dependencies or build scripts.
- CodeQL does not analyze Dart; `flutter analyze` and tests cover that layer.

## Rules for contributors

1. Never add a dependency without reviewing purpose, license, maintenance, and
   advisory history.
2. Never weaken a scan, pin, or permission to make CI green.
3. Regenerate the SBOM and manifest after dependency changes.
4. Never add a GitHub Action by tag; use a reviewed full SHA.
5. Never put a signing key or credential in source, logs, or CI output.
