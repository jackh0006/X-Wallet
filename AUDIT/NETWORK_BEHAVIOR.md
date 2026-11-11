# Network behavior test matrix

| Scenario | Method | Result |
|---|---|---|
| Direct HTTPS RPC | code/test | PASS (chain ID check) |
| Tor/proxy at startup | dead-SOCKS test | PASS (fails, no direct) |
| Tor setup failure | code review | FIXED: route stays selected, fails closed |
| Per-node Tor with a dead node | code review | FIXED: public built-in fallbacks suppressed |
| Cold mode price lookup | test | PASS (no client) |
| Cold mode fee quote | code review | FIXED: `_ensureOnline` |
| Cold mode IP/route probe | code review | FIXED: mode check |
| Malicious RPC HTML/oversize | mock test | PASS for `_postJson`; web3dart/history gaps remain |
| Wrong chain ID | test | PASS on connect/probe; not every fee/receipt call |
| TLS wrong pin | openssl test | PASS (pin after CA/hostname) |
| TLS user/CA failure | code/test | PASS (no bypass callback) |
| HTTP CONNECT + pin | test | REFUSED |
| DNS in Tor/socks5h | code review | remote ATYP=domain; no pcap |
| Android cleartext | manifest review | NSC denies cleartext; dart:io bypasses NSC for app sockets |
| App background/restart | code review | no hidden reconnect; transport rebuilt |

## Not run here

- Real packet capture / `strace` over a full session.
- A live Tor circuit.
- A malicious TLS proxy with a test CA.
- Android network monitoring.
