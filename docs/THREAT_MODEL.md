# Threat Model — X Wallet

Created by jackh0006 (jackh109867@gmail.com)

This page states plainly what the wallet protects against, what it does not,
and where it fails. Nothing here should be read as "unhackable" or "military
grade". Software carries risk; this document describes ours.

## Assets

| Asset | Where it lives | How it is protected |
|---|---|---|
| 24-word seed phrase | In memory only after unlock; in the vault file only Argon2id+device-bound double-wrapped | Two independent wrappers must both open; see docs/CRYPTO.md |
| Private keys | In memory after unlock; persisted only inside the vault | Same envelope as the seed |
| Vault password | Never stored | Only an Argon2id verifier-side KEK exists; there is no recovery path |
| Device-bound secret | Linux owner-only local drawer | Never in preferences or the vault file; Linux is not hardware-bound |
| App-lock PIN | Only as a salted Argon2id hash in secure storage | Exponential backoff on failures: 1 s, 2 s, 4 s … capped at 15 min |
| BscScan API key | Secure storage | Public-but-private value; erased with "Erase all data" |
| Transaction history | Local receipts and pending sends are persisted encrypted; explorer history is fetched live | Receipts use `BNBRCPT1`; pending rows contain public transaction data only |
| Cold pairing (public addresses + fingerprint) | Preferences, public | No secret; fingerprint must be compared out-of-band |
| Cold unsigned request / signed response | Preferences, public | Bounded to 20 each; no seed or key |
| Non-secret config (network, RPC nodes, Tor host/port, auto-lock) | SharedPreferences | No secrets by policy |

## What this wallet defends against

1. **Stolen vault file.** A copy of `bnb-wallet-vault.bnb` alone is inert:
   it needs both your password and the device-bound secret. Moving the file
   to another machine, or exfiltrating it via malware, yields nothing.
2. **Weak passwords / offline brute force.** Any password guess costs an
   Argon2id run (64 MiB, t=3, p=4) per attempt, per salt. There are no
   shortcuts in the file: parameters live in an authenticated header.
3. **Tampering / KDF abuse.** The entire header (magic, version, KDF
   parameters, salt) is authenticated data for every AEAD box. The parser
   also accepts only the published fixed Argon2id profile before it derives a
   key, so a hostile backup cannot request unbounded KDF memory or CPU.
4. **Malicious contacts / address poisoning.** The send dialog shows the
   full grouped, checksummed address and warns when a recipient shares a
   4+ character prefix or suffix with an address already on the device —
   the classic "drip address" scam.
5. **Contract-recipient mistakes.** Before confirmation, the app reads the
   recipient's on-chain code and warns when it is a contract.
6. **Shoulder surfing & screen capture.** Linux desktops have no reliable
   application-level equivalent to protected screenshots; this is a
   documented gap, see below.
7. **Idle exposure.** Auto-lock (configurable; 60 s default) and an
   immediate lock on backgrounding clear keys from memory.
8. **PIN guessing across restarts.** The backoff window is persisted in
   secure storage, so killing the app does not reset the counter.
9. **Keyboard side channels for seeds.** Seeds are entered by tapping
   official BIP-39 words through a picker; the IME/keyboard never receives
   the phrase, so gesture-typing traces and auto-learn dictionaries stay
   clean.
10. **Network observers (when Tor mode is on).** All RPC and explorer
   traffic is routed through a local SOCKS5 connector (Tor). DNS travels
   inside the tunnel. If the proxy is down, calls fail — the app never
   silently falls back to a direct connection.
11. **Cold-wallet field substitution.** A signed response is accepted only
   if its raw EIP-1559 transaction matches the exact pending request field
   by field (chain, nonce, fees, gas limit, recipient, value, calldata),
   its hash matches the raw bytes, and its signature recovers to the paired
   address. A changed request cannot reuse an old signature.
12. **Cold-wallet replay.** A request id can be signed once; a response is
   accepted only while its request is pending; a transaction hash already
   broadcast is refused. The node's returned hash must equal the locally
   computed hash, otherwise the wallet reports an unknown outcome and does
   not resend automatically.
