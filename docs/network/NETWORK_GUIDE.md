# NETWORK_GUIDE.md — Network Configuration and Privacy Guide

**Date**: 2026-11-03
**Baseline Commit**: `68091b06cce3e9c90692e3f632d539ae69734154`

---

## For Users: Choosing Your Connection Mode

### Quick Decision Guide

| Your Situation | Recommended Mode | Why |
|----------------|------------------|-----|
| **Home, trusted network, no privacy concerns** | Direct | Simplest, lowest latency |
| **Corporate/uni network with proxy** | HTTP/HTTPS Proxy | Required by network policy |
| **Public Wi-Fi, want IP privacy** | Tor | Hides IP from RPC; ISP sees only Tor |
| **Censored country, Tor blocked** | Tor Bridge (obfs4) | Bypasses Tor blocking |
| **Running own VPS/node** | Tor → VPS or SOCKS5 → VPS | VPS sees Tor exit / proxy IP |
| **Maximum privacy, technical user** | Strict Privacy + Tor | All traffic forced, fail-closed |
| **Cold signer (offline device)** | Offline Mode | Zero network access |
| **Watch-only companion** | Direct/Tor/Proxy (no keys) | No signing capability |

---

## Connection Mode Details

### 1. Direct HTTPS
- **How it works**: App → TLS → RPC endpoint
- **ISP sees**: RPC hostname (SNI), IP, timing, volume
- **RPC sees**: Your real IP, all requests
- **Setup**: Just enter RPC URL (must be HTTPS)
- **Best for**: Trusted home network, local node

### 2. HTTP/HTTPS Proxy (CONNECT)
- **How it works**: App → HTTP CONNECT → Proxy → TLS → RPC
- **ISP sees**: Proxy IP, CONNECT hostname
- **Proxy sees**: Your IP, destination hostname, all traffic (HTTPS proxy: only CONNECT metadata)
- **RPC sees**: Proxy exit IP
- **Setup**: Settings → Network → Proxy → HTTP/HTTPS → host:port (+ auth if needed)
- **Certificate validation**: Always enforced (no bypass)
- **Best for**: Corporate networks, controlled proxy

### 3. SOCKS5 Proxy
- **How it works**: App → SOCKS5 → Proxy → TLS → RPC
- **ISP sees**: Proxy IP
- **Proxy sees**: Your IP, destination hostname (SOCKS5h), all traffic
- **RPC sees**: Proxy exit IP
- **Setup**: Settings → Network → Proxy → SOCKS5 → host:port (+ auth)
- **DNS**: Remote resolution (no local DNS leak)
- **Best for**: General proxy, SSH tunnels (`ssh -D`)

### 4. Tor (System Daemon)
- **Prerequisites**: `sudo apt install tor` (Ubuntu) or Orbot (Android)
- **Default**: SOCKS5 on `127.0.0.1:9050`
- **How it works**: App → Tor SOCKS5 → 3-hop circuit → TLS → RPC
- **ISP sees**: Tor entry guard IP, encrypted Tor traffic
- **Tor entry**: Your IP
- **Tor exit**: RPC destination IP, TLS handshake
- **RPC sees**: Tor exit node IP
- **Setup**: Settings → Network → Tor → Enable (auto-detects 127.0.0.1:9050)
- **Bridges**: Configure in `/etc/tor/torrc` or Orbot; app just uses SOCKS5
- **Fail-closed**: If Tor stops, requests fail — **no direct fallback**

### 5. Tor Bridges
- **obfs4**: `Bridge obfs4 <IP>:<PORT> <FINGERPRINT> cert=<CERT> iat-mode=0`
- **WebTunnel**: `Bridge webtunnel <IP>:<PORT> <FINGERPRINT> url=<URL>`
- **Configure in**: Tor daemon config (`/etc/tor/torrc`) or Orbot
- **App behavior**: Unchanged — still uses local Tor SOCKS5

### 6. Strict Privacy Mode
- **What it does**: Enforces selected route for **ALL** traffic
- **RPC**: Through route
- **Explorer (BscScan)**: Through route
- **Token metadata**: Through route
- **Price APIs**: Through route (if enabled)
- **Update checks**: none exist in this app
- **Fail-closed**: Any route failure = error shown, no fallback
- **Enable**: Settings → Network → Strict Privacy Mode

### 7. Offline Mode
- **What it does**: Blocks all **app-initiated** network calls (RPC, prices,
  explorer history, node probes). It is a runtime gate, not an OS sandbox; for
  a dedicated air-gapped machine, also run the app under `unshare -n` or a
  systemd unit with `PrivateNetwork=yes` (see `docs/COLD_WALLET.md`).
- **DNS**: Not resolved
- **RPC**: Not polled
- **Tor/Proxy**: Not connected
- **Updates**: Not checked
- **Use case**: Cold signer device, air-gapped operation
- **Enable**: Settings → Wallet Mode → Cold (offline signer) — auto-enables

---

## Per-Node Transport Override

Each RPC node can have its own transport:
- **Inherit** (default): Uses global mode
- **Direct**: This node only — direct HTTPS
- **Tor**: This node only — through Tor
- **Custom Proxy**: This node only — specific SOCKS5

**Configure**: Settings → Nodes → Edit Node → Transport

---

## Node Management

### Adding a Custom Node
1. Settings → Nodes → Add Node
2. **Name**: Descriptive label
3. **URL**: `https://...` (HTTP only for localhost/LAN/.onion)
4. **Network**: Mainnet (56) or Testnet (97)
5. **Transport**: Inherit / Direct / Tor / Custom Proxy
6. **Auth**: Optional Bearer token / Basic auth / Custom headers
7. **Test**: Runs 9-check checklist before saving

