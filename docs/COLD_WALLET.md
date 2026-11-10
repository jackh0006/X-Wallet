# Cold Wallet Mode — operator and developer guide

Status: implemented and self-verified. **Not independently reviewed.** Use on
the current testnet (chain id 97) or with small amounts until an external
review exists. The security assessment is in [`SECURITY_AUDIT.md`](../SECURITY_AUDIT.md).

## What the mode guarantees

- The **cold signer** holds the seed/private key in process memory only while
  unlocked, and has **no network access**: `RpcService` is put offline and
  `connect()` fails closed. It never prepares or broadcasts a transaction.
- The **online companion** holds **no seed and no private key**. It prepares
  an unsigned EIP-1559 request, imports the cold device's signed response,
  independently re-verifies every byte, and only then broadcasts.
- Pairing exports **public addresses only** (plus an optional public xpub).
  No mnemonic, private key, passphrase or vault password crosses the QR/file
  channel.
- A signed response is bound to one request id and one exact set of fields.
  Replay, field substitution, expiry, wrong signer, wrong chain and already
  broadcast bytes are refused.

## The two roles

| Role | Holds | Network | Can sign | Can broadcast |
|---|---|---|---|---|
| Hot (normal) | seed/key while unlocked | yes | yes | yes |
| Cold (offline signer) | seed/key while unlocked | **no** | yes, offline | **no** |
| Online (companion) | public pairing only | yes | **no** | yes, after verification |

Switching modes:

1. Settings → Wallet mode → **Cold (offline signer)**. The wallet disconnects
   and stays offline. If no key is in memory, unlock the vault.
2. On the cold device, export the pairing (QR/file). It contains the first 20
   default BIP-44 addresses and a 4-byte fingerprint.
3. On the online device, switch to **Online (watch-only companion)**. Import
   the pairing and compare the fingerprint on both screens. The first paired
   address becomes the watch-only account.
4. Leaving cold mode locks it. A hot or online session must be explicitly
   unlocked/paired again; keys are not carried across the boundary.

## End-to-end flow

```
online companion                         cold signer (offline)
----------------                         ---------------------
1. build unsigned EIP-1559 request
   (chain, nonce, fees, gas, to,
    value, calldata, asset info)
2. store pending request
3. show QR / file / paste  ───────────▶ 4. import request
                                        5. decode + validate:
                                           version, chain 56/97,
                                           expiry, from is one of
                                           the first 20 addresses,
                                           native/calldata match
                                        6. user reviews recipient,
                                           amount, fee cap, calldata
                                        7. sign with matching
                                           m/44'/60'/0'/0/<index>
                                        8. self-verify the result
                                        9. show signed response
10. import response  ◀──────────────────┘
11. require the exact request still
    pending with identical bytes
12. recompute digest, parse raw tx,
    compare every field, r/s/yParity,
    hash; recover exactly one signer
13. refuse if already broadcast or
    signed after expiry
14. broadcast raw bytes
15. node hash must equal the local
    hash; otherwise report unknown
    outcome and burn the bytes
```

Request lifetime defaults to **30 minutes** and is capped at 24 hours. A
response produced after the request expired (plus 5 minutes of clock skew) is
refused. The online side also refuses a response for a request it no longer
has pending. Keep both devices' clocks reasonably synchronized.

## Protocol envelopes

All three payloads use the same versioned envelope:

```json
{
  "magic": "BNBCOLD",
  "version": 1,
  "kind": "pairing | request | signature",
  "payload": { "...": "..." },
  "checksum": "<sha256 of canonical JSON payload>"
}
```

Rules enforced by [`lib/cold_wallet_protocol.dart`](../lib/cold_wallet_protocol.dart):

- canonical JSON (sorted object keys), SHA-256 checksum;
- exact allow-listed fields; unknown or missing fields are rejected;
- size limits: pairing 8 KiB, request 32 KiB, signature 16 KiB;
- addresses must be valid EIP-55/EIP-20 addresses; duplicates are rejected;
- pairing chain is 56 or 97; request chain is 56 or 97;
- request ids are 8–64 URL-safe characters; expiry must follow creation and
  be at most 24 hours later;
- signed responses carry `requestHash` (the EIP-1559 signing digest) and
  `yParity`; `v` is the full recovery id (0–3), not the legacy 27/28 value;
- native-asset requests carrying calldata are rejected;
- the checksum is an integrity check, **not** an authenticator. Authenticity
  comes from the ECDSA signature over the exact transaction and from the
  paired address fingerprint.

