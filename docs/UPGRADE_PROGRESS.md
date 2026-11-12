# Upgrade progress — 1.6.0

Last updated: 2026-11-12

## Completed

| Item | Evidence |
|---|---|
| Baseline recorded | `docs/BASELINE_TEST_REPORT.md`; analyze clean, 47 focused tests pass |
| Chain registry | `lib/chains.dart`; `test/chains_test.dart` |
| Ethereum defaults (USDT, USDC, XAUT) | `lib/default_tokens.dart`; `test/chains_test.dart` |
| Chain-aware token registry and logos | `lib/token_registry.dart`, `lib/token_logos.dart` |
| Per-chain explorer keys | `lib/storage.dart`, `lib/rpc_service.dart`, `lib/app_state.dart`; `test/explorer_history_test.dart` |
| Etherscan v2 history | `lib/rpc_service.dart`; `test/explorer_history_test.dart` |
| Cold signer chain registry | `lib/cold_tx_codec.dart`, `lib/wallet_core.dart`, `lib/cold_wallet_protocol.dart`; `test/ethereum_signing_test.dart` |
| EIP-155 official vector | `test/ethereum_signing_test.dart` |
| Price provider selection | `lib/price_service.dart`, `lib/storage.dart`, `lib/screens/settings_page.dart`; `test/price_provider_test.dart` |
| Dynamic chain UI | `lib/screens/home_page.dart`, `send_page.dart`, `wallet_page.dart`, `receipt_page.dart`, `activity_page.dart`, `inspect_page.dart`, `settings_page.dart` |
| Custom token duplicate check scoped by chain | `lib/app_state.dart` |
| Tests added | 8 new test files (43 tests) |

## Commands and results

```bash
flutter analyze --no-pub
# PASS — no issues

flutter test --concurrency=1 \
  test/chains_test.dart \
  test/explorer_history_test.dart \
  test/price_provider_test.dart \
  test/ethereum_signing_test.dart
# PASS — see the run log in /tmp/xw-1.6.0-newtests.log
```

## UTXO milestone

- BTC/LTC/DOGE network registry, BIP44/49/84/86 derivation and P2PKH,
  P2SH-P2WPKH, P2WPKH, P2TR addresses.
- WIF/raw key import/export, UTXO discovery, fee estimate, coin selection,
  change, dust handling, signing, serialization, TxID and broadcast.
- UI at `lib/screens/utxo_page.dart`.
- 30 UTXO tests pass, including official BIP44/49/84/86 vectors.

## Verified

```bash
flutter analyze --no-pub
# PASS — no issues

flutter test --concurrency=1   test/chains_test.dart test/explorer_history_test.dart   test/price_provider_test.dart test/ethereum_signing_test.dart
# PASS — all new tests

bash scripts/test-suite-fast.sh
# PASS — 72 non-integration files

BNB_REPRO_PATH=/tmp/bnb-repro-1.6.0 \
  bash scripts/reproducibility-check.sh 5ff0f0a
# PASS — archive fcdf38ad…bc0d
```

## In progress / not done

- Full suite after the UI changes.
- Release version bump, release note, SBOM, manifest and evidence.
- Signed artifacts and post-release verification.
- Hardware wallet, multisig, independent audit, physical device tests and
  screen-reader session: **NOT IMPLEMENTED / NOT PERFORMED**.
