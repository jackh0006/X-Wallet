# Network audit

## Verified controls

- All `HttpClient`/`IOClient` construction is in `lib/net/privacy_client.dart`; `test/data_boundary_test.dart` now checks `HttpClient(`, `IOClient(`, `http.Client(`, `http.get/post`, sockets and launch sites against an allowlist and checks `pubspec.yaml` **and** `pubspec.lock` for telemetry names.
- `User-Agent` is null; only `content-type: application/json` plus transport headers are sent on RPC.
- TLS standard CA/hostname validation runs before SPKI pinning; pin+HTTP CONNECT is refused (`test/tls_pinning_test.dart`).
- SOCKS5h/Tor uses remote DNS; `socks5` uses local DNS by design.
- The transport is rebuilt after preferences load; a dead SOCKS port fails instead of direct (`test/privacy_startup_test.dart`).
- RPC responses are capped at 2 MiB and methods are allowlisted in `_postJson`; URL credentials and cloud metadata targets are rejected (`test/rpc_adversarial_test.dart`).
- Node proxy/bearer/header credentials live in the platform secure store and are stripped from export (`test/node_secret_storage_test.dart`).

## Remaining gaps

- web3dart paths (`getBalance`, `sendRawTransaction`, `receipt`) and BscScan `history` do not all go through the 2 MiB/allowlist choke point.
- Chain-ID is rechecked on connect/probe, not on every fee/receipt/broadcast/batch call.
- `_postJson` accepts any `http(s)` URL without re-applying `nodeUrlAllowed`.
- IPv6 link-local/ULA/IMDS variants and `100.100.100.200` are not rejected by the URL policy.
- BscScan history uses the global transport, not the node's transport, and auto-runs on the Wallet tab when a key exists.
- No real packet capture or `strace` artifact is committed.
