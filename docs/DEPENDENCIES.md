# Dependency review — 2.0.0 branch

This is a review record, not a claim that every transitive package was audited.

## New UTXO dependencies

| Package | Version | Purpose | License | Network | Secrets | Notes |
|---|---|---|---|---|---|---|
| `bitcoin_base` | 7.3.0 | BTC/LTC/DOGE addresses, scripts, transaction builder/signing, P2TR, PSBT primitives | BSD-3-Clause | No automatic calls; provider helpers exist but the wallet uses its own HTTP service | Handles private keys in memory | Pinned exact version. Public API is broad; only the used subset is covered by tests. |
| `blockchain_utils` | 7.1.0 | BIP32/BIP39/BIP44/49/84/86 derivation, WIF, hashing utilities | BSD-3-Clause | No | Handles seed/private key bytes | Direct dependency added because `utxo_wallet.dart` imports it. |

## Why these are used

Implementing secp256k1, BIP32, BIP39, Base58Check, Bech32/Bech32m, Taproot
tweaks and transaction serialization by hand would be unsafe. The library is
used for those primitives; the wallet still builds its own network registry,
fee/coin selection policy, kill-switch gate and review UI.

## Existing dependencies

The EVM path continues to use `web3dart`, `wallet`, `bip32_plus`,
`bip39_mnemonic`, `pointycastle` and `http`. Their versions are locked in
`pubspec.lock`; the full inventory is in `docs/SBOM.json`.

## Supply-chain controls

- Exact versions pinned for the two new packages.
- `flutter pub get` resolves a locked graph.
- Secret scan, licence inventory and SBOM generation run in CI.
- Release artifacts are signed and checksummed.
- No dependency receives a recovery phrase, private key or vault password.

## Known gaps

- No independent professional review of `bitcoin_base`.
- No differential test against a second Bitcoin implementation yet.
- PSBT/descriptors are not integrated, so the corresponding library surface is
  not exercised by the wallet.
