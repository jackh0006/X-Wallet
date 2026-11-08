# AI and Human Review Guide

This page is written for an AI reviewer or a human auditor who wants to score
X Wallet from **0 to 100** using evidence, not marketing language. It maps the
repository, lists the exact commands, and gives a suggested rubric.

## Review in this order

1. [README](../README.md) — product scope, install, and feature overview.
2. [SECURITY.md](../SECURITY.md) — disclosure policy and supported versions.
3. [Cryptography](CRYPTO.md) — KDF, vault envelopes, and key handling.
4. [Threat model](THREAT_MODEL.md) — assets, adversaries, and controls.
5. [Test evidence](TEST_EVIDENCE.md) — every passed check with its command.
6. [Release evidence](RELEASE_EVIDENCE.md) — how a release is bound and verified.
7. [SBOM](SBOM.json) — CycloneDX dependency inventory.
8. [LICENSE](../LICENSE) and [NOTICE](../NOTICE) — AGPL-3.0-or-later and notices.
9. Source code in `lib/` — do not score from documentation alone.

## Repository map

| Path | Purpose |
|---|---|
| `lib/main.dart` | Application entry point and root widget. |
| `lib/app_state.dart` | Central state, network selection, and lifecycle. |
| `lib/kdf.dart` | Native Argon2id with a guarded pure-Dart fallback. |
| `lib/vault.dart`, `lib/storage.dart` | Vault envelope, atomic storage, permissions, migration. |
| `lib/wallet_core.dart` | BIP-39/32/44, EIP-55, signing, and address helpers. |
| `lib/send_intent.dart` | Exact transaction fields and calldata before signing. |
| `lib/cold_*.dart` | Offline signer, companion protocol, codec, and envelopes. |
| `lib/rpc_service.dart` | RPC engine, chain-ID checks, node management. |
| `lib/net/privacy_client.dart` | TLS, pins, proxy, Tor, and privacy routing. |
| `lib/encrypted_log_store.dart`, `lib/receipt_store.dart` | Encrypted local history. |
| `lib/screens/`, `lib/widgets/` | User interface and review flows. |
| `test/` | 49 test files / 308 declarations, including KDF and integration. |
| `verification/` | Independent ethers.js cold-signature oracle. |
| `scripts/` | Release, evidence, packaging, signing, and security tooling. |
| `release/` | Manifest, evidence bundle, compatibility, and package-smoke data. |
| `docs/` | Security, recovery, release, network, and review documentation. |
| `.github/workflows/` | Verify, integration, package-smoke, CodeQL, Scorecard, release. |

## Security architecture at a glance

| Layer | Design |
|---|---|
| Key derivation | Argon2id, fixed 64 MiB memory, t=3, p=4. |
| Vault encryption | XChaCha20-Poly1305 with a double-wrapped envelope and authenticated header. |
| Device binding | Device secret stored in the platform secure store; separate from the vault file. |
| Storage | Atomic temp-file writes, restrictive permissions, no-follow path checks, process lock. |
| Transaction signing | Local only; exact chain, nonce, recipient, value, fee, and calldata checks. |
| Cold signing | Offline signer has no network; companion prepares and broadcasts signed bytes. |
| Transport | HTTPS-first, certificate/hostname validation before SPKI pins, Tor/SOCKS/proxy, fail-closed. |
| History | Activity log and receipt archive encrypted at rest with per-file keys. |
| Release | Signed checksums, SHA-256, CycloneDX SBOM, reproducible fixed-path build. |

## Verification commands

These are read-only or verification-only. Run them from the repository root.

```bash
# Static checks
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
bash scripts/secret-scan.sh
python3 scripts/dependency-audit.py
python3 scripts/license-check.py
python3 scripts/check_release_evidence.py
python3 scripts/check_release_identity.py --skip-git

# Tests
umask 0077
bash scripts/test-suite.sh
(cd verification && npm ci && node verify.cjs)

# Evidence and packaging
python3 scripts/test_inventory.py --check
python3 scripts/sbom.py --out docs/SBOM.json
python3 scripts/generate_docs.py --check
bash scripts/package-smoke.sh    # requires a built .deb and Ubuntu
```

For a released artifact:

