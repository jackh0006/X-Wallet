# Blockchain compatibility

- BNB Smart Chain mainnet 56 and testnet 97 only. No other chain is enabled.
- EVM address, EIP-55, legacy EIP-155 and EIP-1559 transactions.
- ERC-20 transfer/approve/increaseAllowance/transferFrom decode; `transferFrom` word 0 (`from`) is decoded but not displayed.
- Token decimals are bounded (0–36); symbols are display-only and can lie; the contract is shown.
- Mainnet/testnet distinction is text-only; no colour/banner.
- Real-EVM integration (`test/integration/anvil_test.dart`) is 3 tests but requires `ANVIL_URL`; Anvil is not installed in this environment, so it is **BLOCKED** here.
- `verification/verify.cjs` cross-checks one EIP-1559 transaction with ethers.js. No legacy EIP-155 vector and no random differential fuzz.
