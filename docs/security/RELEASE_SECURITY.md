# RELEASE_SECURITY.md — Linux Release Signing and Distribution Security

**Date**: 2026-11-03
**Baseline Commit**: `68091b06cce3e9c90692e3f632d539ae69734154`

---

## Historical Android Credential Exposure (Not a Linux Release Credential)

**The old Android release keystore (`scripts/release.keystore`) and its predictable password were committed to public Git history.**

| Artifact | Status | Action Required |
|----------|--------|-----------------|
| `scripts/release.keystore` | **REMOVED from tree** (commit `68091b0`) | **TREAT AS COMPROMISED** |
| Predictable hardcoded release password (year and local username) | **REMOVED** | **TREAT AS COMPROMISED** |
| Git history | **CANNOT REWRITE** (public, no force-push) | Document; rotate key |

**Status of rotation**: **NOT VERIFIED.** A clean current-tree scan proves only
that the tracked source tree no longer contains the material. It does not
prove the exposed credential has been invalidated, that the private key is no
longer usable elsewhere, or that any published artifact has been replaced.

This is historical public-repository exposure only. It is not used for Linux
packages and no Android build, signing, rotation, or distribution work is in
the active release scope. Treat the old material as compromised permanently.

### Android build gate (blocked until rotation)

`scripts/build-apk.sh` now requires all of the following and fails closed:

1. `BNB_EXPECTED_SIGNER_SHA256` — the approved replacement certificate
   SHA-256.
2. `BNB_RELEASE_OWNER_APPROVED=1` — explicit owner approval after the incident
   runbook is complete.
3. `release/android-signer-denylist.txt` — at least one confirmed compromised
   fingerprint. An empty denylist cannot prove an artifact is not signed by
   the old identity.
4. `scripts/verify-android-signer.sh` — verifies the built APK against the
   allowlist and denylist.

Until the historical fingerprint is recorded and a replacement key is
approved, no Android artifact may be built or published. The full timeline
and owner actions are in
[`INCIDENT_2026-11-KEYSTORE.md`](INCIDENT_2026-11-KEYSTORE.md).

---

## Linux .deb Signing (`scripts/build-deb.sh`)

### Output

- `x-wallet-<version>-amd64.deb`
- `SHA256SUMS` (SHA-256 checksum)
- Optional `.deb.asc` (GPG detached signature)

### GPG Signing

```bash
# Set only on the maintainer-controlled release host:
export BNB_GPG_KEY='approved key fingerprint or UID'
gpg --batch --yes --digest-algo SHA256 \
  --default-key "$BNB_GPG_KEY" \
  --detach-sign --armor "$DEB"
```

- **Key management**: GPG key held by maintainer (not in repo)
- **Verification**: `gpg --verify x-wallet-*.deb.asc x-wallet-*.deb`
- **No key available**: the build script still emits a checksum-marked,
  explicitly unsigned diagnostic package. It is not releaseable.

---

## Secret Scanning (CI + Local)

### `scripts/secret-scan.sh` — Runs in GitHub Actions

**Checks**:
1. **Tracked keystores**: `*.jks`, `*.keystore`, `*.p12`, `*.pfx`, `*.pem`, `*.key`
2. **PEM private key blocks**: `-----BEGIN *PRIVATE KEY-----` in tracked files
3. **Old password pattern**: current-tree scan; `bash scripts/secret-scan.sh --history` separately reports the historical exposure without printing it
4. **Inline signing passwords**: `storePassword`/`keyPassword` with values
5. **Hardcoded 32-byte keys**: `privateKey`/`secretKey`/`seedPhrase` = 64 hex chars

**Pass Criteria**: The default current-tree mode has zero matches. The
`--history` inventory may report the known public exposure and is not evidence
of credential rotation.

### `.gitignore` Protection

```
*.keystore
*.jks
*.p12
*.pfx
key.properties
release-signing/
/dist/
*.apk
*.aab
*.deb
*.bak
/test_*.dart
/bin/investigate*.dart
/bin/verify_signature.dart
```

---

## SBOM (Software Bill of Materials)

### Generation

```bash
python3 scripts/sbom.py --out docs/SBOM.json
```

### Contents

