# Test results

Baseline: `8583393` + local audit fixes. All results below were executed in this
workspace unless marked BLOCKED.

## Full suite

| Item | Value |
|---|---|
| Command | `bash scripts/test-suite-fast.sh` |
| Exit code | **0** |
| Non-integration files | **68** |
| Total test files | 69 (3 integration declarations excluded) |
| Declarations | **391** |
| Failed | **0** |
| Log | `/tmp/xw-audit-final-suite.log` |

The fast runner groups stateless files and runs filesystem/device-secret files
in their own process, matching the canonical suite's isolation for stateful
tests.

## Static and security checks

| Check | Command | Result |
|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed lib test tool` | PASS (129 files, 0 changed) |
| Analysis | `flutter analyze --no-pub` | PASS, no issues |
| Secret scan | `bash scripts/secret-scan.sh` | PASS |
| Dependency audit | `python3 scripts/dependency-audit.py` | PASS |
| Licence inventory | `python3 scripts/license-check.py --dart-only` | PASS |
| SBOM | `python3 scripts/sbom.py` | PASS, 126 components |
| Cold signature | `cd verification && npm ci && node verify.cjs` | PASS, 8 substitutions rejected |
| Reproducibility | fixed path `/tmp/bnb-repro-1.5.3` | PASS (`40ce258c…`) — same host only |
| Package launch | rootless extract + Xvfb | PASS (stayed alive, ldd clean) |
| Release identity | `python3 scripts/check_release_identity.py` | PASS on main 8583393 |
| Release gate | `python3 scripts/release-gate.py` | PARTIALLY VERIFIED |

## New regression tests added by this audit

| File | Tests | Result | Proves |
|---|---:|---|---|
| `test/audit_regressions_test.dart` | 8 | PASS | BIP-39 Trezor vector, BIP-44 address, EIP-55 typo rejection, PIN backoff overflow, cold approve contract binding |
| `test/erase_all_appstate_test.dart` | 1 | PASS | `AppState.eraseAll` completes without the process-lock deadlock |

## Blocked / not run

| Check | Status | Why |
|---|---|---|
| Real Anvil integration (3 declarations) | BLOCKED | Anvil not installed in this environment |
| Clean apt install/upgrade/uninstall | BLOCKED | no root/apt |
| Packet capture / `strace` egress artifact | BLOCKED | no full-session capture performed |
| Independent-machine rebuild | BLOCKED | no second host/toolchain |
| Physical Android install/run | BLOCKED | no device |
| Real screen-reader session | BLOCKED | no assistive-technology session |
| `unshare -rn` offline launcher success path | BLOCKED | user namespaces blocked in container |
| Official Argon2/BIP-32/Wycheproof vectors | NOT RUN | no corpus/pinned data added |
| Random differential signing fuzz | NOT RUN | only one ethers fixture |

## Test-count reality

The inventory says **69 files / 391 declarations**. The default non-integration
run is **68 files**; the missing file is `test/integration/anvil_test.dart`
(3 declarations, BLOCKED here). This is not a skipped test in CI: the
`integration` workflow runs it when Anvil is available.
