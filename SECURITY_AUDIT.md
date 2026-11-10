# Security Self-Assessment — X Wallet

> **Superseded for release status by `docs/CLAIM_REGISTER.md` and
> `docs/HARDENING_REPORT.md` (1.5.3).** This page records the 2026-11-03
> self-assessment; it is not an audit and some claims in it were downgraded.

Date: 2026-11-03
Scope: Linux cold-wallet transaction path, transaction verification, TLS
pinning, process memory hardening, and Debian release-signing hygiene.
Baseline commit: `19e03c8` (`safety/pre-reaudit-19e03c8`).
Status: **self-assessment and cross-implementation verification — not a
third-party audit.**

This document records what was found, what was changed, what was actually
executed, and what remains unproven. It deliberately avoids claims of
independent review or readiness for unrestricted real-money use.

## 2026-11-05 verification-gate update

The previous full-suite command grouped all tests in two long-lived Flutter
processes. A widget-test timeout could therefore make the overall result hard
to attribute and leave no useful per-file terminal evidence. The release
driver now starts each test file in its own serial process, has a 120-second
watchdog for ordinary files and a 900-second watchdog for the explicitly
tagged Argon2id files, prints every exit status, and returns failure for any
timeout. This is a test-infrastructure control, not evidence of a passing
suite: a complete green hosted Ubuntu 24.04 run remains required.

## Classification

| Label | Applies? | Meaning |
|---|---|---|
| Ready for unrestricted real-money use | **No** | No independent third-party review; no hardware wallet; no camera QR on Linux; and no current clean-machine installation evidence. |
| **Testnet ready (self-assessed)** | **Yes, conditionally** | The critical cold-signing and verification defects below are fixed and demonstrated by automated tests plus an independent ethers.js cross-check. Use only on BSC testnet / small amounts until an external review exists. |
| Mainnet for large sums | **No** | Same reasons as above. |

## Critical findings and disposition

### C-1 — Cold EIP-1559 signing produced invalid bytes (fixed)

The previous cold signer used the `rlp` package's `Rlp.encode` with
`Uint8List`/`List<int>` arguments. That API encodes every `List<int>` as an
RLP **list**, so a 20-byte address or calldata was wrapped as a list of
integers instead of an RLP byte string. Signatures were produced over bytes
that did not match the transaction the online side would broadcast; calldata
transactions were especially affected.

Fix:

- `lib/cold_tx_codec.dart` is now the single strict codec for the unsigned
  payload, signing digest, signed payload and signed-transaction parsing.
- Byte strings and integers are encoded explicitly; the parser rejects
  non-canonical RLP, trailing bytes, wrong lengths, `r`/`s` out of range,
  high-s, and `yParity` other than 0/1.
- Signing, response verification and the online broadcast gate all use this
  codec, so the digest cannot drift from the raw bytes.
- `v` stores the full ECDSA recovery id (0–3); only `yParity` enters the
  EIP-1559 serialization.

Evidence:

- `test/cold_tx_codec_test.dart` — 4/4 pass.
- `verification/verify.cjs` — parses the exact signed bytes with ethers.js,
  recomputes the EIP-1559 payload/digest, checks every field plus
  `r`/`s`/`yParity`, recovers the signer, and rejects 8 field substitutions.
  It passes.
- `test/cold_wallet_service_test.dart` proves a changed request cannot reuse
  an old signature and a node returning a different hash cannot cause a
  resend.

### C-2 — Cold response verification did not bind all fields (fixed)

The old verifier checked the signature over a request but did not rebuild and
compare every serialized field, did not compare the signed-transaction hash to
the raw bytes, and could accept a response whose `yParity`/`v` disagreed.

Fix: `WalletCore.verifyColdSignatureDetailed` now:

1. reconstructs the unsigned EIP-1559 digest from the request;
2. parses the supplied raw transaction with the canonical codec;
3. compares chain id, nonce, fees, gas limit, recipient, value, calldata and
   access list;
4. compares `r`, `s`, `yParity`, the full recovery id and the transaction
   hash;
