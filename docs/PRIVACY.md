# PRIVACY.md — what this wallet does and does not do with your information

Version 1.0.5 · AGPL-3.0-or-later · Contact: jackh109867@gmail.com

## What we collect: nothing

The wallet has no telemetry, no analytics, no crash reporting, no update
pings, no account, no email. It never calls a server of the developer. The
developer receives nothing, ever. A network capture of a running wallet
shows requests to the RPC nodes and explorer you (or the defaults) selected,
plus optional public price lookups. Price lookups are off by default and are
blocked in cold mode. They send only fixed coin IDs, never an address or
balance.

## What the network layer actually sends

Every HTTP client is constructed in one module (`net/privacy_client.dart`);
`test/data_boundary_test.dart` fails if another construction site appears.
Node proxy passwords, bearer tokens and custom headers are held in the
platform secure store, not in the plain preferences file:

- **No identifying headers.** Requests carry only `content-type:
  application/json` (RPC) or `accept: application/json` (explorer).
  The library default `User-Agent: Dart/x.x (dart:io)` is scrubbed.
- **Tor route (optional, off by default):** with "Route traffic through Tor"
  enabled, the same requests are tunnelled through a local SOCKS5 connector
  (Tor SocksPort, e.g. `127.0.0.1:9050`; Orbot on Android). There is NO
  fallback to a direct connection — if the proxy is down, network calls
  simply fail. Bridges (obfs4/WebTunnel) are configured inside tor/Orbot
  itself; the wallet only needs the local SOCKS port.
- **DNS:** with Tor enabled, hostnames resolve through SOCKS5.
- **Timing:** proxy round trips add latency; the fee engine derives its
  "seconds per block" expectations from realrpc measurements, never from
  hardcoded tables.

## What an RPC node can and cannot learn

CAN see:

- your IP address or Tor exit's IP (when node privacy is on, it sees the
  Tor exit, not you);
- every question you ask it — balance, nonce, gasprice, chain, block,
  fee history, broadcast of signed transactions — and can associate those
  with the addresses involved;
- timing and sequencing of your questions.

CANNOT see:

- your seed words or private keys (nothing leaves the device — signing is
  local; the payload broadcast is opaque);
- what a transaction means to you (mempool observers see data, not context);
- anything above HTTPS payload length/timing when Tor is on.

The wallet narrates all of this in plain words inside Settings → RPC nodes,
shows a **one-time warning per node** before you add one, and offers
**strict mode** (talk ONLY to your chosen node; no fallback doors).

## Where your data lives

- **Vault (encrypted):** `bnb-wallet-vault.bin` — seed/keys sealed with
  XChaCha20-Poly1305 under an Argon2id-derived key (64 MiB, t=3, p=4).
- **Receipt archive (encrypted):** `bnb-wallet-receipts.bin`, key derived
  from wallet secret + a device drawer secret, envelope `BNBRCPT1`, capped
  at 200 entries.
- **Plain preferences:** network choice, chosen RPC, phone book (public
  node addresses + labels), custom token contracts, hidden-token keys, a
  watch-only public address, Lite-mode flag, the pending-tx status list and
  the state discussed above. Nothing secret is in there; the phone book and
  user token links are shareable JSON.
- **API keys** (optional BscScan key): secure on-device storage.
- **Encrypted activity log:** `bnb-wallet-log.bin`, envelope `BNBLOG01`,
  XChaCha20-Poly1305 under a key derived from the wallet key and the device
  drawer secret. Capped at 5 MB / 10 000 entries. It records network, fee,
  transaction and lock events for the in-app Logs screen (Simple and Expert
  views). Signed transactions and secret material are never written to it.
- **Raw RPC panel:** the last 50 request/response pairs are kept in memory
  only for "View raw request", never on disk.
- **Watch-only profile:** its public address is a plain preference; there is
  no key or seed for it on this device.

## Backups

Nothing the wallet stores is uploaded anywhere by it. There is no cloud
backup, no export push, no sync. Exports (node phone book JSON) go to your
clipboard or file only when you trigger them.

## Third parties

- You choose (or accept by default) which RPC operators you talk to; the
  wallet ships no exclusive agreement with any of them.
- The explorers named in the trusted-source list (`assets/token_sources.json`)
  are for token due-diligence in your browser — the wallet does not fetch
  them by itself.
- Components and versions are listed in `docs/SBOM.json`.

## Who writes this wallet

One maintainer (jackh0006, jackh109867@gmail.com). The code is AGPL-3.0-or-
later; build and verify it yourself (see the About screen and the README).
No third-party audit exists yet — the threat model documents this openly.
