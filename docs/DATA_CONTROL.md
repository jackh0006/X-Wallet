# Data Control and AI Boundary

This page documents where wallet data lives, what leaves the device, and why the
builder or an AI coding assistant has no runtime control over user funds.

## Local-only data

| Data | Location | Encrypted |
|---|---|---|
| Vault | `~/.local/share/bnb-wallet/bnb-wallet-vault.bnb` (or custom path) | Yes |
| Device secret | OS secure storage / local drawer | Yes |
| Activity log | App data directory | Yes |
| Receipts | Next to the vault file | Yes |
| Public preferences | App data directory | No secrets |
| Recovery phrase | Shown locally, never transmitted | Not stored in plaintext |

Code references:

- `lib/storage.dart` — local path resolution, atomic writes, permissions.
- `lib/vault.dart` — vault envelope and authentication.
- `lib/kdf.dart` — Argon2id parameters.
- `lib/encrypted_log_store.dart` — encrypted activity log.
- `lib/receipt_store.dart` — encrypted receipts.
- `lib/net/privacy_client.dart` — the network choke point.

## What leaves the device

The app sends only what is required for the selected action:

- JSON-RPC calls to the configured node (balances, nonces, fees, broadcast).
- Optional explorer history requests to BscScan when the user adds an API key.
- A public USD price request to `api.coinmarketcap.com`, with fallback to
  `api.coingecko.com`, `api.binance.com`, or `api.coinbase.com`, containing only
  fixed public coin symbols/IDs. No address, balance, vault, or identifier is sent.
- A public-IP echo request to `api.ipify.org` made only when the user runs the
  privacy, proxy, or external Tor route test. It sends no wallet data.
- No account registration, analytics, ads, telemetry, or AI service calls.

There is no builder-controlled upload endpoint in the application.

## AI boundary

- The app does not call an AI service.
- No AI model receives the vault, private keys, recovery phrase, password, or
  signing material.
- The AI coding assistant works on the public source repository; it has no
  runtime channel into a user's device or wallet.
- The app contains no telemetry SDK and no remote-control channel.
- The user can run the wallet with networking disabled, use Tor/SOCKS, or point
  it at a local node.

This is a design boundary backed by code inspection and the dependency inventory.
It is not a claim that a compromised device, operating system, or browser can
never be attacked.

## How to verify

```bash
# No analytics SDK in the locked dependency inventory
grep -iE "firebase|analytics|sentry|amplitude|mixpanel|segment" \
  pubspec.lock verification/package-lock.json || true

# Secret scan of the current tree
bash scripts/secret-scan.sh

# Dependency and SBOM inventory
python3 scripts/license-check.py
python3 scripts/sbom.py --out docs/SBOM.json

# Inspect the network choke point and RPC call sites
grep -RIn "HttpClient\|IOClient\|http\." lib/net lib/rpc_service.dart
```

## User control

- The user chooses the RPC node and can add a local node.
- The user chooses Tor, SOCKS5, SOCKS5h, or HTTP CONNECT.
- The user can freeze signing, set a recipient allowlist, and set a
  per-transaction limit.
- The user can erase local data from the app.

## Scope

This document describes the code and packaging boundary. It does not replace an
independent audit or a device-level threat model. See
[RISK_CONTROLS.md](RISK_CONTROLS.md) for operating controls.
