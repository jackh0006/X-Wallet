# Update and Re-Verification Playbook

**Remember this file for every future version.** It defines the minimum
verification for the code that changed, how to bind the result to the exact
commit, and when a full re-run is genuinely required. The goal is fast,
complete, evidence-backed updates without repeating multi-hour runs for code
that did not change.

This file does not replace the release gate. It tells you which checks are
required and which previous results remain valid.

## Core rule

> **Verify the changed surface completely, prove it against the exact commit,
> and reuse the recorded baseline for unchanged code.**

A previous result is valid only when:

1. the file, dependency, toolchain, and build input are unchanged;
2. the previous evidence is recorded for a known commit;
3. the current release still passes the cheap global gates;
4. the result is not a security claim that depends on the changed area.

If any of those is false, run the affected checks again. If you are unsure, run
the affected area, not the entire suite.

## Baseline: 1.3.0

These are the recorded 1.3.0 results. Reuse them only for unchanged areas.

| Check | Baseline | Measured time |
|---|---|---|
| Formatting | PASS — 109 files, 0 changed | 2 s |
| Static analysis | PASS — no issues | 13 s |
| Default suite | PASS — 58/58 files | about 10–12 min |
| Test inventory | 60 files / 347 declarations | < 1 s |
| Mutation testing | 5/5 killed | 89–97 s |
| Anvil real-EVM integration | 3/3 | 11–28 s |
| Independent cold oracle | PASS — 8 substitutions rejected | 5–6 s |
| Backup/restore E2E | 4/4 | 13 s |
| Localization | PASS | 11–13 s |
| Password strength | 5/5 | < 1 s |
| Multi-wallet vault | 4/4 | < 1 s |
| Default tokens | 3/3 | < 1 s |
| Private-key cold signing | 3/3 | < 1 s |
| Legacy data migration | 2/2 | < 1 s |
| Public RPC defaults | 3/3 | < 1 s |
| Spending safety | 5/5 | 10–35 s |
| Data boundary | 4/4 | 9 s |
| Release signing tools | PASS | 2 s |
| Release identity negative tests | 15/15 | < 1 s |
| Debian package build | PASS — signed `.deb` | 30 s |
| Reproducibility (two builds) | PASS — `dffb5b35…` | 256–265 s |
| Package smoke (CI) | PASS | 150–170 s |
| Dashboard/CI | PASS | 4–8 min |

The heavy 1.3.0 path takes about **40–50 minutes**, not two hours. The extra
time came from repeated full-suite runs and retries. Do not repeat those.

## Change-scoped matrix

Find every changed path, take the union of the required checks, then run them.