13. **TLS interception with a trusted-but-wrong certificate.** Optional
   SPKI pinning runs *after* standard CA and hostname validation. A pin can
   never make an untrusted or wrong-host certificate acceptable. Pinned
   HTTP CONNECT is refused rather than silently downgraded.

## Cold-wallet threats (implemented flow)

The cold flow separates the seed holder (offline) from the network holder
(public pairing only). Its security depends on the user comparing the pairing
fingerprint and reviewing the transaction on the cold screen.

| Threat | Control | Residual risk |
|---|---|---|
| Malicious pairing replaces the recipient addresses | Pairing is public data; the fingerprint is derived from the first address and must be compared on both devices out-of-band | If the user skips the fingerprint comparison, a substituted pairing is accepted |
| Online companion prepares a dishonest request (wrong recipient/fee) | Cold device decodes and displays the exact request; the user must approve it | A user who does not review the cold screen can sign a dishonest request |
| Signed response substitutes fields | Full field-by-field comparison, request hash, raw parse, `r`/`s`/`yParity`, transaction hash, signer recovery | A bug in the shared codec could affect both sides; the independent ethers.js check is the cross-check |
| Replay of a signed response | Single-use request id, pending-request requirement, broadcast-hash burn list | Reinstalling the app clears local replay state; the chain nonce still prevents a second valid transaction with the same nonce |
| Unsigned request sits on disk too long | 30-minute default lifetime, 24-hour hard cap, expiry checked at sign and verify time | Clock skew beyond 5 minutes causes refusal, not acceptance |
| QR/file channel is observed | Envelopes contain only public tx data and public addresses | The channel is not confidential; it does not need to be |
| Cold device has no network but is compromised | No network code runs in cold mode; keys stay in process memory while unlocked | A compromised OS can read memory or the seed; out of scope |
| Online companion is compromised | It never holds a key, and it cannot forge a signature for the paired address | It can refuse service, lie about fees, or withhold a response |

The cold protocol is not a substitute for a hardware wallet: the seed exists
in the cold device's process memory while unlocked, and there is no secure
element or trusted display.

## What this wallet does NOT defend against

Honesty section. These are real limits, not corner cases.

- **A compromised device or OS.** Keyloggers, rootkits, screen readers, or
  a malicious keyboard on a rooted/android-modified device can defeat any
  local protection, including the secure store. Out of scope.
- **Malicious RPC endpoints or explorer API.** A lying endpoint can show
  fake balances or reflect the wrong history. The wallet does not verify
  chain data independently (light-client proofs are not implemented).
- **On-chain privacy.** Blockchains are public ledgers. Any address you
  transact with, and everyone running a node, can link amounts and
  counterparties. Tor hides *where you asked*, not *what the chain says*.
- **ISP/traffic analysis with Tor on.** Your ISP still sees that you are
  sending traffic to Tor (or to a bridge endpoint). It does not see the
  destinations inside the tunnel unless it also runs the guard.
- **Tor entry/exit observers.** A malicious guard with a malicious exit
  could correlate traffic patterns for non-TLS traffic; the wallet is
  HTTPS-only, so exits see ciphertext only.
- **Clipboard.** Addresses and amounts can be copied. Malware reading the
  clipboard can substitute addresses. Always compare the full grouped
  address in the confirmation dialog.
- **Linux FLAG_SECURE gap.** On desktop, screenshots are not blocked at
  the toolkit level. Lock your session when leaving the machine.
- **Flash shred guarantees.** "Erase all data" overwrites the vault with
  random bytes before deletion, but wear-leveling means copies can linger
  in flash. The real guarantee is crypto-erasure: deleting the device
  secret leaves the ciphertext permanently unverifiable.
- **Seed loss.** There is no recovery. If you lose the seed phrase and
  forget the vault password, the funds are gone. The app cannot fix this.
- **User error.** Sending to the wrong (valid) address, losing the seed,
  or confirming a scam transaction is out of scope for any software.
- **Cold-flow user checks.** The cold device must display and the user must
  review the recipient, amount, fee cap and calldata. The software binds the
  bytes but cannot force a human to read the screen. The pairing fingerprint
  must be compared on both devices; skipping that check defeats the pairing
  control.