- Every dependency from `pubspec.lock` + `verification/package-lock.json`
- Version + SHA-256 of each package
- License classification
- Deterministic (same lockfile = same SBOM)

### CI Enforcement

```yaml
# .github/workflows/verify.yml
- run: python3 scripts/sbom.py --out docs/SBOM.json
- name: SBOM must be committed and current
  run: git diff --exit-code docs/SBOM.json
```

---

## Release Procedure (Security Checklist)

### Pre-Release

- [ ] Version bump in `pubspec.yaml`
- [ ] `flutter analyze --no-pub` → no errors
- [ ] `bash scripts/test-suite.sh` → all pass (non-KDF 209, KDF individually)
- [ ] `bash scripts/secret-scan.sh` → clean
- [ ] `cd verification && npm ci && node verify.cjs` → pass
- [ ] `python3 scripts/license-check.py` → all locked packages have license text
- [ ] `python3 scripts/sbom.py --out docs/SBOM.json` → committed
- [ ] `git diff --exit-code docs/SBOM.json` → clean
- [ ] Update `CHANGELOG.md`

### Linux .deb Release

- [ ] `BNB_GPG_KEY=<approved key> bash scripts/build-deb.sh` → produces `.deb`, `SHA256SUMS`, `.asc`
- [ ] Install on clean Ubuntu 22.04/24.04 amd64 VM
- [ ] Smoke test: launch, vault create/unlock, send, network modes
- [ ] `dpkg -c x-wallet-*.deb` → no secrets, correct permissions
- [ ] `gpg --verify x-wallet-*.deb.asc x-wallet-*.deb`

### Git Tag & Push

- [ ] `git tag -s v1.x.y -m "Release v1.x.y"` (GPG signed tag)
- [ ] `git push origin main --tags`
- [ ] GitHub Release: upload `.deb`, `SHA256SUMS`, `.asc`
- [ ] Verify GitHub release artifacts match local checksums

---

## Reproducible Builds (Target)

| Component | Status | Notes |
|-----------|--------|-------|
| **Flutter/Dart toolchain pin** | NOT DONE | Need `FLUTTER_VERSION`, `DART_SDK` pins |
| **Linux build environment** | NOT DONE | Docker image with pinned packages |
| **Independent rebuild verification** | NOT TESTED | Compare two builds byte-for-byte |
| **SBOM determinism** | ✅ DONE | `scripts/sbom.py` from lockfile |

---

## Supply Chain Security

| Practice | Status |
|----------|--------|
| **Dependency pinning** | `pubspec.lock` + `package-lock.json` committed |
| **Vulnerability scanning** | `scripts/dependency-audit.py` plus npm audit in CI; results are only valid when the networked scan completes |
| **License compliance** | NOT VERIFIED: the SBOM records npm license fields when present but is not a complete license-policy scan |
| **No proprietary core deps** | ✅ Core wallet uses only OSS |
| **Contribution policy** | `CONTRIBUTING.md` |
| **Vulnerability reporting** | `SECURITY.md` (jackh109867@gmail.com) |

---

## Evidence Locations

| Artifact | Location |
|----------|----------|
| Build script | `scripts/build-deb.sh` |
| Secret scan | `scripts/secret-scan.sh` |
| SBOM generator | `scripts/sbom.py` |
| SBOM output | `docs/SBOM.json` |
| CI workflow | `.github/workflows/verify.yml` |
| Gitignore | `.gitignore` |
| Release keystore (old) | **REMOVED** (was `scripts/release.keystore`) |

---

## Key Rotation Record

| Date | Key ID | Algorithm | Status | Notes |
|------|--------|-----------|--------|-------|
| ~2026-10 | Old Android release keystore | RSA-2048 | **COMPROMISED** | Historical public exposure; not a Linux credential |

---

*This document describes Linux release security practices. The old Android
keystore remains a historical compromise, not an active Linux work item.*

## Release signer identity is mandatory

Before publishing a Linux package, record the public GPG fingerprint in the
release evidence, create a detached signature with the maintainer-controlled
key, and verify that exact fingerprint in a separate trust context. No private
signing material belongs in this repository. In this workspace no authorized
Linux signing key has been verified, so signing remains **NOT VERIFIED**.
