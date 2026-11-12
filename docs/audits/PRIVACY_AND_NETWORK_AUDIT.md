# Privacy and network audit — 2.0.0 branch

## Outbound inventory

| Destination | Data | Kill switch | Route |
|---|---|---|---|
| BNB/Ethereum RPC | public addresses, tx data | Yes | Tor/proxy/inherit |
| BscScan/Etherscan | public address + API key | Yes | Tor/proxy/inherit |
| mempool.space | BTC address or raw tx | Yes | Tor/proxy/inherit |
| litecoinspace.org | LTC address or raw tx | Yes | Tor/proxy/inherit |
| BlockCypher | DOGE address or raw tx | Yes | Tor/proxy/inherit |
| Price providers | fixed symbols/IDs | Yes | Tor/proxy/inherit |
| User-opened explorer | txid/address in URL | Not applicable (browser) | User browser |

## Checks

- `RpcService._ensureOnline` and `connect` block on kill switch.
- `UtxoService._guard` blocks before any request.
- `PriceService.refresh` clears prices and returns.
- No telemetry, analytics, AI or builder upload.
- No wallet secret is sent to any indexer/provider.
- Tor/proxy failure is fail-closed by the existing privacy client.

## Not proven

- Packet capture.
- DNS leak test on every platform.
- Behaviour of the OS/browser outside the wallet process.

Public addresses and source IP are visible to whichever RPC/indexer receives
the query. Tor/proxy reduces, but does not eliminate, correlation risk.