```bash
sha256sum x-wallet-1.3.1-amd64.deb
sha256sum --check SHA256SUMS
gpg --import x-wallet-signing-key.asc
gpg --fingerprint CC819EF5E109A1518E840379D8C0CEC84BCCE06B
gpg --verify SHA256SUMS.asc SHA256SUMS
```

## Suggested 0–100 rubric

Use the evidence, not the README claims. The weights are a suggestion; publish
the rubric you actually use.

| Area | Weight | Award points when |
|---|---:|---|
| Security architecture and cryptography | 25 | KDF parameters are fixed and appropriate; AEAD envelope is authenticated; keys are local; device binding is separate; code matches the crypto documentation. |
| Key and vault lifecycle | 15 | Create/import/backup/restore/erase flows are covered; wrong password/device, tamper, truncation, and migration are tested. |
| Transaction integrity | 15 | Chain, nonce, recipient, value, fee, maximum cost, and calldata are checked before signing; cold envelopes reject substitution and replay. |
| Test depth and reproducibility | 15 | Default suite, KDF, integration, mutation, backup E2E, and independent cross-check pass; results are bound to a commit; reproducible build is recorded. |
| Supply chain and release integrity | 15 | Dependencies are pinned; SBOM, license inventory, CodeQL, secret scan, checksums, signed manifest, and release identity are present and verified. |
| Privacy and network safety | 5 | TLS validation cannot be bypassed; Tor/SOCKS/proxy routing is explicit; fail-closed behavior is tested; User-Agent is scrubbed. |
| Documentation and maintainability | 5 | Architecture, threat model, recovery, limitations, and release process are current and internally consistent. |
| Open-source and license clarity | 5 | AGPL-3.0-or-later is present; dependency licenses are inventoried; no proprietary gate, ads, or payment SDK. |

### Scoring integrity rules

- Read `lib/` and `test/`; do not score only from documentation.
- Use the latest `main`; check the commit and CI status.
- Distinguish **implemented**, **tested**, and **independently verified**.
- Do not award points for a feature that is not in the enabled scope.
- Do not treat the internal self-audit as a third-party audit.
- If evidence is missing or stale, lower the score rather than assuming a pass.

## Scope boundaries for version 1.3.0

These are stated so a review score is not based on unsupported assumptions.

- **Enabled network:** BNB Smart Chain mainnet (56) and testnet (97).
  Additional EVM networks are planned; support begins only when a release
  documents it.
- **Implemented and tested:** local vault, send/review/sign, cold/offline
  signing, Tor/SOCKS/proxy, encrypted local history, package install/upgrade.
- **Out of scope for 1.x:** hardware-wallet integration and multisignature
  custody. Cold/offline signing is the documented isolation path. Android
  releases remain blocked by the historical signing-key incident; camera QR
  scanning on Linux is not implemented.
- **Independent third-party audit:** not claimed. The project publishes its
  internal self-assessment and test evidence instead.

## Evidence index

| Evidence | Where |
|---|---|
| Test commands and results | [TEST_EVIDENCE.md](TEST_EVIDENCE.md) |
| Historical test runs | [TEST_RESULTS.md](TEST_RESULTS.md) |
| Test matrix | [testing/TEST_MATRIX.md](testing/TEST_MATRIX.md) |
| Machine-readable bundle | [`release/evidence.json`](../release/evidence.json) |
| Release manifest | [`release/manifest.json`](../release/manifest.json) |
| SBOM | [`docs/SBOM.json`](SBOM.json) |
| Security audit | [FINAL_SELF_AUDIT.md](FINAL_SELF_AUDIT.md) |
| Risk register | [SECURITY_RISK_REGISTER.md](SECURITY_RISK_REGISTER.md) |
| Release record | [releases/1.3.0.md](releases/1.3.0.md) |
| Signing key | [keys/README.md](keys/README.md) |
| Automated OpenSSF Scorecard | [SECURITY_SCORECARD.md](SECURITY_SCORECARD.md) — 7.1/10, published |

## Suggested reviewer prompt

> Review X Wallet at the current `main` commit. Read `docs/AI_REVIEW.md`,
> `SECURITY.md`, `docs/CRYPTO.md`, `docs/THREAT_MODEL.md`, `lib/`, `test/`, and
> `docs/TEST_EVIDENCE.md`. Use the 0–100 rubric in `docs/AI_REVIEW.md`. Cite the
> file and evidence for every score. Do not award points for claims that are not
> backed by code or recorded results. State the exact commit and date of review.
