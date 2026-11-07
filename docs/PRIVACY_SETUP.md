# Privacy Setup: VPN, VLESS, Tor, and Proxies

This guide explains how to route X Wallet through a VPN or a local VLESS/Xray
client before Tor, and how to use the proxy modes. All signing and vault
decryption stay local; these settings only change the network route.

## 1. Install Tor

Ubuntu or Debian:

```bash
sudo apt update
sudo apt install tor obfs4proxy snowflake-client
```

Check the installation:

```bash
tor --version
```

The app detects `tor`, `obfs4proxy`, and `snowflake-client` and shows the
missing component.

## 2. VPN first, then Tor

If you use WireGuard, OpenVPN, or another system VPN:

1. Connect the VPN and confirm your public IP is the VPN exit.
2. Open **Settings → Tor & bridges**.
3. Leave **Upstream before Tor** set to **Direct**.
4. Start managed Tor.

Traffic path:

```text
X Wallet → system VPN tunnel → VPN/VPS exit → Tor guard → Tor circuit → RPC
```

The app does not need the VPN provider's details. The operating system routes
Tor through the active VPN tunnel.

## 3. VLESS/Xray before Tor

If your Netherlands server runs VLESS/Xray, run a local SOCKS inbound on the
same machine as X Wallet.

Example inbound fragment for an Xray client configuration:

```json
{
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10808,
      "protocol": "socks",
      "settings": { "udp": true }
    }
  ]
}
```

Start the client:

```bash
xray run -c /path/to/config.json
```

Then in **Settings → Tor & bridges**:

- **Upstream before Tor:** `SOCKS5h (remote DNS)`
- **Upstream host:** `127.0.0.1`
- **Upstream port:** `10808`
- **Tor chain depth:** `1` for normal Tor
- Save, then **Start managed Tor**

Traffic path:

```text
X Wallet → 127.0.0.1:10808 (VLESS client) → Netherlands VPS → Tor guard → Tor circuit → RPC
```

The app writes the upstream into the private Tor configuration. The VLESS
password is stored in the platform secure store, not in plain preferences.

## 4. Tor over Tor (experimental)

**Tor chain depth** can be 1, 2, or 3.

- `1` — normal Tor (recommended).
- `2` — a second Tor instance uses the first Tor instance as its SOCKS
  upstream.
- `3` — a third Tor instance is added in front of the second.

More hops are slower and experimental. Tor over Tor does not automatically make
you anonymous; it can reduce performance and may weaken anonymity if the route
is misconfigured. Use it only if you understand the tradeoff.

The final SOCKS port is the one the wallet uses. The app starts each hop in a
private temporary directory and stops only the processes it started.

## 5. Proxy modes

Open **Settings → Custom proxy** for:

- `SOCKS5`
- `SOCKS5h` (remote DNS, recommended for privacy)
- `HTTP CONNECT`

Common setups:

```bash
# SSH SOCKS5 through a VPS
ssh -D 1080 -N user@your-vps
```

Use `socks5h://127.0.0.1:1080` in the app.

```bash
# Local VLESS/Xray SOCKS inbound
xray run -c /path/to/config.json
```

Use `socks5h://127.0.0.1:10808` in the app.

Proxy mode is fail-closed: if the proxy is down, requests fail instead of
falling back to your real IP.

## 6. Verify the route

For Tor:

```bash
curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip
```

For a SOCKS proxy:

```bash
curl --socks5-hostname 127.0.0.1:1080 https://ifconfig.me/ip
```

For an HTTP CONNECT proxy:

```bash
curl --proxy http://127.0.0.1:8080 https://ifconfig.me/ip
```

The app also has a **Test** button in the proxy and Tor dialogs. It reports the
route result without printing credentials.

## 7. Logs

**Settings → Tor & bridges** shows the latest Tor hop logs, including:

- bootstrap progress
- bridge/transport errors
- exit status
- warnings

Use **Copy log** to copy the current tail. The Activity Center contains the
wallet's own encrypted network story; it never stores seed words, private keys,
vault passwords, or proxy passwords.

## 8. Operational rules

- Connect the VPN or VLESS client **before** starting managed Tor.
- Keep the local SOCKS port bound to `127.0.0.1`.
- Do not expose SOCKS, Tor, or RPC ports to the public internet.
- Use a dedicated VPS for privacy routing.
- Verify the exit IP after changing any route.
- For large holdings, use hardware-backed custody; network privacy does not
  protect a compromised computer.
