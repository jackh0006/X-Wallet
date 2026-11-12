# Network egress inventory — X Wallet 1.6.0

This is the complete list of destinations the wallet code can contact. It does
not include the optional `xdg-open` browser action the user triggers from a
link.

| Destination | Purpose | Data sent | Data received | Address sent? | Device metadata? | Necessary? |
|---|---|---|---|---|---|---|
| Selected BNB RPC node | Balances, nonce, fees, simulation, broadcast, receipts | JSON-RPC method and parameters (public address, tx data) | Chain data | Yes, to that node only | No app/device header | Yes |
| Selected Ethereum RPC node | Same for Ethereum | Same | Chain data | Yes, to that node only | No | Yes |
| BscScan API | BNB history | Public address, chain ID 56/97, API key | Tx list | Yes | No | Only if the user enables history |
| Etherscan API | Ethereum history | Public address, chain ID 1/11155111, API key | Tx list | Yes | No | Only if the user enables history |
| CoinMarketCap | USD prices | Fixed coin symbols via the public listing endpoint; optional API key header | Prices | No | No | Only if USD display is on |
| CoinGecko | USD prices | Fixed coin IDs; optional demo API key header | Prices | No | No | Only if USD display is on |
| Binance spot ticker | USD prices for BNB/ETH | Fixed pair symbol | Price | No | No | Only if USD display is on and chosen/auto |
| Tor SOCKS proxy | Transport for the above | TLS bytes | TLS bytes | The destination sees the exit IP, not the user IP | No | Optional |
| User HTTP/SOCKS proxy | Transport | TLS bytes | TLS bytes | Proxy sees destination and source IP | No | Optional |
| — | Network kill switch | Nothing | Nothing | — | — | Blocks all of the above |

## What is never sent

- Seed phrase, private key, vault contents, vault password, vault name, wallet
  label.
- Device model, manufacturer, IMEI, serial, advertising/installation ID,
  timezone, locale, contacts, installed apps.
- Analytics, telemetry, crash reports, AI prompts.
- A wallet address to a price provider.
- A BNB address to an Ethereum service or vice versa.
- Custom headers that could carry cookies, referer/origin, authorization,
  API keys, host/framing or CRLF.

## Residual observations

- An RPC provider learns the queried public addresses and the source IP unless
  Tor/proxy is used. HTTPS does not hide either.
- An explorer learns the queried address and (if supplied) the API key.
- A price provider learns the source IP and that the wallet requested a price,
  unless routed through Tor/proxy.
- The operating system, DNS resolver and network operator remain outside the
  wallet’s control.
- Physical packet capture is **NOT PERFORMED**; this inventory is code-based.
