# Data classification

| Class | Examples | At rest | Notes |
|---|---|---|---|
| A — private keys | vault private keys, imported keys | encrypted vault / portable backup | in memory after unlock; no zeroisation |
| B — seed | BIP-39 phrase | encrypted vault / phrase paper | not in prefs/logs |
| C — passwords/keys | vault password, PIN hash, device secret, node credentials | device secret 0600/keyring; PIN/keyring; node creds keyring | vault password never stored |
| D — public wallet data | addresses, watch address, cold pairing | prefs | not secret |
| E — transaction history | receipts, pending tx, activity log | receipts/log encrypted; pending prefs plain but public | BscScan history live |
| F — settings | network, RPC, Tor, theme | prefs plain | no secrets by policy |
| G — cache/temp | Flutter cache, atomic temps, exports | temp 0600; exports plaintext | exports need cleanup |

The classification is implemented for A–C at rest on Linux, with the documented exception that the device secret is a same-user-readable drawer file.
