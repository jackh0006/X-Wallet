# Changelog

All notable user-facing changes to X Wallet are recorded here. The detailed
engineering history is in [docs/CHANGELOG.md](docs/CHANGELOG.md).

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
