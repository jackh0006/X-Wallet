# X Wallet — risks and limitations

This is the single user-facing risk register. Technical audit evidence lives in
`docs/audits/` and is not a marketing claim.

## Readiness

- **No independent professional audit.**
- **Not approved for large holdings.**
- Stable 1.6.0 is for **small amounts only**.
- Development 2.0.0 is **not a stable release**.

## Blockchain support

- BTC/LTC/DOGE have local derivation, address, transaction and broadcast code,
  but **no live testnet send/receive evidence**.
- Litecoin **MWEB is not implemented**.
- Dogecoin is **P2PKH only**; SegWit, Taproot and RBF are not claimed.
- Bitcoin Taproot is **key-path only**; script-path is not implemented.
- No PSBT, output descriptors, xprv/xpub, watch-only, gap-limit recovery or
  RBF fee bumping.
- No custom UTXO networks.
- The wallet does not validate block headers, PoW, DigiShield or AuxPoW itself;
  it relies on the selected node/indexer for chain data.

## Devices and recovery

- No physical Android test.
- No two-device offline-signing test.
- No real screen-reader session.
- Clean second-install recovery has not been proven with real UTXO funds.
- Dart memory cannot be reliably zeroised; no forensic-erasure guarantee.

## Privacy

- RPC providers and indexers see queried public addresses and the source IP
  unless Tor/proxy is used.
- HTTPS does not hide the queried address from the endpoint.
- Tor does not hide Tor usage from the ISP and does not defeat all correlation.
- No packet capture or DNS-leak test on every platform.
- No telemetry, analytics, AI call or builder upload exists.

## Supply chain

- `bitcoin_base` and `blockchain_utils` are pinned but not independently
  audited here.
- No independent rebuild.
- Release signing keys are owner-controlled; compromise of the device remains
  a risk.

## What would change the decision

1. Live testnet send/receive for BTC, LTC and DOGE.
2. Independent signature verification across all script/sighash cases.
3. PSBT and physical two-device offline signing.
4. Independent rebuild.
5. Independent professional audit.
6. Recovery drill on a clean device.
