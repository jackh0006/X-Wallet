# Large-Value Use and Custody Controls

**Status: owner-directed large-value use is permitted only with the controls
below. This is not an independent certification or a security guarantee.**

X Wallet is a local, non-custodial software wallet. The signing key exists in
process memory while the wallet is unlocked. The controls on this page reduce
operational risk; they do not turn a hot wallet into a hardware security module.

## Recommended use by value at risk

| Value at risk | Recommended setup |
|---|---|
| Testnet / learning | Local hot wallet with throwaway keys |
| Small amounts | Hot wallet + paper backup + small test transfer |
| Meaningful savings | Separate vault accounts, freeze signing, allowlist, per-transaction limit, cold/offline signing |
| Significant holdings | Split across separate wallets, cold/offline signing, offline backups, documented recovery drill |

## Mandatory controls for larger balances

1. **Split the balance.** Do not keep one large balance in one hot account.
2. **Freeze signing** when you are not actively sending.
3. **Recipient allowlist** for every destination you use.
4. **Per-transaction limit** below the amount you would risk losing.
5. **Cold/offline signing** for larger transfers.
6. **Paper recovery phrase**, stored offline and separate from the device.
7. **Test transfer** before every new recipient.
8. **Verify the release SHA-256 and detached signature** before installing.
9. **Dedicated device or OS account** for the wallet.
10. **Documented recovery drill** on a clean device.

## What the wallet provides

- Local key ownership and encrypted storage.
- Argon2id + XChaCha20-Poly1305 vault encryption with a device-bound layer.
- Exact transaction review before local signing.
- Freeze signing, recipient allowlist, and per-transaction limits.
- Cold/offline signing with request/sign/verify/broadcast separation.
- Tor, SOCKS5, SOCKS5h, and HTTP CONNECT routing.
- Encrypted activity logs and receipts.
- Signed release checksums, SBOM, and published test evidence.

## Scope facts

- This is a software hot wallet; a compromised operating system or same-user
  attacker can read an unlocked session.
- There is no hardware secure element and no hardware-wallet integration in the
  1.x scope.
- The project publishes an internal self-audit, not an independent third-party
  audit.
- A blockchain transfer is irreversible; no software can undo a signed transfer.
- Large-value use is an owner risk decision. Follow
  [RISK_CONTROLS.md](RISK_CONTROLS.md) and keep only amounts you can afford to
  lose on any single device.

## Verification

- Test evidence: [TEST_EVIDENCE.md](TEST_EVIDENCE.md)
- Risk controls: [RISK_CONTROLS.md](RISK_CONTROLS.md)
- Data control: [DATA_CONTROL.md](DATA_CONTROL.md)
- Release signature: see the GitHub release page and `SIGNING_CHECKLIST.md`.
