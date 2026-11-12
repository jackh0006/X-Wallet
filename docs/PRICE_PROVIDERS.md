# USD price providers — X Wallet 1.6.0

## Selection

Settings → **USD price source**:

| Value | Behaviour |
|---|---|
| Automatic | Tries CoinMarketCap, then CoinGecko, then Binance. |
| CoinMarketCap | Only CoinMarketCap. Optional API key header. |
| CoinGecko | Only CoinGecko. Optional demo API key header. |
| Binance | Only Binance spot tickers for BNB/ETH. |

A pinned provider is the **only** provider contacted. If it fails, the last
prices remain visible, are marked stale, and the error is shown. The wallet
never silently switches.

## Data sent

Only fixed coin symbols/IDs:

- CoinMarketCap: public listing request, optional `X-CMC_PRO_API_KEY`.
- CoinGecko: fixed IDs such as `ethereum`/`tether`, optional demo key.
- Binance: fixed pair symbols such as `BNBUSDT`/`ETHUSDT`.

No address, balance, vault, device model, timezone or installation ID is sent.

## API keys

- Optional.
- Stored in the platform secure store.
- Sent only to that provider.
- Removed by erase-all.
- Never exported with the wallet or written to logs.

## Limits

- Prices are market indications, not execution guarantees.
- A token without a known ID shows no USD value rather than a guessed one.
- Price selection does not change RPC, explorer or transaction execution.
- Packet capture is not performed in this release.