## What is stored where

`ColdWalletService` persists only public data in preferences:

| Key | Content |
|---|---|
| `cold_pairing_v1` | pairing envelope (public addresses, fingerprint) |
| `cold_pending_requests_v1` | unsigned request envelopes, bounded to 20 |
| `cold_signed_responses_v1` | signed response envelopes, bounded to 20 |
| `cold_signed_request_ids_v1` | ids already signed, bounded to 20 |
| `cold_broadcast_hashes_v1` | tx hashes already broadcast, bounded to 20 |

No secrets are written by the cold flow. The vault remains the only place a
seed or private key is persisted, and only in its encrypted envelope.

## Verification before broadcast

The online companion never trusts the cold device's claims. It re-derives:

1. the unsigned payload and `keccak256` digest from the pending request;
2. the parsed raw transaction from the response;
3. every field (chain, nonce, fees, gas limit, recipient, value, calldata,
   access list);
4. `r`, `s`, `yParity`, `v`, and `keccak256(raw)` against the advertised hash;
5. the recovered signer against the paired `from` address.

The independent implementation in
[`verification/verify.cjs`](../verification/verify.cjs) uses **ethers.js
6.17.0** (not web3dart) on a synthetic public test vector. It checks the same
payload/digest/raw bytes/hash/signature/recovered signer and rejects eight
field substitutions. CI runs it on every push.

```sh
cd verification
npm ci
node verify.cjs
```

## Transport channels

- **Display QR** of the envelope text on the sending device.
- **Export to file** (`.json`) through the platform save dialog.
- **Paste** the envelope text or a file path.
- **Camera QR scanning** is not implemented in this Linux build. Use file or
  paste; a phone build would need a camera plugin, which is out of scope here.

QR codes of a full signed transaction can be large. If a QR does not fit,
use the file. The protocol rejects payloads above its size limits rather than
truncating them.

## Failure behavior

| Situation | Behavior |
|---|---|
| Pairing checksum/fingerprint wrong | refuse import; ask for a fresh pairing |
| Request expired | refuse to sign and refuse to verify |
| Request `from` not in first 20 default addresses | refuse to sign |
| Custom derivation path does not match `from` | signer refuses |
| Response bytes differ from pending request | refuse; nothing is broadcast |
| Wrong signer / wrong chain / wrong nonce / substituted field | refuse |
| Replayed request id with different bytes | refuse |
| Already broadcast hash | refuse |
| Node returns a different hash | report unknown outcome; do not resend; bytes burned |
| Cold mode tries to connect | fail closed; no RPC call leaves the device |

## Limits

- Version 1.1.0 enables BSC mainnet (56) and testnet (97); other EVM networks are not yet enabled.
- Only EIP-1559; legacy fee requests are not created for the cold flow.
- Access lists are rejected.
- First 20 default BIP-44 accounts only (`m/44'/60'/0'/0/0..19`). Custom
  derivation paths are not carried in the request.
- No camera QR on Linux.
- No two-physical-device field test has been recorded.
- No third-party audit.

## Network-isolated launcher

Cold mode blocks every app-initiated call at runtime. For a stronger,
OS-enforced boundary, the `.deb` also installs `x-wallet-offline`. It runs the
same binary inside an empty network namespace with only a loopback interface:

```sh
x-wallet-offline
```

It requires `util-linux` and user namespaces. If the namespace cannot be
created, the launcher **fails closed** and tells you to keep the machine
physically offline; it never falls back to a networked run.

For a dedicated cold machine, the stronger procedure is:

1. Use a machine that has no Wi-Fi/Bluetooth hardware enabled and no network
   cable; disable the interfaces in the firmware/OS as well.
2. Boot a clean, fully updated OS from removable media if possible.
3. Run `x-wallet-offline` (or `unshare -n -- x-wallet`) and verify that the
   only interface in the namespace is `lo`.
4. Move signing requests and responses only by USB or by displaying/copying
   the payload, and verify the payload hash on the cold screen before signing.
5. Never connect the cold machine to a network, even briefly, for updates.

## Tests

```sh
flutter test test/cold_tx_codec_test.dart          # 4
flutter test test/cold_wallet_protocol_test.dart   # 15
flutter test test/cold_wallet_service_test.dart    # 15
flutter test test/cold_wallet_test.dart            # 8
cd verification && npm ci && node verify.cjs       # independent ethers
```

See [`docs/TESTING.md`](TESTING.md) for the full matrix and the exact limits
of what these tests do and do not prove.
