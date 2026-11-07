# Verified Defaults

This page lists the public defaults shipped with X Wallet 1.3.0 and the exact
on-chain or HTTP check used to accept them. Defaults are ordinary public
infrastructure; the user can replace every RPC node and hide or remove every
token.

## Default BSC tokens

| Symbol | Contract | Chain | Decimals | Verification |
|---|---|---|---|---|
| USDT | `0x55d398326f99059fF775485246999027B3197955` | 56 | 18 | `eth_call` `decimals()` → `0x12`; `symbol()` → `USDT` |
| USDC | `0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d` | 56 | 18 | `eth_call` `decimals()` → `0x12`; `symbol()` → `USDC` |

BNB is the native coin and is never hidden; it pays network fees. The token
defaults are merged once per install and are not duplicated by address case.

## Default public RPC doors

Every endpoint below answered `eth_chainId` with the correct chain ID when the
list was verified. None requires an API key.

| Network | URL | Expected chain ID |
|---|---|---|
| BSC mainnet | `https://bsc-dataseed.bnbchain.org` | 56 |
| BSC mainnet | `https://bsc-dataseed-public.bnbchain.org` | 56 |
| BSC mainnet | `https://bsc-dataseed.nariox.org` | 56 |
| BSC mainnet | `https://bsc-rpc.publicnode.com` | 56 |
| BSC mainnet | `https://1rpc.io/bnb` | 56 |
| BSC mainnet | `https://bsc-mainnet.public.blastapi.io` | 56 |
| BSC mainnet | `https://rpc.48.club` | 56 |
| BSC testnet | `https://data-seed-prebsc-1-s1.bnbchain.org:8545` | 97 |
| BSC testnet | `https://bsc-testnet-rpc.publicnode.com` | 97 |

Health is checked by the node manager, including chain-ID match and response
time. A dead or wrong-chain endpoint is not used for signing or broadcasting.

## History API

Transaction history uses the chain-aware BscScan V2 endpoint:

- Mainnet/testnet: `https://api.bscscan.com/v2/api`
- A BscScan API key is required. Add it in Settings → History. The local
  receipt archive and balances do not require a key.

BscScan plan rules are set by BscScan, not by X Wallet. If the provider
requires a paid plan for a chain, the history request returns that message
verbatim; the wallet does not invent a fallback or hide the error.

## Reproduce these checks

```bash
# Chain ID for each public RPC
curl -sS -X POST -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
  https://bsc-dataseed.bnbchain.org

# USDT decimals and symbol
curl -sS -X POST -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_call","params":[{"to":"0x55d398326f99059fF775485246999027B3197955","data":"0x313ce567"},"latest"]}' \
  https://bsc-dataseed.bnbchain.org
```
