# Baseline test report — 1.5.5 tree

Date: 2026-11-12
Repository: X-Wallet checkout in the session workspace
Baseline commit: `ead3237` (`stable`, `1.5.5+17`)

This report records the state **before** the 1.6.0 changes. Later regressions
must not be blamed on the baseline.

## Commands run

```bash
flutter analyze --no-pub
flutter test --concurrency=1 \
  test/vault_rename_test.dart \
  test/multi_vault_test.dart \
  test/fee_engine_test.dart \
  test/send_intent_test.dart \
  test/vault_management_test.dart
```

## Results

| Check | Result |
|---|---|
| Static analysis | PASS — no issues (19.2 s) |
| Focused vault/multi-vault/rename/fee/send-intent tests | PASS — 47/47 |
| Formatting (previous release gate) | PASS |
| Full 1.5.5 suite (release evidence) | PASS — 68 non-integration files |
| Release evidence identity | PASS at `1.5.5+17` |
| Release gate (source) | PASS at `1.5.5+17` |

## Known baseline conditions

- Only BNB Smart Chain (56) and BSC testnet (97) are first-class chains.
- `BnbNetworks` is the single network table; many UI strings name BSC/BNB.
- Default tokens cover BSC USDT and USDC only.
- Price providers are an automatic fallback chain, not a user choice.
- Explorer API keys are a single BscScan key, not per chain.
- Hardware-wallet and multisig support are **not implemented**.
- No independent audit, independent rebuild, physical Android run,
  two-device cold test or screen-reader session exists.
- Mutation testing was last run for 1.5.3 and was not re-run for 1.5.5.

## Environment

- Ubuntu 24.04.5 LTS x86_64
- Flutter 3.47.6 stable, Dart 3.13.5
- Android SDK 36 / build-tools 36.0.0
- The container has no Android device or independent audit service.
