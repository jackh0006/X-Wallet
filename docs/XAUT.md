# XAUT — Tether Gold

## What it is

XAUT is an ERC-20 token issued by Tether that represents a claim on allocated
gold. Holding XAUT is **not** the same as holding physical gold, and it is not
a guarantee of redemption. Issuer terms, custody, audits, redemption conditions
and jurisdictional rules apply off-chain.

## Canonical Ethereum contract

| Field | Value |
|---|---|
| Network | Ethereum mainnet (chain ID 1) |
| Contract | `0x68749665FF8D2d112Fa859AA293F07A622782F38` |
| Symbol | `XAUT` |
| Decimals | 6 |
| Issuer | Tether |

“XAUTUSDT” is a **market pair**, not an ERC-20 contract. X Wallet ships XAUT,
not a token invented for that pair name.

## Verification

1. Open Tether’s official XAUT page: <https://gold.tether.to/>.
2. Open the contract on Etherscan:
   <https://etherscan.io/address/0x68749665FF8D2d112Fa859AA293F07A622782F38>.
3. Compare the contract address, name, symbol and decimals.
4. Do not trust a token merely because its symbol is “XAUT”.

The built-in registry marks this exact contract as canonical. Any other
contract with the same symbol is shown as unverified.

## Wallet behaviour

- The token is listed only on Ethereum mainnet.
- Balances are read from the contract; no balance is hardcoded.
- Transfers use standard ERC-20 calldata with the reviewed contract address.
- The token logo falls back to a neutral icon; the wallet does not substitute
  an unofficial logo.
- The wallet does not claim that XAUT is physical gold or that redemption is
  guaranteed.

## Evidence

- Contract constant: `lib/default_tokens.dart`.
- Registry entry: `lib/token_registry.dart`.
- Test: `test/chains_test.dart`.
- Issuer/official link: <https://gold.tether.to/>.
- Explorer link: <https://etherscan.io/token/0x68749665FF8D2d112Fa859AA293F07A622782F38>.
