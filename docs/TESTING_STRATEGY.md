# Testing Strategy

Status labels are evidence, not promises: **IMPLEMENTED**, **TESTED**, and
**VERIFIED** are distinct. A passing mock or an exception-only assertion is
not verification.

## Required gates

| Gate | Command | Current status (2026-11-06) |
|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed lib test tool` | PASS |
| Static analysis | `flutter analyze --no-pub` | PASS: no issues |
| Full unit/widget suite | `bash scripts/test-suite.sh` | PASS: 48 default files, 0 failed, 0 timed out, 533 s; 49 files total including the separate Anvil suite |
| Production KDF | `test/kdf_production_test.dart` | PASS: fixed 64 MiB/t=3/p=4, native vs pure-Dart agreement, one real round-trip < 60 s |
| Property/fuzz-style parsers | `test/fuzz_and_property_test.dart` | PASS: deterministic seeds, 2000-iteration RLP/calldata/vault/envelope mutations |
| RPC adversarial responses | `test/rpc_adversarial_test.dart` | PASS: wrong chain, non-JSON/HTML, oversized/malformed balance, network switch |
| Accessibility | `test/accessibility_test.dart` | PASS: semantics label, keyboard hold/early release, 200% text scale |
| Secret scan (current tree) | `bash scripts/secret-scan.sh` | PASS |
| Secret scan (history) | `bash scripts/secret-scan.sh --history` | KNOWN EXPOSURE: old Android keystore remains public; rotation `NOT VERIFIED` |
| Dependency advisory audit | `python3 scripts/dependency-audit.py` | PASS: no current pub.dev advisory flags |
| License inventory | `python3 scripts/license-check.py` | PASS for inventory; release-owner review still required |
| Independent transaction verification | `(cd verification && npm ci && node verify.cjs)` | PASS: 8 field substitutions rejected |
| SBOM freshness | `python3 scripts/sbom.py --out docs/SBOM.json` | PASS |
| Test inventory and docs | `test_inventory.py --check`, `release_manifest.py --check`, `generate_docs.py --check` | PASS |
| Release gate | `python3 scripts/release-gate.py` | INCOMPLETE: source checks recorded locally; release artifacts/install/reproducibility absent |
| Clean install / launch | manual, clean Ubuntu | NOT TESTED |
| Reproducibility | `bash scripts/reproducibility-check.sh` | PASS with fixed-path constraint — identical archive `388f94bf…` and manifests; different absolute paths differ (embedded Flutter paths) |
| Independent audit | external | NOT AVAILABLE |

Every new defect needs a regression test that asserts the intended code path,
the observable state, and preservation of unrelated data.

## Test layers

| Layer | Where | Notes |
|---|---|---|
| Unit | `test/*_test.dart` | Crypto, storage, fees, lifecycle, protocol |
| Property-based | `test/fuzz_and_property_test.dart` | Seeded `Random`; reproducible failures |
| Fuzz-style | `test/fuzz_and_property_test.dart` | Deterministic mutation, not coverage-guided fuzzing |
| Integration (mock RPC) | `test/rpc_adversarial_test.dart` | Malicious and malformed JSON-RPC responses |
| Integration (real EVM) | `test/integration/anvil_test.dart` | Anvil 1.9.0, chain 97: native transfer, ERC-20 deploy/transfer/approve/revoke, wrong chain, revert |
| Security | vault/envelope/cold/RPC suites | Tamper, replay, wrong chain, lookalike addresses |
| Widget/UI | `test/navigation_flow_test.dart`, `test/*_dialog*`, `test/accessibility_test.dart` | Flows, keyboard, semantics |
| Performance | `release/benchmarks.json` | Native KDF measured; startup/RSS still `NOT TESTED` |
| Release | `scripts/release-gate.py`, `reproducibility-check.sh` | Gate is the authority; artifacts not yet built |

## Resource constraints

The release-check machine is a 2-core / 3.8 GiB Ubuntu 24.04 host. The test
driver is serial, gives KDF-tagged files a 900 s watchdog, and sets
`umask 0077`. Do not run two `flutter test` processes at once: concurrent runs
have caused native test-device segmentation faults. A timeout, OOM, or
segfault is `FAILED`/`INCOMPLETE`, never a pass.