- **Cold-mode field testing.** The flow is covered by automated tests and a
  fake broadcast, not by a documented two-physical-device exercise.
- **Camera QR on Linux.** Not implemented; file and paste are the transports.
- **Historical credential exposure.** The old Android release keystore was
  committed publicly and remains compromised. It is not a Linux package
  credential and Android work is outside this assessment.
- **Memory locking is best-effort.** `prctl(PR_SET_DUMPABLE, 0)` and the core
  limit are asserted on Linux; `mlockall` can fail under a low memlock limit.
  Windows/macOS are not covered by the kernel-state test.
- **Independent verification — honest status.** The cryptography sits on
  published, reviewed primitives (Argon2id, XChaCha20-Poly1305, HKDF — from
  the pinned `cryptography` package; secp256k1 via `web3dart`; SOCKS5 from
  `socks5_proxy`). The EIP-1559 serialization is project code, because the
  available RLP helper encoded byte strings incorrectly; it is cross-checked
  against ethers.js 6.17.0 in `verification/verify.cjs`. What no software
  author alone can hand you is a **third-party security audit of this
  release** — if you plan to hold serious value here, require one before
  doing so, and ask for the latest audit statement:
  **jackh109867@gmail.com**. The internal self-assessment is
  [`SECURITY_AUDIT.md`](../SECURITY_AUDIT.md); it does not claim to be an
  external audit.

## Risk register (continuous self-assessment)

Reviewed on 2026-11-06 against the `release/1.0.10` line. The exact commit is
in `release/manifest.json`. This is an internal assessment, not an independent
audit.

| Risk | Attack scenario | Impact | Likelihood | Mitigations | Residual risk | Test evidence |
|---|---|---|---|---|---|---|
| Malware / compromised OS | Keylogger, memory reader, screen capture | Total loss | Medium | Auto-lock, dumpable=0, core limit, encrypted vault, no plaintext logs | A same-user attacker can read an unlocked process; no secure element | `memory_protection_test`, `encrypted_log_store_test`, `log_canary_test` |
| Malicious RPC provider | Fake balance, wrong chain, bogus fee/history | Wrong decision, loss | Medium | Chain-ID validation on connect and probe, HTTPS-only, optional Tor, local signing, review screen | No light-client proof; a lying node can still mislead | `nodes_test`, `node_manager_test`, `tls_pinning_test`, `privacy_config_test` |
| Malicious token contract | Non-standard `transfer`, hidden fee, fake metadata | Loss or misleading review | Medium | Exact 4+32+32 calldata, contract address shown, decimals bounded, simulation, fee-on-transfer log check | A contract can still behave unexpectedly on-chain | `send_intent_test`, `fuzz_and_property_test`, `tx_lifecycle_test` |
| Address poisoning | Lookalike prefix/suffix address in history/clipboard | Loss | Medium | Full checksummed address, grouped display, affix warning, clipboard guard | User can still confirm the wrong valid address | `wallet_core_test`, `clipboard_guard_test`, `send_intent_test` |
| Supply-chain compromise | Malicious dependency or GitHub Action | Total loss | Medium | Lockfiles, pinned action SHAs, SBOM, dependency advisory audit, license inventory, CodeQL, secret scan | No formal reproducibility proof yet; upstream compromise remains possible | `verify` workflow, `dependency-audit.py`, `sbom.py`, `license-check.py` |
| Historical Android signing key | Forged APK carrying the old identity | Distribution authenticity loss | **Confirmed exposure** | Removed from tree, history scan, signer allowlist/denylist, release blocked | Rotation **NOT VERIFIED**; old fingerprint not yet recorded | `docs/security/INCIDENT_2026-11-KEYSTORE.md`, `secret-scan.sh --history` |
| Vault/backup theft | Copy vault file or backup | Loss if password weak | Low–Medium | Argon2id 64 MiB/t=3/p=4, double wrapper, device secret, fixed header policy | Weak password remains weak; device secret is a local drawer, not hardware | `vault_test`, `kdf_production_test`, `vault_import_rollback_kdf_test` |
| Clipboard substitution | Malware replaces copied address | Loss | Medium | Secret detection, auto-clear, full address review, affix warning | Clipboard is inherently untrusted | `clipboard_guard_test` |
| Phishing / social engineering | Fake support, fake site, seed request | Total loss | Medium | No dapp browser, no remote seed entry, plain-language warnings | User can still be tricked into revealing the seed | UI tests, documentation |
| Physical theft | Stolen unlocked machine | Total loss | Low | Auto-lock, password KDF, device secret | An unlocked session is exposed | `navigation_flow_test`, `vault_test` |
| Malicious update | Trojanised package | Total loss | Low | GPG-signed `.deb`, `SHA256SUMS`, release gate, provenance attestations | User must verify the signature/fingerprint independently | `release-check.sh`, `release-gate.py` |
| Memory inspection | Dump/core or debugger | Key disclosure | Medium | `PR_SET_DUMPABLE=0`, `RLIMIT_CORE=0`, best-effort `mlockall` | Dart GC memory cannot be securely erased; no claim is made | `memory_protection_test` |
| Offline-signing substitution | Modified request or response | Wrong signature | Low | Canonical RLP, field-by-field verify, checksum, expiry, replay list, independent ethers.js check | Shared codec bug could affect both sides; physical two-device test not done | `cold_tx_codec_test`, `cold_wallet_protocol_test`, `cold_wallet_service_test`, `verification/verify.cjs` |

