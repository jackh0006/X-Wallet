# Privacy audit

## Data that leaves the device

| Destination | Default | Data | Control |
|---|---|---|---|
| Configured RPC / phone-book nodes / built-in fallbacks | on | addresses, balances, nonce, fees, calldata, signed raw tx | RPC settings, node book, strict mode |
| BscScan `txlist` | off (API key required) | wallet address + API key in the URL | Settings key |
| CoinMarketCap / CoinGecko / Binance | **off** (`show_usd=false`) | fixed coin IDs only | Settings USD |
| `api.ipify.org` | user button only | source IP | route test |
| External browser / `xdg-open` | user action | tx hash / URL | explicit tap |
| Tor directory/guard traffic | only when Tor enabled | Tor protocol | Tor settings |

No telemetry, analytics, crash reporting, ads, Firebase, AI API, remote config, cloud sync, webhook or developer server was found in `lib/`, `pubspec.lock`, `android/` or `linux/`.

## Fixes in this audit branch

- Per-node Tor/custom proxy no longer falls back to built-in public nodes: `connect()` and the fee/independent pools suppress public fallbacks when the active/configured node pins a transport.
- Tor setup failures no longer turn the route off and silently go direct; the route remains selected and fails closed.
- Cold mode now gates `feeQuote`, `feeSnapshot`, `probePublicIp` and `probeProxyRoute`; the fee path previously bypassed the offline flag.
- USD prices are off by default and gated in cold mode.

## Remaining risks

- **BscScan API key is sent in the query string** (URLs may appear in proxy/node logs). A header would be safer.
- **Custom node headers** may include `cookie`/`accept-language`/`referer`; only a prefix denylist is enforced. A strict allowlist is safer.
- **Android Network Security Config contradicts supported HTTP LAN/`.onion` modes**: the app validates HTTP for loopback/LAN/onion, but the manifest/NSC denies cleartext. dart:io bypasses NSC, so the setting is decorative for app sockets; plugin/WebView traffic would break.
- **RPC provider sees addresses and timing** unless Tor is on. This is inherent to light wallets.
- **No packet capture** is committed for 1.5.3. The privacy claims are code/test based, not pcap based.
