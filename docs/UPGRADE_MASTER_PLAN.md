# Upgrade master plan — X Wallet 1.6.0

Started from `1.5.5+17` (`ead3237`). The plan is staged so each change has a
focused test and a recorded decision. No stage is marked complete without
evidence.

## Stage 0 — Baseline

- [x] Recorded in `docs/BASELINE_TEST_REPORT.md`.
- [x] Static analysis clean; 47 focused vault/send/fee tests pass.

## Stage 1 — Chain abstraction

- [x] `lib/chains.dart` registry for BNB mainnet/testnet and Ethereum
  mainnet/Sepolia with explicit chain IDs, native symbols, explorers, APIs,
  default RPCs and fallbacks.
- [x] `BnbNetworks` now delegates to the registry (legacy call sites keep
  working).
- [x] Per-chain explorer keys; a BscScan key is never used for Etherscan.
- [x] Per-chain default node reset.
- [x] Cold signer accepts every registered chain and rejects unknown IDs.

## Stage 2 — Ethereum integration

- [x] Ethereum native balance, ERC-20 metadata/balance, transfers, fees and
  receipts reuse the existing EVM path with `chainId = 1`.
- [x] Sepolia is selectable for practice.
- [x] Default Ethereum tokens: USDT, USDC and XAUT (Tether Gold).
- [x] Ethereum explorer history through Etherscan v2 (`chainid=1`).
- [x] Canonical EIP-155 signing vector test.
- [x] Cold EIP-1559 signing on chain 1 and chain-binding regression test.

## Stage 3 — Vault and identity

- [x] Existing multi-vault code already gives each vault a separate password
  and encryption; baseline rename test preserved the recovery phrase.
- [x] Rename path re-encrypts the decrypted record atomically.
- [ ] A dedicated “one authoritative vault display name” model is **not**
  added; the current account label is the single stored name. Documented in
  `docs/IMPLEMENTATION_DECISIONS.md`.

## Stage 4 — Nodes, explorers, prices

- [x] Independent node lists per chain (existing model already keyed by
  `network`; reset/defaults extended to Ethereum).
- [x] Explorer API keys isolated per chain.
- [x] User-selectable price provider with optional secure API keys.
- [x] Pinned provider never silently falls back.

## Stage 5 — Privacy

- [x] Price requests contain fixed symbols/IDs only.
- [x] Custom headers reject cookies, referer/origin, auth, API keys, host,
  framing and CRLF.
- [x] No device model, timezone, installation ID or wallet name is sent by the
  wallet code.
- [x] Egress inventory documented in `docs/PRIVACY_EGRESS.md`.
- [ ] Packet capture and OS-level air-gap test remain **NOT PERFORMED**.

## Stage 6 — High-value security

- [x] Transaction review binds chain, sender, recipient, amount, token,
  calldata, nonce and fee to the exact signed object.
- [x] Large-transfer confirmation and hold-to-confirm remain.
- [ ] Hardware-wallet integration is **NOT IMPLEMENTED**.
- [ ] Multisignature / threshold custody is **NOT IMPLEMENTED**.
- [ ] Time-delay / policy engine beyond the existing local spending policy is
  **NOT IMPLEMENTED**.

These are external-standard integrations, not something to fake. Safe options
are documented in `docs/IMPLEMENTATION_DECISIONS.md`.

## Stage 7 — UI

- [x] Chain selector shows all four supported networks.
- [x] Native symbol and chain name are dynamic on Home, Send, Wallet, Receipt,
  Activity and Settings.
- [x] Ethereum token rows use the existing shared components.
- [ ] Full accessibility audit with a screen reader remains **NOT PERFORMED**.

## Stage 8 — Testing

- [x] New tests: chain registry, Ethereum token defaults, explorer endpoint
  isolation, price-provider pinning, EIP-155 vector, cold chain binding.
- [x] Existing BNB, vault, cold-wallet and privacy tests.
- [ ] Physical Android run, independent rebuild and independent audit remain
  **NOT PERFORMED**.

## Stage 9 — Documentation and release

- [x] Baseline, plan, progress, decisions, acceptance criteria and egress
  inventory.
- [x] Version, changelog, release note, SBOM and evidence refreshed.
- [ ] Release artifacts are built, signed and verified in the release run.
