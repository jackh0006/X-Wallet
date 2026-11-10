# Hardening baseline — 1.5.3

All figures below are from commands run in this workspace on 2026-11-10.
Commands that could not run are marked **NOT RUN HERE**, never guessed.

## Source state

- Repository: `jackh0006/X-Wallet`
- Base: `v1.5.1` (`f3a955a8b305229ced408b9ba6e19df78afa66d0`)
- Working branch: `hardening/1.5.3`
- Version: `1.5.3+15`

## Static checks

| Check | Command | Result |
|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed lib test tool` | see final run |
| Static analysis | `flutter analyze --no-pub` | **PASS** — "No issues found" |
| Branding | `python3 scripts/check_branding.py` | **PASS** — "Branding: PASS (X Wallet; compatibility identifiers preserved)" |
| Test inventory | `python3 scripts/test_inventory.py --check` | **PASS** — 67 files, 382 declarations |
| Secret scan | `bash scripts/secret-scan.sh` | **NOT RUN HERE** (final gate) |
| Dependency audit | `python3 scripts/dependency-audit.py` | **NOT RUN HERE** (final gate) |
| SBOM | `python3 scripts/sbom.py` | regenerated for 1.5.3 |
| Full suite | `bash scripts/test-suite.sh` | **NOT RUN HERE** (final gate) |

## New regression tests added

| File | Declarations | Proves |
|---|---:|---|
| `test/hardening_regressions_test.dart` | 9 | Pending recovery state, cancel verification, approve spender, unlimited threshold, token spoofing, clipboard guard, price defaults |
| `test/multi_vault_test.dart` | 6 | Three vaults, create/switch/rename/delete, password change, pending isolation |
| `test/portable_backup_test.dart` | 5 | Portable backup round-trip, wrong password, tamper, truncation, fresh-device restore |
| `test/privacy_startup_test.dart` | 2 | Transport rebuilt after prefs load; USD prices off by default |
| `test/node_secret_storage_test.dart` | 3 | Node credentials absent from plain prefs, export strips them, PIN fails closed |

## Targeted runs completed

| Command | Result |
|---|---|
| `flutter test test/hardening_regressions_test.dart` | PASS |
| `flutter test test/multi_vault_test.dart` | PASS (6/6) |
| `flutter test test/portable_backup_test.dart` | PASS (5/5) |
| `flutter test test/privacy_startup_test.dart` | PASS (2/2) |
| `flutter test test/node_secret_storage_test.dart` | PASS (3/3) |
| `flutter test test/erase_flow_test.dart` | PASS |
| `flutter test test/data_boundary_test.dart test/rpc_adversarial_test.dart` | PASS (11/11) |
| `flutter test test/cold_wallet_test.dart test/cold_wallet_protocol_test.dart test/send_intent_test.dart` | PASS (53/53) |

## Known limits of this baseline

- Windows, macOS and physical Android are not run here.
- `unshare -rn` is blocked in this container, so the OS-enforced offline
  launcher cannot be exercised here; it is shipped fail-closed and must be
  tested on a host with user namespaces enabled.
- No packet capture or `strace` artifact is recorded.
- No independent rebuild or audit is claimed.
