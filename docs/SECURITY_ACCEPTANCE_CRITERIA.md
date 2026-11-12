# Security acceptance criteria — 1.6.0

A criterion is met only with a command, exit code and commit. A clean scan is
not proof of security.

## Must pass before publication

| ID | Criterion | Evidence |
|---|---|---|
| SAC-01 | `dart format` clean | command output |
| SAC-02 | `flutter analyze --no-pub` clean | command output |
| SAC-03 | Full test suite passes for the release tree | test log |
| SAC-04 | New chain tests pass | `test/chains_test.dart` |
| SAC-05 | Explorer endpoint isolation tests pass | `test/explorer_history_test.dart` |
| SAC-06 | Price-provider pinning tests pass | `test/price_provider_test.dart` |
| SAC-07 | EIP-155 vector and cold chain binding pass | `test/ethereum_signing_test.dart` |
| SAC-08 | Secret scan passes | `scripts/secret-scan.sh` |
| SAC-09 | Dependency and licence checks pass | scripts |
| SAC-10 | SBOM, manifest, evidence and docs are generated and committed | generators |
| SAC-11 | Release identity and strict source gate pass | scripts |
| SAC-12 | Signed artifacts verify after publication | `verify-release-assets.sh` |
| SAC-13 | UTXO derivation matches official BIP44/49/84/86 vectors | `utxo_wallet_test.dart` |
| SAC-14 | BTC/LTC/DOGE build/sign and fee/change balance | `utxo_transaction_test.dart` |
| SAC-15 | UTXO indexer parsing and kill switch | `utxo_service_test.dart` |

## Cannot be met in this session

| ID | Criterion | Status |
|---|---|---|
| SAC-20 | Independent professional audit | NOT PERFORMED |
| SAC-21 | Independent-machine rebuild | NOT PERFORMED |
| SAC-22 | Physical Android install/send test | NOT PERFORMED |
| SAC-23 | Two-device cold-signing test | NOT PERFORMED |
| SAC-24 | Screen-reader session | NOT PERFORMED |
| SAC-25 | Packet capture of every egress | NOT PERFORMED |
| SAC-26 | Hardware-wallet integration | NOT IMPLEMENTED |
| SAC-29 | BTC/LTC/DOGE live testnet send/receive | NOT PERFORMED |
| SAC-30 | PSBT and two-device offline signing | NOT IMPLEMENTED / NOT PERFORMED |
| SAC-27 | Multisig / threshold custody | NOT IMPLEMENTED |
| SAC-28 | Large-holding approval | NEVER GRANTED BY SELF-ASSESSMENT |

## Readiness labels

Use exactly one:

- `NOT READY` — a required gate is failing.
- `DEVELOPMENT READY` — code and tests are usable by developers; no
  real-money claim.
- `LIMITED REAL-WORLD USE` — internal evidence is green, amounts are small,
  and the user accepts the documented limits.
- `INDEPENDENTLY REVIEWED` — an independent report exists and findings are
  fixed or accepted.
- `LARGE-HOLDING READINESS CANDIDATE` — independent review, independent build,
  physical tests and recovery drills all exist. This session cannot grant it.