5. recovers the signer and requires exactly one match to the paired address.

Evidence: `test/cold_wallet_service_test.dart` (15/15) and
`test/cold_wallet_protocol_test.dart` (15/15) include recipient, value,
chain, nonce, gas, fee and calldata substitutions; `r`/`s`/`yParity`/hash
substitutions; modified raw bytes with a fresh checksum; wrong signer;
expired request; future timestamp; replayed request id with different bytes.

### C-3 — Cold transport had no replay/substitution envelope (fixed)

Pairing, requests and signed responses are now canonical JSON envelopes with a
magic marker, protocol version, kind, SHA-256 checksum over the canonical
payload and strict allow-listed fields. Unknown fields, duplicate addresses,
expired requests, immature requests (expiry before creation), oversized
payloads and native-asset requests carrying calldata are rejected.

Requests are single-use by id; the online side refuses a response whose
request is no longer pending, whose bytes differ from the pending copy, that
was signed after expiry, that claims a future signing time, or whose raw
transaction hash was already broadcast. The node's returned hash must equal
the locally computed hash or the wallet reports an unknown outcome and marks
the bytes burned to prevent an automatic resend.

### C-4 — TLS pinning bypassed normal validation and read the wrong bytes (fixed)

Two defects were found:

1. The pinned connection path installed a `badCertificateCallback` and did
   not run standard CA/hostname validation first, so a valid pin could make a
   certificate for another host acceptable.
2. `spkiSha256Base64FromDer` used index 7 for v3 certificates. RFC 5280 puts
   the subjectPublicKeyInfo at index 6 when the explicit version field is
   present; index 7 is the extensions block. Pins were computed over the
   wrong DER bytes.

Fix:

- `openPinnedTlsConnection` performs a normal `SecureSocket.connect` with the
  caller's trust context and no permissive callback; the pin is checked only
  after the handshake succeeds.
- SPKI extraction uses index 6 with version, 5 without, and fails closed.
- Pinned HTTP CONNECT is refused before opening a socket (no pin enforcement
  on that transport yet).
- No empty `SecurityContext` and no `badCertificateCallback` remain in the
  pinning path.

Evidence: `test/tls_pinning_test.dart` (6/6) generates an ephemeral CA and
server certificate with OpenSSL, proves the Dart pin equals the OpenSSL
`x509 -pubkey | pkey -outform DER | dgst -sha256` result, and proves a pin
cannot bypass CA or hostname validation. Wrong pins and empty pin lists fail.

### C-5 — Memory protection was a shell no-op (fixed)

The old code ran `sh -c 'ulimit -c 0'`, which changed a child shell and left
the wallet process dumpable with a core limit.

Fix: `lib/memory_protection.dart` calls Linux kernel APIs through FFI:
`prctl(PR_SET_DUMPABLE, 0)`, `setrlimit(RLIMIT_CORE, 0)` and best-effort
`mlockall(MCL_CURRENT | MCL_FUTURE)`. Failures are reported honestly; the app
does not pretend the hardening succeeded.

Evidence: `test/memory_protection_test.dart` reads back `PR_GET_DUMPABLE == 0`
and the core soft limit `0` from the running test process (2/2 pass). This is
Linux-only; Android/Windows/macOS behavior is not covered by that test.

### Historical Android credential disclosure (outside this Linux-only scope)

`scripts/release.keystore` and a predictable hardcoded release password
(derived from the year and the local username) were present in the public
repository history. Removing the file from the current tree does not remove it from
history, and rewriting public history would require a force-push, which this
project forbids.

Actions taken:

- The keystore is deleted from the current tree; `scripts/build-apk.sh` no
  longer creates or references a repository keystore. It requires
  `BNB_KEYSTORE`, `BNB_KEY_ALIAS`, `BNB_STORE_PASS` and `BNB_KEY_PASS` from
  the environment and fails closed if any is missing.
- `.gitignore` blocks `*.keystore`, `*.jks`, `*.p12`, `*.pfx`,
  `key.properties` and signing directories.
