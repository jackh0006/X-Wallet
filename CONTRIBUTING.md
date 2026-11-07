# Contributing to X Wallet

Thanks for helping. This is a non-custodial wallet: a mistake can cost real
money. Read this file, [`AGENTS.md`](AGENTS.md),
[`SECURITY.md`](SECURITY.md), and
[`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md) before changing anything.

License: AGPL-3.0-or-later. By contributing you agree your work is licensed
under the same terms.

## Mandatory rules

1. **Never commit a secret.** No recovery phrase, private key, keystore,
   password, API key, signing material, or real wallet fixture. Use the
   deterministic public test fixtures in `test/`.
2. **Never invent evidence.** Do not write "tested", "verified", "audited", or
   a score unless a command in this repository produced that result for the
   exact commit. A timeout, OOM, or interrupted run is `FAILED` or
   `INCOMPLETE`, never a pass.
3. **Never weaken cryptography to get green tests.** Production Argon2id is
   fixed at 64 MiB, t=3, p=4. Tests may use the assert-guarded test KDF for
   envelope/format coverage, but a real production-parameter test must remain.
4. **Every new behavior needs a test.** Add it to the appropriate suite and
   regenerate `docs/testing/test-inventory.json` and `TEST_MATRIX.md`.
5. **Every dependency change needs review.** Run the advisory and license
   inventories, regenerate the SBOM, and explain why the dependency is needed.
6. **Every PR explains security impact.** State what can go wrong, what you
   changed to prevent it, and which tests prove it.
7. **Do not bypass branch protection or required checks.** A failing check is
   a blocker, not a suggestion.
8. **Do not publish a release.** The maintainer signs and publishes; Android
   remains blocked until the historical keystore incident is closed.

## Required local verification

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
bash scripts/test-suite.sh
bash scripts/secret-scan.sh
(cd verification && npm ci && node verify.cjs)
python3 scripts/dependency-audit.py
python3 scripts/license-check.py
python3 scripts/sbom.py --out docs/SBOM.json
python3 scripts/test_inventory.py --check
python3 scripts/check_release_evidence.py
python3 scripts/release_manifest.py --check
python3 scripts/generate_docs.py --check
python3 scripts/release-gate.py
```

`release-gate.py` reports `VERIFIED`, `PARTIALLY VERIFIED`, `INCOMPLETE`, or
`FAILED`. Do not describe a version as confirmed unless the gate says
`VERIFIED` for its exact commit and artifacts.

## KDF and test performance

The vault uses the reference native Argon2 library when available
(`lib/kdf.dart`), with a pure-Dart fallback. The native path is measured by
`test/kdf_production_test.dart`; it must stay under the guard there. Envelope
tests use `VaultCipher.debugKdfOverride`, which is compiled out of release
builds. Never lower the production parameters.

Suites tagged `kdf` are serial and get the long watchdog in
`scripts/test-suite.sh`. Do not run two `flutter test` processes at once on a
small machine: that has caused native test-device segmentation faults.

## Pull request checklist

- [ ] I read the threat model and the relevant security docs.
- [ ] The change has tests, and the test inventory is regenerated.
- [ ] Static analysis, formatting, and the full suite pass locally.
- [ ] Secret scan and dependency/license checks pass.
- [ ] SBOM and release manifest are current.
- [ ] I reviewed the security impact and wrote it in the PR.
- [ ] I did not add or expose any secret.
- [ ] I did not weaken a security check to make CI green.

## Reporting a vulnerability

Do not open a public issue. Email **jackh109867@gmail.com** with the version,
commit, and a minimal reproduction. Never include a seed phrase or private key.
See [`SECURITY.md`](SECURITY.md).