| Changed area | Required checks | Do not skip |
|---|---|---|
| `lib/kdf.dart`, `lib/vault.dart`, `lib/workers.dart` | `kdf_production_test`, `vault_test`, `vault_header_validation_test`, `vault_import_rollback_kdf_test`, `backup_restore_e2e_test`, `workers_test`, `cold-signature` oracle | KDF parameters, wrong password/device, tamper, truncation, migration |
| `lib/wallet_core.dart`, `lib/send_intent.dart`, `lib/cold_tx_codec.dart` | `wallet_core_test`, `send_intent_test`, `cold_tx_codec_test`, `cold_wallet_protocol_test`, `cold_wallet_service_test`, `cold_wallet_test`, `hold_to_confirm_test`, `cold-signature` oracle, Anvil integration | Chain ID, recipient, value, fee, nonce, calldata, replay, substitution |
| `lib/storage.dart`, `lib/posix_fs.dart`, `lib/encrypted_log_store.dart`, `lib/receipt_store.dart` | `filesystem_security_test`, `rollback_injection_test`, `log_canary_test`, `drawer_secret_test`, `receipt_store_test`, `backup_restore_e2e_test` | Permissions, atomic rename, no-follow, lock identity, no secret in logs |
| `lib/password_strength.dart`, `lib/screens/vault_password_dialog.dart` | `password_strength_test`, `vault_multi_wallet_test`, `navigation_flow_test` | Any length, no trimming, confirmation, strength label |
| `lib/app_state.dart` vault session + `wallet_page.dart` manager | `vault_multi_wallet_test`, `vault_rename_test`, `navigation_flow_test`, `settings_state_test` | One password, add/switch/rename/remove, cache cleared on lock |
| `lib/default_tokens.dart`, default token merge | `default_tokens_test`, `send_intent_test` | USDT/USDC canonical contract and no duplicates |
| `lib/storage.dart` legacy directory migration | `legacy_migration_test`, `filesystem_security_test`, `vault_test` | Copy vault + device secret + prefs, never overwrite current vault |
| Cold pairing/signing for key-only wallets | `cold_private_key_test`, `cold_wallet_service_test`, `cold_wallet_protocol_test` | Pairing, key binding, replay safety, response verification |
| `lib/spending_policy.dart`, send/settings UI | `spending_policy_test`, `send_intent_test`, `tx_lifecycle_test`, `settings_state_test`, `navigation_flow_test`, `widget_test` | Freeze, allowlist, per-transaction limit before signing |
| `lib/net/privacy_client.dart`, `lib/rpc_service.dart`, `lib/tor_manager.dart` | `rpc_adversarial_test`, `tls_pinning_test`, `privacy_config_test`, `privacy_dialogs_test`, `ua_scrub_test`, `nodes_test`, `node_manager_test` | Wrong chain, TLS validation before pin, fail-closed route, no fallback |
| `lib/fee_engine.dart`, `lib/tx_lifecycle.dart` | `fee_engine_test`, `fee_parity_test`, `send_intent_test`, `tx_lifecycle_test` | EIP-1559/legacy math, sanity clamps, max cost |
| `lib/screens/**`, `lib/widgets/**` | `widget_test`, `navigation_flow_test`, `accessibility_test`, `story_test`, `journey_map_test`, `hold_to_confirm_test` | Hold-to-confirm, full-address review, semantics, 200% text |
| `lib/localized_text.dart`, `lib/l10n/**`, `assets` strings | `localization_test`, `localization_catalog_test` | Every locale, fallback behavior |
| `pubspec.yaml` / `pubspec.lock` | Full suite + `dependency-audit`, `license-check`, `sbom`, `data_boundary_test` | Dependency change invalidates dependency evidence |
| `.github/workflows/**`, `scripts/**` | Affected script tests, `release-gate`, `check_release_identity`, `test_release_identity` | Workflow permissions and pinned actions |
| Docs, version text, release notes only | Formatting, branding, free-use, test inventory, release evidence, manifest, docs sync, secret scan | No source test rerun needed |

If a change touches more than one area, run the union. If it touches a shared
core file (`wallet_core`, `vault`, `storage`, `send_intent`, `rpc_service`),
treat it as a release candidate and run the full suite once.

## Always-required quick gates

These are cheap and must run for every version, even docs-only:

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --no-pub
python3 scripts/check_branding.py
python3 scripts/check_free_product.py
python3 scripts/test_inventory.py --check
python3 scripts/check_release_evidence.py
python3 scripts/release_manifest.py --check
python3 scripts/generate_docs.py --check
bash scripts/secret-scan.sh
python3 scripts/dependency-audit.py
python3 scripts/license-check.py
python3 scripts/check_release_identity.py
python3 scripts/test_release_identity.py
python3 scripts/release-gate.py
```

Expected time: **1–2 minutes**.

## Commands for the affected areas

```bash
# Crypto / vault
flutter test test/kdf_production_test.dart test/vault_test.dart \
  test/vault_header_validation_test.dart test/vault_import_rollback_kdf_test.dart \
  test/backup_restore_e2e_test.dart test/workers_test.dart --concurrency=1

# Transactions / signing
flutter test test/wallet_core_test.dart test/send_intent_test.dart \
  test/cold_tx_codec_test.dart test/cold_wallet_protocol_test.dart \
  test/cold_wallet_service_test.dart test/cold_wallet_test.dart \
  test/hold_to_confirm_test.dart test/tx_lifecycle_test.dart --concurrency=1
(cd verification && npm ci && node verify.cjs)
bash scripts/run-anvil-tests.sh