- `scripts/secret-scan.sh` fails CI on tracked keystores, PEM private keys,
  the old password string, inline Android signing passwords and hardcoded
  32-byte keys. It passes on the current tree.

The Android credential remains compromised permanently. It is not used to
build or sign the Linux `.deb`, and Android rotation/distribution is not an
active release task in this assessment. It cannot be remediated by Linux
source changes.

### C-7 — Cold signing ignored the paired account index (fixed)

The pairing exported the first 20 default BIP-44 addresses, but the cold
signer always signed with `m/44'/60'/0'/0/0`. A request for account 1–19
therefore produced a different signer than the request named.

Fix: `ColdWalletService.signRequest` finds the request's `from` address in
the derived default list and signs with the matching
`m/44'/60'/0'/0/<index>` path. A test proves an address outside the first 20
is refused. Custom derivation paths are still unsupported and must be
specified by the caller; a mismatched custom path is refused by the signer.

### C-8 — Test/UI keyring read could hang indefinitely (fixed)

`AppStorage.init()` awaited the OS keyring without a bound. Under the Flutter
test runner (no platform plugins) this never completed, and on a Linux
desktop the libsecret call runs on the GTK thread.

Fix: the read is bounded by the existing 3-second keyring timeout and is
skipped entirely when `FLUTTER_TEST` is set. Widget tests are hermetic again;
production behavior keeps the fail-closed timeout.

## Verification matrix

| Check | Command | Result |
|---|---|---|
| Canonical codec | `flutter test test/cold_tx_codec_test.dart` | 4/4 pass |
| Protocol envelopes | `flutter test test/cold_wallet_protocol_test.dart` | 15/15 pass |
| Cold service/replay/broadcast | `flutter test test/cold_wallet_service_test.dart` | 15/15 pass |
| Existing cold wallet tests | `flutter test test/cold_wallet_test.dart` | 8/8 pass |
| TLS pinning | `flutter test test/tls_pinning_test.dart` | 6/6 pass |
| Kernel memory hardening | `flutter test test/memory_protection_test.dart` | 2/2 pass |
| Independent ethers.js | `cd verification && npm ci && node verify.cjs` | pass, 8 substitutions rejected |
| Secret scan | `bash scripts/secret-scan.sh` | pass |
| Static analysis | `flutter analyze --no-pub` | no errors (see docs/TESTING.md for infos/warnings) |
| Full test suite | `bash scripts/test-suite.sh` | see docs/TESTING.md for the exact recorded run |

## Not tested / limitations

- **No independent third-party audit.** This is the largest open item.
- **No two-device field test.** The cold flow was exercised through automated
  services and dialogs, not by moving files between two physical machines.
- **No camera QR scanning on Linux.** File, paste and displayed QR are
  implemented; scanning uses the platform camera plugin elsewhere.
- **No local-chain integration test.** `anvil` is not installed in this
  environment, so no real node accepted or rejected a signed transaction.
  The broadcast gate is tested with a fake RPC that returns the expected hash;
  a mismatched hash test proves the refusal path.
- **Memory hardening is Linux-only.** `mlockall` is best-effort; the kernel
  may refuse it under a low `RLIMIT_MEMLOCK`. The test asserts the two
  controls that must hold (`dumpable=0`, core limit 0), not that all memory is
  locked.
- **TLS pinning does not cover HTTP CONNECT.** That transport is refused when
  pins are configured rather than silently downgraded.
- **Cold request lifetime** defaults to 30 minutes and is capped at 24 hours.
  Clock skew between devices is tolerated by 5 minutes; larger skew causes a
  refusal, not a best-effort acceptance.
- **Access lists are not supported** by the cold protocol; the codec rejects
  them instead of encoding them incorrectly.
- **Windows/macOS paths** are not exercised by this assessment.

## Reproduction

```sh
flutter pub get
flutter analyze --no-pub
bash scripts/test-suite.sh
bash scripts/secret-scan.sh
cd verification && npm ci && node verify.cjs && cd ..
```

Do not treat a green local run as a security audit. The value of these checks
is that they fail when the bytes or the rules drift.
