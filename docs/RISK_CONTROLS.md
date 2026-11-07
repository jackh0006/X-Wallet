# Risk Controls and Safe Operation

X Wallet is a local, self-custodial software wallet. This page explains the
controls that reduce operational risk and how to use them for larger balances.

## Built-in controls

| Control | What it does | Where |
|---|---|---|
| Encrypted vault | Argon2id + XChaCha20-Poly1305, device-bound layer | Vault creation/unlock |
| Local signing | Keys never leave the device | Send review |
| Freeze signing | Blocks every send until deliberately unfrozen | Settings → Spending safety |
| Recipient allowlist | Restricts recipients when enabled | Settings → Spending safety |
| Per-transaction limit | Caps native BNB per transfer | Settings → Spending safety |
| Hold-to-confirm | Requires a deliberate press-and-hold | Send review |
| Exact review | Recipient, chain, nonce, fees, maximum cost, calldata | Send review |
| Cold/offline signing | Offline signer has no network path | Cold wallet |
| Tor / SOCKS / HTTP proxy | Hides the route from the local network | Settings → Privacy |
| Encrypted history | Logs and receipts are encrypted at rest | Local storage |
| Backup verification | Recovery-phrase quiz before funding | Wallet actions |
| Auto-lock | Locks on idle and when the app backgrounds | Settings → Auto-lock |

## Recommended operating procedure for larger balances

1. Use a dedicated device or a dedicated operating-system account.
2. Create the wallet offline if possible, and verify the recovery phrase on paper.
3. Split holdings across separate vault accounts or separate wallets; do not keep
   one large balance on one hot device.
4. Enable **Freeze signing** when you are not actively sending.
5. Set a **recipient allowlist** and a **per-transaction limit** before funding.
6. Send a small test amount to every new recipient first.
7. Use cold/offline signing for larger transfers when practical.
8. Verify the recipient and the full transaction details on the review screen.
9. Keep the recovery phrase offline and separate from the device.
10. Verify the release SHA-256 and the detached signature before installing.
11. Keep the operating system, firmware, and the app updated.
12. Use a trusted RPC node or Tor/SOCKS routing; verify the current route in
    Settings → Privacy.

## Security model

- The wallet is non-custodial: the recovery phrase and signing keys are local.
- The vault is encrypted at rest; the device-bound secret is separate from the
  vault file.
- Signing is local. RPC nodes receive public transaction data and address
  queries, never seed words or private keys.
- The app has no account, subscription, ads, or analytics SDK.
- No AI service or builder-controlled server receives vault contents, private
  keys, seed phrases, or transaction signing material.

## Scope facts

- This release is a software hot wallet; a compromised operating system can read
  an unlocked session.
- The project publishes an internal self-audit and test evidence. An independent
  third-party audit is a separate engagement and is not claimed here.
- Hardware-wallet integration is outside the 1.x scope.
- The reviewed isolation path in this release is cold/offline signing plus the
  spending controls above.
- Large-value use requires the operating procedure above and an owner decision
  to accept the residual software-wallet risk.

## Verification

- SHA-256 and signature: see the GitHub release page and `SIGNING_CHECKLIST.md`.
- Test evidence: `docs/TEST_EVIDENCE.md` and `release/evidence.json`.
- Data-flow proof: `docs/DATA_CONTROL.md`.