# Storage
flutter test test/filesystem_security_test.dart test/rollback_injection_test.dart \
  test/log_canary_test.dart test/drawer_secret_test.dart \
  test/receipt_store_test.dart --concurrency=1

# Spending safety
flutter test test/spending_policy_test.dart test/send_intent_test.dart \
  test/tx_lifecycle_test.dart test/settings_state_test.dart \
  test/navigation_flow_test.dart test/widget_test.dart --concurrency=1

# Network / privacy
flutter test test/rpc_adversarial_test.dart test/tls_pinning_test.dart \
  test/privacy_config_test.dart test/privacy_dialogs_test.dart \
  test/ua_scrub_test.dart test/nodes_test.dart test/node_manager_test.dart \
  --concurrency=1

# UI / accessibility / localization
flutter test test/widget_test.dart test/navigation_flow_test.dart \
  test/accessibility_test.dart test/story_test.dart test/journey_map_test.dart \
  test/localization_test.dart test/localization_catalog_test.dart --concurrency=1

# Full suite only for a release candidate or shared-core change
bash scripts/test-suite.sh
```

On this machine, Anvil is at `$HOME/.foundry/bin/anvil`:

```bash
export PATH="$HOME/.foundry/bin:$PATH"
```

## Evidence binding

Record each required check against the exact commit:

```bash
umask 0077
python3 scripts/record_check.py --id <check-id> --log /tmp/opencode/evidence-<version>/<check-id>.log -- <command>
```

Then:

1. Write the real result table in `docs/releases/<version>.md`.
2. Update `docs/TEST_EVIDENCE.md` only for checks that changed.
3. Regenerate `docs/SBOM.json` if dependencies changed.
4. Regenerate `release/manifest.json` and `docs/GENERATED_STATUS.md`.
5. Update `release/evidence.json` with the exact commit, artifact hash, and
   signature hashes.
6. Run `python3 scripts/check_release_identity.py` and
   `python3 scripts/release-gate.py`.
7. Commit evidence and generated docs; never publish with `PENDING`.

Do not copy an old hash, duration, or pass mark for a new artifact. The package
hash changes even when only documentation differs.

## Release-candidate path

Use this for every public version:

1. Run the union of affected checks plus the quick gates.
2. Run the full suite **once** if a shared core or dependency changed.
3. Build `x-wallet-<version>-amd64.deb` from the final source commit.
4. Generate `SHA256SUMS`, sign `SHA256SUMS.asc`, and verify in a clean keyring.
5. Run package smoke in CI (or on a disposable machine).
6. Run fixed-path reproducibility when build inputs changed.
7. Run release identity and the release gate.
8. Publish with the signed package, source archive, SBOM, and release evidence.

## What is never waived

- A signed artifact and a verified detached signature.
- The exact SHA-256 of the published package.
- Release identity and the release gate.
- Package install/launch/upgrade evidence for a public `.deb`.
- A real test run for every changed feature.
- An honest statement that the audit is internal, not independent.

## Honest wording

Use **verified for the recorded commit** when a command exited 0 and the
evidence binds to that commit. Do not use **guaranteed safe** or
**independently audited**. A signature proves artifact integrity, not the
absence of defects.

## Maintenance

When a new feature or test is added:

1. Add the test file to `docs/testing/TEST_MATRIX.md`.
2. Add the feature row to the change-scoped matrix above.
3. Re-run `python3 scripts/test_inventory.py`.
4. Update the baseline table after the version is published.

This file is referenced from `AGENTS.md` so future sessions load it first.

## Evidence ancestry after a squash merge

GitHub squash-merges a release PR into a new commit, so the tested commit is
not an ancestor of the release commit. Keep the tested commit fetchable (a
signed `tested-x.y.z` tag) and record `squashMerge` in
`release/evidence.json`.

The identity/gate generators accept differences between the tested commit and
`sourceCommit` only in `docs/`, `release/`, and an explicit release-tooling
allowlist (`scripts/generate_docs.py`, `scripts/release-gate.py`,
`scripts/check_release_identity.py`). If a later commit changes another root
file, add that path to all three allowlists deliberately — never whitelist
wallet code or tests.
