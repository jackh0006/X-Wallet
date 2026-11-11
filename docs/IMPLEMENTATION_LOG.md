# Implementation Log

Chronological, evidence-bound record. Do not rewrite history here; append new
entries and mark superseded claims.

## 2026-11-06 — release/1.0.10 candidate

**Code commit:** `e474b8956a68febf44ef780c7decf898e9050018`
**Final candidate HEAD:** `142929315b7df572ffae93cbc5ab1a2ec2395724`
**PR:** <https://github.com/jackh0006/X-Wallet/pull/10>

### Cryptography and transaction fixes

- Wired the reference native Argon2id library into `lib/kdf.dart`, with an
  explicit pure-Dart fallback. Measured 344 ms for 64 MiB / t=3 / p=4.
- Added `test/kdf_production_test.dart`: fixed parameters, native vs pure-Dart
  agreement at 1 MiB, one real 64 MiB round-trip under a 60 s guard.
- Envelope/format tests use `VaultCipher.debugKdfOverride` (assert-guarded,
  compiled out of release).
- Fixed `SendIntent.decodeErc20Transfer` to require exact 4+32+32-byte
  calldata; added a trailing-byte regression test.

### Test stability

- Navigation fixture is offline and awaits real storage I/O through
  `runAsync`; HomePage no longer starts real RPC timeouts.
- Storage teardown flushes encrypted-log appends and retries `ENOTEMPTY`.
- Full suite: 47 files / 299 declarations, 47/47 passed locally in 577 s.
- Hosted CI: full suite passes in both push and PR runs.

### Evidence and CI

- Added `release/manifest.json`, `docs/testing/test-inventory.json`,
  `docs/GENERATED_STATUS.md`, generated README status block,
  `scripts/release-gate.py`, `scripts/record_check.py`, `scripts/test_inventory.py`,
  `scripts/release_manifest.py`, and `scripts/generate_docs.py`.
- Added workflows: `dependency-review`, `docs-sync`, `release-build`
  (provenance + SBOM attestations), `reproducibility`, `scheduled-security`.
- Branch protection now also requires `generated-files` and `review`.

### Android incident

- Recorded the historical `scripts/release.keystore` exposure in
  `docs/security/INCIDENT_2026-11-KEYSTORE.md`.
- Added `scripts/verify-android-signer.sh` and
  `release/android-signer-denylist.txt`.
- `scripts/build-apk.sh` requires owner approval, an approved signer, and a
  populated denylist; Android remains blocked.

### Reproducibility investigation

- Two worktrees at different paths differed in `bnb_wallet_gui`,
  `libapp.so`, and three plugin `.so` files.
- `strings` showed `libapp.so` embeds
  `file:///<path>/.dart_tool/flutter_build/dart_plugin_registrant.dart`, and
  plugins embed `<path>/linux/flutter/ephemeral`.
- `readelf -n` confirmed different linker build IDs.
- Rebuilding twice in the same path was identical except one stale
  `native_assets.json`.
- Two clean builds at the same fixed path `/tmp/bnb-repro-final` produced
  identical files and, with `SOURCE_DATE_EPOCH=0` and `gzip -n`, identical
  archives: `134e6b064dcc22b57a23136031b3224b6594af2f9efeb2ad388dfc3b2e6c86d4`.
- Constraint documented: different absolute build paths are not guaranteed to
  match; independent-machine proof is still required.

### Artifact

- Built the unsigned 1.0.10 package from the final docs state.
- SHA-256: `d25ecdb2de3a8e706950158639d0366dc147f339957500a98b3f429c6b549244`.
- `dpkg-deb -x` + `ldd` resolve all libraries; no secret-bearing filenames.
- Not signed, not installed, not published.

### Continuation — durable records and reproducibility fix

- Added `IMPLEMENTATION_STATUS.md`, `docs/IMPLEMENTATION_LOG.md`,
  `docs/SECURITY_SCORECARD.md`, `docs/SECURITY_RISK_REGISTER.md`,
  `docs/TEST_RESULTS.md`, `docs/RELEASE_PROCESS.md`,
  `docs/RELEASE_VERIFICATION.md`, `docs/COMPATIBILITY.md`,
  `docs/BACKUP_AND_RECOVERY.md`, `docs/INCIDENT_RESPONSE.md`,
  `docs/CRYPTOGRAPHY.md`, `docs/TRANSACTION_SECURITY.md`,
  `docs/SUPPLY_CHAIN_SECURITY.md`, and `docs/SECURITY_AUDIT.md`.
