# Changelog

All notable user-facing changes to X Wallet are recorded here. The detailed
engineering history is in [docs/CHANGELOG.md](docs/CHANGELOG.md).

## 1.6.0 — 2026-11-13

- Add Ethereum mainnet (1) and Sepolia (11155111) alongside BNB Smart Chain.
- Ship canonical Ethereum USDT, USDC and XAUT (Tether Gold) defaults.
- Keep explorer API keys separate per chain: BscScan for BNB, Etherscan for
  Ethereum.
- Add a user-selectable USD price provider with optional secure API keys.
- Make Home, Send, Wallet, Receipt, Activity and Settings chain-aware.
- Cold signer accepts every registered chain and rejects unknown chain IDs.

## 1.5.5 — 2026-11-12

- Transaction review now binds the **nonce and sender** to the exact signed
  transaction; a change after review refuses the signature.
- Cold pairing fingerprints cover the chain and **every** paired address.
- “Erase all data” removes known pre-1.2 application-data directories,
  including their vault and plaintext device secret.
- Android file import is capped at 8 MiB.
- Custom RPC headers cannot add cookies, referer/origin, authorization, API
  keys, host/framing headers, CR/LF or oversized values.
- The release gate has a strict source mode and a post-release verifier that
  re-downloads the published assets and checks their signatures and APK signer.

## 1.5.0 — 2026-11-10

- Android ships the native reference Argon2id library; the 64 MiB/t=3/p=4
  parameters are unchanged.
- Vault keys clear on background/idle even without a PIN.
- New PINs are 6–12 digits, trivial PINs are refused, and optional
  wipe-after-10-failures is on by default.
- Biometric unlock is strong-biometric-only; secure storage fails closed.
- Android rejects obscured overlay touches and keeps FLAG_SECURE on.
- R8 minification, resource shrinking, and Dart obfuscation for release APKs.
- New blue Material 3 theme, Home hero, Activity tab, USD toggle, adaptive icon
  and Android 12+ splash.
- Explorer/source links open in the Android browser; desktop-only storage
  controls are hidden on Android.
- English-only UI remains; no analytics, ads, accounts, or AI endpoints.

## 1.4.3 — 2026-11-10

- Show public USD values under assets on the Android dashboard, Home, and Send.
- Show the available balance and its USD value before sending.
- Keep pending transfers and saved receipts in Recent activity on Android.
- Keep the app English-only and the Linux desktop layout unchanged.
- Price lookup sends only fixed public coin IDs to CoinGecko; route test shows
  the public IP seen by the outside service.

## 1.1.0 — 2026-11-06

- Renamed the product to **X Wallet** across the application, six locales,
  window title, Android label, desktop entry, icons, documentation, and tests.
- Migrated the Debian package to `x-wallet` with
  `Provides/Replaces/Conflicts: bnb-wallet`; existing user data and the
  `/usr/bin/bnb-wallet` compatibility alias are preserved.
- Added the original X Wallet icon set.
- Added branding and free-use validators.
- Added the final internal self-audit, project completion guide, and full test
  evidence page.
- Signed the published release checksum manifest with the owner GPG key.

## 1.0.10 and earlier

See [docs/CHANGELOG.md](docs/CHANGELOG.md) for the complete history.
