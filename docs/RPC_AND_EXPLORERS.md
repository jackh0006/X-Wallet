# RPC and explorer configuration — X Wallet 1.6.0

## Independent per-chain configuration

Every `RpcNode` stores a `network` key. The wallet only uses nodes whose
`network` equals the selected chain. The chosen node is also persisted as
`rpc_<network>`; switching chains restores that chain’s last node and never
overwrites another chain’s choice. A BNB node is never used for an Ethereum
balance, and changing Ethereum nodes does not change BNB nodes.

- Add, edit, enable/disable, reorder, test and remove nodes in Settings.
- The node test checks HTTPS, host reachability, `eth_chainId` and latency.
- Strict mode uses only the selected node; no fallback.
- Non-strict mode may use that chain’s documented public fallbacks.
- A wrong chain ID is refused before balances, fees or broadcast.

## Recommended defaults

| Chain | First default | API key |
|---|---|---|
| BNB mainnet | `https://bsc-dataseed.bnbchain.org` | BscScan |
| BNB testnet | `https://data-seed-prebsc-1-s1.bnbchain.org:8545` | BscScan |
| Ethereum | `https://ethereum-rpc.publicnode.com` | Etherscan |
| Sepolia | `https://ethereum-sepolia-rpc.publicnode.com` | Etherscan |

Public providers are labelled “public”; they are not claimed to be the fastest
or most secure.

## Explorer keys

- BscScan key: used for chain 56/97 history only.
- Etherscan key: used for chain 1/11155111 history only.
- Keys are stored in the platform secure store, never in SharedPreferences,
  logs, exports or the vault.
- Removing a key disables history for that chain; balances and sends still
  work.
- Erase-all removes every explorer key.

## What the RPC provider sees

The selected RPC provider sees the public addresses you query, the transaction
payloads you simulate/broadcast, and your source IP unless Tor/proxy is used.
It never sees the seed, private key, password or vault contents. See
`docs/PRIVACY_EGRESS.md`.

## What the explorer sees

The explorer receives the public address you request history for, the chain ID
and your API key. It does not receive the seed, private key or vault.
