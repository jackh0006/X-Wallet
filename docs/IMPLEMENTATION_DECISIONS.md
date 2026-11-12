# Implementation decisions — 1.6.0

## Chain keys remain the storage keys

Existing vaults, node rows, receipts and preferences persist
`mainnet`/`testnet`. The new registry keeps those keys and adds `ethereum`
and `sepolia`:

| Key | Chain ID | Native | Family |
|---|---:|---|---|
| `mainnet` | 56 | BNB | BNB |
| `testnet` | 97 | tBNB | BNB |
| `ethereum` | 1 | ETH | Ethereum |
| `sepolia` | 11155111 | ETH | Ethereum |

Renaming keys would break existing data. Display names come from
`ChainSpec`, never from the storage key.

## One shared EVM path, explicit chain facts

Ethereum and BNB share the EVM transaction, ERC-20 and fee code. Chain-specific
facts (ID, native symbol, explorer, API, defaults) live in `ChainSpec`. No
code assumes BNB’s chain ID, symbol or explorer any more.

## Ethereum default tokens

| Token | Contract | Decimals |
|---|---|---:|
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` | 6 |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | 6 |
| XAUT | `0x68749665FF8D2d112Fa859AA293F07A622782F38` | 6 |

“XAUTUSDT” is a market pair, not an ERC-20 contract. The wallet ships the
canonical token as **XAUT** and does not invent a contract for the pair name.

## Node choice is per chain

The selected RPC is stored as `rpc_<network>` and restored on chain switch. The
legacy single `rpc` value is migrated only to BNB mainnet. This prevents a BNB
node from becoming the Ethereum node after a restart (self-audit SA-10).

## Explorer keys are per chain family

A BscScan key is sent only to BscScan. An Etherscan key is sent only to
Etherscan. The legacy single BscScan key is migrated to the BSC mainnet slot.
Erase-all removes every explorer key.

## Price providers

The user picks a provider. `auto` keeps the documented fallback order; any
pinned provider is the only one contacted. A failed pinned provider leaves the
last prices in place, marks them stale and shows the error. It never silently
switches.

Optional CoinMarketCap and CoinGecko keys are stored in the platform secure
store and are never exported. They are sent only to that provider.

## Vault names

The encrypted account `label` is the single stored display name. The rename
operation mutates that field in the decrypted record and re-encrypts atomically;
it never touches the private key, mnemonic, address, derivation path or
history. Adding a second “wallet name” field would create two sources of truth.

## Cold-wallet chains

The cold codec now accepts every chain in `ChainSpec` and rejects unknown
chain IDs. EIP-1559 is supported for both BNB and Ethereum. Legacy cold
transactions are not shipped; the hot path supports legacy fees, the cold path
uses type-2 transactions.

## Not implemented, deliberately

- **Hardware wallets:** requires a real device protocol and a supported library;
  no proprietary protocol was invented.
- **Multisig/threshold custody:** requires a standard contract or descriptor
  format, deployment assumptions and independent audit. A password vault is
  not multisig.
- **Time-delay policy engine:** not shipped without a reviewed recovery path.
- **Independent audit:** cannot be produced by the development agent.

These are listed as blockers, not sold as features.
