# Feature inventory

| Feature | Implemented | Tested | Documented | Status |
|---|---|---|---|---|
| BIP-39 create/import | yes | yes | yes | stable |
| BIP-32/44 accounts | yes | yes (default path) | yes | stable; custom path not exposed |
| Encrypted vault | yes | yes | yes | stable |
| Multi-account vault | yes | yes | yes | stable |
| Multi-vault (3) | yes | yes | yes | stable; registry atomicity gaps |
| Change vault password | yes (UI) | yes | yes | stable |
| Portable backup/restore | yes | yes (fast KDF; fresh-device model) | yes | stable; production-param e2e partial |
| BSC mainnet/testnet | yes | yes (Anvil blocked here) | yes | stable |
| Native/ERC-20 send | yes | yes | yes | stable |
| Approve/increase/transferFrom review | yes | yes (new binding test) | yes | stable |
| Fee engine | yes | yes | yes | no hard cap/ratio |
| Hold-to-confirm | yes | yes | yes | stable |
| Spending freeze/allowlist/limit | yes | yes (send/bump only) | yes | cold path fixed in this branch |
| Tor/SOCKS/HTTP proxy | yes | partly | yes | per-node fallback fixed; no pcap |
| Offline/cold mode | runtime gate | yes (prices/startup) | yes | binary still links network |
| Cold signing | yes | yes (automated) | yes | no physical two-device test |
| Encrypted log/receipts | yes | yes | yes | shared log/receipt across vaults |
| Erase all | yes | yes (deadlock test) | yes | legacy dirs still survive |
| Android APK | yes | signed/built; no device | yes | device run unverified |
| Linux `.deb` | yes | launch smoke | yes | apt install/upgrade unverified |
