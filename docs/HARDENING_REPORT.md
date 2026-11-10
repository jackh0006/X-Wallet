# Hardening report — X Wallet 1.5.3

Date: 2026-11-10
Scope: the 1.5.1 source at `v1.5.1`, hardened into 1.5.3.
This is an internal self-review, **not** an independent audit.

## Result

| Area | Before 1.5.3 | 1.5.3 | Evidence |
|---|---|---|---|
| Recovery | Backup required the old device secret; a new device could not restore it | `BNBBKP01` portable backup restores with the password only | `test/portable_backup_test.dart` |
| Multiple vaults | One active vault file | Up to three independent vaults with separate passwords; pending rows scoped per vault | `test/multi_vault_test.dart` |
| Password change | Implemented but unreachable in the UI | Settings → Vaults → Change password | `test/multi_vault_test.dart` |
| Uncertain broadcast | Signed hash discarded; retry could pay twice | Signed bytes persisted before broadcast; unresolved rows block sends and are checkable | `lib/screens/send_page.dart`, `test/hardening_regressions_test.dart` |
| Cancel | Always failed verification | Signs an explicit zero value | `test/hardening_regressions_test.dart` |
| ERC-20 approval | Spender hidden; only exact 2^256-1 flagged | Spender displayed, 2^255 threshold, `increaseAllowance`/`transferFrom` decoded | `test/hardening_regressions_test.dart` |
| ABI decoding | `transfer`/`approve` address words rejected as invalid | Last 20 bytes of the ABI word are used | `test/hardening_regressions_test.dart` |
| Token spoofing | Exact "USDT" on a fake contract passed silently | Always unverified | `test/hardening_regressions_test.dart` |
| Tor/proxy startup | Transport built before prefs, silently direct | Rebuilt after init; dead SOCKS fails closed | `test/privacy_startup_test.dart` |
| Cold mode | Prices still ran at startup | All app-initiated calls gated; USD off by default | `test/privacy_startup_test.dart` |
| Node credentials | Proxy passwords/tokens in plain preferences | Secure store; export strips them | `test/node_secret_storage_test.dart` |
| RPC trust | Unbounded responses, any method, credential URLs | 2 MiB cap, method allowlist, URL policy | `test/rpc_adversarial_test.dart` |
| Erase | Log and orphan temp files survived | All vaults, log and `.dest-<hex>` files removed | `test/erase_flow_test.dart` |
| Branding | Version could appear in the display name | Gate enforces "X Wallet" exactly | `scripts/check_branding.py` |
| Android signer | 1.5.1 identity | New 1.5.3 identity (see claim register) | `apksigner` |

## Bugs fixed with a regression test

1. Tor/proxy silently bypassed after restart (privacy).
2. Cold mode still called price APIs (privacy/offline claim).
3. Uncertain broadcast could be retried with a new nonce (double payment).
4. Cancel could never pass verification.
5. Standard ERC-20 `transfer`/`approve` review threw "Invalid EVM address".
6. `approve` hid the spender and only flagged the exact maximum.
7. An exact known symbol on a fake contract was not marked unverified.
8. Node proxy passwords and tokens were stored in plain preferences and exported.
9. `eraseAllData` left the activity log and crash-orphaned temp files.
10. PIN verification returned true when the PIN record was missing.
11. Backup could not be restored on a new device.
12. Android keyring could mint a replacement secret over an existing vault
    (documented; a test still requires a platform-channel harness).

## Claims downgraded or removed

- "The offline signer has no network path" → cold mode blocks all
  app-initiated calls; the binary still links network code. See
  `docs/CLAIM_REGISTER.md` C25.
- "Device-bound double wrapper; both factors required" → the password wrapper
  opens the payload; the device wrapper is defense-in-depth (C3/C4).
- "Crypto-erasure" → deleting the device secret does not make a retained vault
  plus password undecryptable (C5).
- "Nonce is checked before signing" → it is displayed and used, but
  `SendIntent.verify` has no nonce parameter (C18).
- "91/100" → 70/100 internal self-assessment; no audit credit (C41).

## Remaining blockers

- Independent audit, independent rebuild, physical cold-device test, real
  screen-reader session, Android device run.
- Cold-path spending policy and nonce binding in `SendIntent.verify`.
- Strict release gate and release-signed Android CI.
- Coverage-guided fuzzing and a soak test.

**This wallet is NOT approved for large amounts until the independent audit
and the human-only items are complete.**