- Added `docs/evidence/2026-11-06/` with environment, CI checks, suite summary,
  reproducibility log, same-path diff, and package hash.
- Reworked `scripts/reproducibility-check.sh` to use a fixed absolute build
  path, `SOURCE_DATE_EPOCH=0`, and `gzip -n`.
- Reproducibility result: PASS at `/tmp/bnb-repro-final`, archive
  `388f94bf…`; different absolute paths still differ.
- Provisional self-assessed score: **73/100**, with release blockers listed.
- Added the three-pass self-audit (`docs/SELF_AUDIT_2026-11-06.md`) and an
  independent-review guide (`docs/INDEPENDENT_REVIEW_GUIDE.md`).

## Superseded claims

- “Reproducibility FAILED” (earlier 2026-11-06 entry) is superseded by the
  fixed-path pass above. Different-path builds still differ; the earlier
  failure was real and is retained as investigation history.

## 2026-11-06 — final engineering tranche

- **Release identity:** `scripts/check_release_identity.py` plus 12 negative
  tests; fail-closed on missing checks, stale hashes, malformed commits,
  duplicate checks, missing identity notes, and artifact hash mismatch.
- **Real EVM:** Anvil 1.9.0 chain 97 integration suite. Native transfer,
  wrong-chain rejection, ERC-20 deploy/mint/transfer/approve/revoke/revert,
  signed-field verification. Pinned fixture at
  `test/integration/fixtures/test_token.json`.
- **Mutation testing:** `scripts/security_mutation_check.py`; first run found
  missing zero-address and low-s regressions, both added; final score 5/5.
- **Backup/restore E2E:** synthetic create → encrypted backup → wipe → restore,
  wrong password, tamper and truncation tests.
- **Signing tooling:** owner-only `scripts/sign-release.sh`,
  `scripts/verify-release-signature.sh`, disposable-key negative tests.
- **Android inventory:** `scripts/inventory-android-signers.sh` prints public
  fingerprints only; synthetic-keystore test; incident remains blocked.
- **CI:** Anvil, signing, inventory, mutation, identity, package-smoke,
  two-runner reproducibility and startup/RSS workflows.
- Current scorecard: **79/100**, unsigned and unsigned-for-release.

## 2026-11-12 — X Wallet 1.5.5 release

- **Version:** `1.5.5+17`; release tag `v1.5.5` at
  `cd2f8e69b88a9ab8cd86da985b4d091621458652`.
- **Tested code:** `32b0aad3c296b52e2bfd4d84929c09de5c67eb0d`, preserved by the
  signed tag `tested-1.5.5`; tooling commit `95e34ed` adds passphrase-aware
  release scripts.
- **Squash merge:** `e59124eee13c06d4d79b242396caccc79f43f2a5` from reviewed
  branch head `2b1d192`; evidence PR merged as `cd2f8e6`.
- **Security changes:** reviewed nonce and sender are bound to the exact signed
  transaction; cold-pairing fingerprint covers the chain and every paired
  address; erase-all includes pre-1.2 data directories; Android imports are
  capped at 8 MiB; custom RPC headers reject cookies/referer/origin/
  authorization/API keys/host/framing headers/CRLF/oversized values.
- **Release tooling:** `release-gate.py --require-source` is used by CI;
  `release-verify.yml` downloads the published assets, imports the committed
  public key, verifies `SHA256SUMS`/GPG and the APK signer, then runs
  `--require-verified --artifacts-dir`.
- **Checks:** formatting/analyze PASS; fast suite PASS (68 non-integration
  files); inventory 69 files / 395 declarations; audit regressions 12/12; cold
  oracle PASS; secret/dependency/licence/SBOM PASS; `.deb` build + GPG PASS;
  Android arm64/universal signed with `2a96a384…3ba9a`; package-smoke run
  `43103453990` PASS; fixed-path reproducibility PASS
  (`440aff80…8e08`).
- **Artifacts:** `.deb` `2f8ef873…c77298`; arm64 APK `6978de80…7a16`;
  universal APK `eb6772b3…c186b`; source archive `891b7b41…48436`; SBOM
  `1e9946ed…672a14`; signed `SHA256SUMS` `b7d46b85…2015f`.
- **Status:** `RELEASE APPROVED` for the recorded internal checks. Independent
  audit, independent-machine rebuild, physical Android run, two-device cold
  signing and screen-reader session remain **NOT PERFORMED**. The first
  post-release verifier runs exposed tooling-only bugs; the fixed verifier was
  merged in `4ec8cad`/`eb73927` and re-run against the published assets.
