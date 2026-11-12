# Ethereum integration — X Wallet 1.6.0

## Supported chains

| Chain | Key | ID | Native | Explorer | API |
|---|---|---:|---|---|---|
| BNB Smart Chain | `mainnet` | 56 | BNB | bscscan.com | api.bscscan.com/v2/api |
| BNB testnet | `testnet` | 97 | tBNB | testnet.bscscan.com | api.bscscan.com/v2/api |
| Ethereum | `ethereum` | 1 | ETH | etherscan.io | api.etherscan.io/v2/api |
| Ethereum Sepolia | `sepolia` | 11155111 | ETH | sepolia.etherscan.io | api.etherscan.io/v2/api |

The registry is `lib/chains.dart`. Every RPC connection checks `eth_chainId`
against the selected chain before any balance, fee or broadcast call.

## What is shared

- EVM address validation and EIP-55 checksums.
- ERC-20 metadata, balance, transfer calldata and `approve` decoding.
- EIP-1559 and legacy fee calculation.
- Transaction review and `SendIntent.verify` binding.
- Receipt parsing, confirmation tracking and local encrypted receipts.
- Cold-wallet codec and signature verification.

## What is chain-specific

- Chain ID, native symbol/name, explorer and API host.
- Default public RPCs and fallbacks.
- Default tokens.
- Explorer API key.
- Block-time/fee behaviour is measured from the selected chain, never assumed.

## Default Ethereum tokens

| Token | Contract | Decimals |
|---|---|---:|
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` | 6 |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | 6 |
| XAUT | `0x68749665FF8D2d112Fa859AA293F07A622782F38` | 6 |

`XAUTUSDT` is a market pair name, not an ERC-20 contract. The wallet ships
XAUT (Tether Gold) itself. Always confirm a contract on the issuer’s official
page before moving funds.

## Tests

- `test/chains_test.dart` — chain IDs, native symbols, defaults, no BNB RPC in
  Ethereum defaults.
- `test/explorer_history_test.dart` — Etherscan/BscScan host, chain ID and key
  isolation.
- `test/ethereum_signing_test.dart` — official EIP-155 vector, Sepolia
  chain-binding and cold chain-1 signing.
- Existing BNB, vault, cold-wallet and privacy tests remain.

## Not tested here

- A live Ethereum node round-trip (no funded node in this environment).
- A physical Android send.
- An independent audit.
