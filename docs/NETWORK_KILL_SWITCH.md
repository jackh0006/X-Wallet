# Network kill switch — X Wallet

The kill switch is a **fail-closed** user setting, not a label.

When enabled:

- `RpcService.connect`, `_ensureOnline`, balances, fees, simulation, broadcast,
  receipts, history and node probes throw `StateError` before opening a socket.
- `PriceService.refresh` clears prices and returns without creating a client.
- The selected Tor/proxy route is irrelevant: nothing is sent.
- The setting is persisted as `network_kill_switch` and applied at startup
  before the first request.
- Erase-all resets it.

When disabled, the normal selected privacy route applies. The kill switch does
not claim that the OS, browser or another app is prevented from using the
network; it governs the wallet process.

Evidence: `test/network_kill_switch_test.dart` (4 tests) and
`lib/rpc_service.dart` / `lib/price_service.dart`.