A risk is never marked "closed" here without a test that names the exact
commit. The generated status report and the release gate are the current
evidence index.

## Android-specific threats

Android adds attack surfaces that a Linux desktop does not have. These are the
controls and the honest limits in 1.5.0.

| Threat | Control | Residual risk |
|---|---|---|
| Screen capture / recents thumbnail | `FLAG_SECURE` on every screen | A rooted/camera-equipped attacker can still photograph the screen |
| Tapjacking / overlay | `filterTouchesWhenObscured` on the Android view | A compromised OS or accessibility service can still inject events |
| Backup extraction | `allowBackup=false`, `dataExtractionRules` excludes root, no broad storage permission | A rooted device or vendor backup tool may bypass app-level flags |
| Clipboard substitution | Secret-shaped text is blocked; copied addresses clear after 30 s; full address review | Clipboard is inherently untrusted |
| Malicious keyboard / IME learning | Seed entry uses an in-app word picker; secret fields disable suggestions, autocorrect and personalized learning | The OS keyboard can still observe non-secret fields |
| Keystore/TEE compromise | Device secret is Keystore-wrapped; StrongBox/TEE where available | The current key is not yet user-auth-bound; a compromised OS can use it while the app runs |
| Rooted / emulator / debugger | No silent block; local warnings are planned | A rooted device can read app memory and bypass many controls |
| Malicious RPC / price / IP service | Fixed hosts, HTTPS, system CAs only, no wallet data in price requests; IP echo only on route test | Those services still see the request and the public IP |
| Fake APK | Approved signer gate, old certificate denylisted, signed checksums | Users who skip signature verification can install a fake build |
| Intent spoofing / deep links | Only the launcher activity is exported; no deep links | A malicious app can still show a fake UI and phish the user |
| Offline signing on Android | Cold mode sets the RPC offline; QR/file/paste protocol with field verification | No camera QR scanner in 1.5.0; no two-device physical test |
| Native KDF | Android ships `libargon2-arm.so`; 64 MiB/t=3/p=4 unchanged | Device timing and low-memory behavior are **NOT TESTED** on a physical phone |

## When Tor mode is useful, and when it is not

Useful: reducing which nodes see *your IP asking about your addresses* —
useful if your address is linked to a publicly known identity and you do
not want the RPC provider to correlate it.

Not useful: hiding activity from the chain, hiding identity already baked
into past transactions, or bypassing a malware/keyboard compromise.

## Responsible disclosure

Found an issue? Contact jackh0006 <jackh109867@gmail.com>. Please include
reproduction steps. Do not test against addresses you do not own.

Anything in this document you cannot reproduce or that sounds like trust
instead of proof? Email me — I will show you the runnable proof, or say
plainly that it can only be proven by use (docs/STANDARDS.md explains which
is which).
