# X Wallet — Project Completion

## What X Wallet is

X Wallet is a free, open-source (AGPL-3.0-or-later), local, non-custodial
EVM-compatible desktop wallet for Linux. Version 1.4.0 enables BNB Smart Chain.
It creates or imports BIP-39 wallets,
derives EVM addresses, signs locally, and stores the vault with Argon2id and
XChaCha20-Poly1305. It also provides a cold/offline signing workflow, optional
Tor/SOCKS routing, transaction review, and a hardened Linux storage path.

## Supported networks

Version 1.4.0 enables BNB Smart Chain mainnet (56) and testnet (97). The
codebase uses EVM primitives, but no other network is enabled or claimed in
this release. Additional EVM networks are planned; do not assume support until
a release documents it.

## Current stable version

**X Wallet 1.4.0** (`1.4.0+9`)

The stable release is published at:

<https://github.com/jackh0006/X-Wallet/releases/tag/v1.4.0>

## Download

Download only from the release page:

- `x-wallet-1.4.0-amd64.deb`
- `SHA256SUMS` and `SHA256SUMS.asc`
- `x-wallet-signing-key.asc`
- SBOM and release documentation

The release is signed with owner key
`CC819EF5E109A1518E840379D8C0CEC84BCCE06B`. Verify the fingerprint through an
independent channel before trusting it.

## Verify the SHA-256

```bash
sha256sum x-wallet-1.4.0-amd64.deb
sha256sum --check SHA256SUMS
```

Compare the output with the SHA-256 published on the GitHub release page. A
matching hash proves the download is the artifact the project published; it
does not prove the project itself is free of defects.

```bash
gpg --import x-wallet-signing-key.asc
gpg --fingerprint CC819EF5E109A1518E840379D8C0CEC84BCCE06B
gpg --verify SHA256SUMS.asc SHA256SUMS
sha256sum --check SHA256SUMS
```

## Supported platform

Verified for the release process:

- Ubuntu 24.04 x86_64 (build, `.deb` install/launch/upgrade/uninstall, Xvfb
  smoke).

Not verified: Debian, Fedora, Linux ARM64, Windows, macOS, Android.
Do not claim support for these until they are built and tested.

A running Secret Service provider (normally `gnome-keyring` on Ubuntu/GNOME or
KWallet on KDE) is required. Minimal or headless sessions without one currently
fail at startup with an unhandled libsecret error; this is a documented
limitation, not a claim of headless support.

## Installation

```bash
sudo apt install ./x-wallet-1.4.0-amd64.deb
```

The Debian package is `x-wallet` and replaces `bnb-wallet` while preserving
the user-data directory and the `/usr/bin/bnb-wallet` compatibility alias.

## Backup and recovery

1. Write the 12/24-word recovery phrase on paper; never store it in a photo,
   cloud note, chat, or password manager.
2. Verify the backup before funding the wallet.
3. To restore, use **Import wallet → recovery phrase** on a clean installation.
4. Confirm the derived address against an independent record.
5. Send a small test amount first.

A copied vault file alone is inert without the device-bound secret. Losing the
recovery phrase and the vault password loses the funds; there is no recovery
service.

## Security model and controls

- The wallet is local and non-custodial; keys never leave the device.
- The vault is encrypted at rest with Argon2id and XChaCha20-Poly1305, plus a
  separate device-bound layer.
- Signing is local and exact; the review screen shows recipient, chain, nonce,
  fees, maximum cost, and calldata.
- Freeze signing, a recipient allowlist, and a per-transaction limit are
  enforced before any transaction is prepared.
- Cold/offline signing is built in for larger transfers, including
  private-key-only wallets.
- One encrypted vault can hold several wallets; add, switch, rename, and remove
  them with one vault password.
- Any non-empty vault password is accepted, with a live strength score and a
  confirmation field so typos cannot silently create an unopenable vault.
- BNB, USDT, and USDC appear by default; the token contracts and 18-decimal
  precision are verified on-chain.
- Default RPC doors are free public HTTPS endpoints: BNB Chain, PublicNode,
  1RPC, Blast, and 48.club.
- The release artifact is signed; verify the published fingerprint and SHA-256.
- RPC data is not light-client verified. Use a trusted or self-hosted node and
  verify large recipients independently.
- Dart memory cannot be guaranteed zeroized; `mlockall` and non-dumpable
  process flags are applied best-effort on Linux.
- Android remains blocked by the historical signing-key incident; the Linux
  `.deb` is unaffected.
- For larger balances, follow [RISK_CONTROLS.md](RISK_CONTROLS.md) and use
  cold/offline signing.

## Internal self-audit scope

The internal self-audit covered the key lifecycle, vault encryption, atomic
storage, transaction construction and signing, cold/offline signing, chain and
recipient validation, token/calldata handling, RPC trust, release identity,
supply chain, CI, logging, and packaging. It is documented in
[`FINAL_SELF_AUDIT.md`](FINAL_SELF_AUDIT.md). It is **not** an independent
external audit.

## Scope of this release

- Linux amd64 (Ubuntu 24.04 verified).
- BNB Smart Chain mainnet (56) and testnet (97).
- Local hot-wallet signing plus cold/offline signing.
- Hardware-wallet integration and multisignature custody are outside the 1.x
  product scope; no support is claimed.
- Token approvals/unlimited allowances are not built; the wallet builds
  transfers only.
- Camera QR scanning on Linux is not implemented; cold transport uses file,
  paste, and QR display.
- Windows, macOS, Linux ARM64, and Android releases are not provided.

## Reporting security issues

Email **jackh109867@gmail.com** privately. Do not open a public issue. Never
send a seed phrase, private key, password, or live wallet file.

## Free use

X Wallet is free to use. There is no subscription, paid license, paywall,
advertisement, or payment required for core wallet functions. Optional
donations are separate from wallet balances and are never requested inside a
transaction confirmation. Blockchain network fees are paid to the network, not
to X Wallet.