### 9-Check Node Test
| Check | Blocks Save If Failed |
|-------|----------------------|
| Reachable | ✅ |
| Correct Chain ID | ✅ |
| Chain Head Freshness | ⚠️ (warning only) |
| Gas Price (eth_gasPrice) | ⚠️ |
| EIP-1559 Fee History | ⚠️ |
| Pending Nonce | ⚠️ |
| eth_call | ⚠️ |
| eth_estimateGas | ⚠️ |
| sendRawTransaction (probe) | ⚠️ (invalid payload — never broadcasts) |

### Strict "Use Only My Node"
- **Enable**: Settings → Nodes → "Use ONLY my node"
- **Behavior**: Exactly one active node; no fallbacks; no built-in doors
- **Fee/Receipt pools**: Only your node (honest single-node badge)

---

## Network Status Dashboard

**Location**: Home tab → Network card

| Indicator | Values | Meaning |
|-----------|--------|---------|
| **Mode** | Direct / HTTP Proxy / HTTPS Proxy / SOCKS5 / Tor / Bridge / Offline | Active connection mode |
| **Route** | VERIFIED / NOT VERIFIED / WARNING / FAILED | Last connectivity test |
| **Tor** | Connected / Not Running / Bridge Configured | Tor daemon status |
| **Proxy** | Connected / Auth Failed / Unreachable | Proxy status |
| **DNS** | Remote / Local / FAILED | DNS resolution path |
| **TLS** | Valid / Pinned / FAILED | Certificate status |
| **RPC** | URL + Chain ID + Last Test | Active endpoint |
| **Strict** | ENABLED / DISABLED | Strict privacy enforcement |

**Never trust a green status unless you ran the test yourself.**

---

## VPS-Through-Tor Setup (Advanced)

**Goal**: Your VPS RPC endpoint sees only Tor exit IP

### On Your VPS
1. Run RPC node (Erigon/Geth/Bor) with HTTPS (Let's Encrypt or self-signed + CA)
2. Restrict access: firewall to Tor exit IPs (optional, but recommended)

### In X Wallet
1. Settings → Nodes → Add Node
2. URL: `https://your-vps.example.com`
3. Transport: **Tor** (or Inherit with global Tor)
4. Test: Must pass all checks
5. Enable Strict Privacy Mode

### What VPS Still Sees
- All RPC methods, parameters
- Queried addresses, submitted transactions
- Timing, volume
- Any API key you provide

**Tor does NOT hide blockchain data** — only your network identity.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| "Tor connection failed" | Tor not running | `sudo systemctl start tor` / Open Orbot |
| "Proxy authentication failed" | Wrong user/pass | Check Settings → Proxy → Auth |
| "Certificate validation failed" | Self-signed cert, MITM | Use valid HTTPS; don't disable validation |
| "Chain ID mismatch" | Wrong network selected | Match node to Mainnet/Testnet |
| "DNS leak suspected" | Local DNS before proxy | Ensure SOCKS5h / Tor; disable system DNS |
| "Strict mode blocks everything" | Route down | Check Tor/Proxy status; disable Strict temporarily |
| "Node test: sendRaw failed" | Node doesn't support eth_sendRawTransaction | Use node with full JSON-RPC |

---

## For Developers: Network Architecture

### Code Path
```
UI (Settings) 
  → AppState (network config)
  → RpcService (node pools, health checks)
  → NetworkPrivacyManager (privacy_client.dart)
    → HttpClient.connectionFactory
      → Direct: SecureSocket.connect
      → Proxy: HTTP CONNECT → SecureSocket
      → SOCKS5: socks5_proxy.Socks5Socket
      → Tor: socks5_proxy.Socks5Socket (127.0.0.1:9050)
```

### Key Classes
- **`lib/net/privacy_client.dart`**: `createClientForNode()`, `openPinnedTlsConnection()`, SPKI pinning
- **`lib/rpc_service.dart`**: Node pools, `_selectNodeForRequest()`, `_rpcPostFull()`, `testNodeDeep()`
- **`lib/tor_manager.dart`**: Tor daemon detection, status
- **`lib/app_state.dart`**: Global proxy/Tor config, node book, strict mode

### Adding a New Transport
1. Add `NodeTransport` enum value
2. Implement in `privacy_client.dart::createClientForNode()`
3. Add UI in `settings_page.dart` proxy/Tor dialogs
4. Add test in `test/privacy_dialogs_test.dart` + `test/tls_pinning_test.dart`
5. Document in this guide

---

## Security Checklist for Network Config

- [ ] **HTTPS only** for all RPC/explorer endpoints
- [ ] **Certificate validation enabled** (never disabled)
- [ ] **SPKI pins configured** for critical nodes
- [ ] **Strict Privacy Mode ON** when using Tor/Proxy
- [ ] **Offline Mode ON** for cold signer
- [ ] **No HTTP endpoints** except localhost/LAN/.onion
- [ ] **Proxy/Tor tested** before relying on them
- [ ] **DNS leak test passed** (packet capture)
- [ ] **Chain ID validated** on every connect
- [ ] **No secrets in request bodies** (signing is local)

---

## Evidence Locations

| Test / Verification | Location |
|---------------------|----------|
| TLS pinning (OpenSSL cross-check) | `test/tls_pinning_test.dart` |
| User-Agent scrubbing | `test/ua_scrub_test.dart` |
| Proxy/Tor dialogs | `test/privacy_dialogs_test.dart` |
| Node test checklist | `test/nodes_test.dart`, `test/node_manager_test.dart` |
| Network layer implementation | `lib/net/privacy_client.dart`, `lib/rpc_service.dart` |
| Tor manager | `lib/tor_manager.dart` |

---

*This guide describes the implemented network architecture. Always verify your own configuration with packet captures before trusting privacy claims.*