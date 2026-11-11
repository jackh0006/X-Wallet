# Documentation consistency

## Fixed in this audit branch

- `CITATION.cff` version 1.1.0 → 1.5.3; root `VERSION` added.
- README 1.5.1 filenames / “Version 1.5.1” → 1.5.3.
- README reproducibility hash and cross-runner claim corrected (fixed-path only; independent rebuild NOT TESTED).
- SBOM count 116 → 126 CycloneDX components in README/TEST_EVIDENCE/SUPPLY_CHAIN.
- `scripts/test-suite.sh` “47-file suite” → 66.
- Release note result column now PASS/NOT TESTED, not prose.
- Android release doc no longer claims every APK is covered by one `SHA256SUMS`; per-APK `.sha256` + release `SHA256SUMS` is stated.
- Threat model 1.0.10 risk register and “rotation NOT VERIFIED” row refreshed to 1.5.3.

## Remaining mismatches

- `v1.5.3` tag tree has `CITATION.cff` 1.1.0 and no `VERSION`; the fixes are on `main`, not in the tag.
- `release/evidence.json` sourceCommit `4867ff1` ≠ tag commit `34d31e1` ≠ tested code `b84c6fe` (squash chain, documented but not “identical”).
- `docs/releases/1.5.3.md` date 2026-11-10 vs `CITATION.cff` 2026-11-11.
- `release/package-smoke.json` still records 1.5.1.
- `README.md` still contains some historical proof rows and a fixed-path hash; they are labelled but not all re-run for 1.5.3.
- `docs/SECURITY_SCORECARD.md` package-smoke credit is stronger than the 1.5.3 launch-only smoke.

## Audit-branch counts

The audit branch adds `test/audit_regressions_test.dart` and
`test/erase_all_appstate_test.dart`, so the working inventory is 69 files /
391 declarations. The published v1.5.3 release remains 67/382. README and
manifest are kept at the release counts; the audit additions are listed in
`AUDIT/TEST_RESULTS.md`. A future release must regenerate both.
