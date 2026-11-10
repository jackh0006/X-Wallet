# Cryptography Spec — X Wallet v1.0.5

Created by jackh0006 (jackh109867@gmail.com)

Implementation: `lib/vault.dart`, `lib/kdf.dart`, `lib/security.dart`,
`lib/storage.dart`, `lib/cold_tx_codec.dart`,
`lib/cold_wallet_protocol.dart`, `lib/net/privacy_client.dart`,
`lib/memory_protection.dart`.
Crypto primitives are provided by the `cryptography` package (XChaCha20-
Poly1305, HKDF-SHA256), the reference Argon2 implementation via
`dargon2_core`/`dargon2_flutter` (Argon2id), `web3dart`/`wallet` (secp256k1,
keccak256, EIP-55), and `socks5_proxy` for SOCKS5 transport.

One serialization component is project code: the canonical EIP-1559/RLP
codec in `lib/cold_tx_codec.dart`. The available `rlp` helper encoded every
`List<int>` as an RLP list, so addresses and calldata were serialized
incorrectly. The replacement is not a new cryptographic primitive; it is a
strict encoder/decoder cross-checked against ethers.js 6.17.0 in
`verification/verify.cjs`.

## Vault envelope v2 ("BNBVL004", version byte 2)

Stored at `<app-support>/bnb-wallet-vault.bnb`, base64 of the binary
envelope. Total binary layout, in order:

```
offset  size  field
0       8     magic   "BNBVL004" (0x42 0x4e 0x42 0x56 0x4c 0x30 0x30 0x34)
8       1     version 0x02
9       4     Argon2id memory KiB, uint32 LE   (65536)
13      4     Argon2id iterations, uint32 LE   (3)
17      4     Argon2id parallelism, uint32 LE  (4)
21      16    salt (random)
37      24    paperBox nonce
61      32    paperBox ciphertext  (DEK, 32 bytes)
93      16    paperBox MAC (Poly1305)
109     24    deviceBox nonce
133     32    deviceBox ciphertext  (same DEK)
165     16    deviceBox MAC
181     24    payloadBox nonce
205     N     payloadBox ciphertext (JSON vault)
205+N   16    payloadBox MAC
```

AAD for ALL THREE AEAD boxes is bytes [0..37) — the header including
parameters and salt. Consequences:

- Any modification of magic, version, KDF parameters or salt makes every
  box fail authentication. Parameter downgrade attacks are impossible
  without also holding the DEK (i.e. having broken the wrappers already).
- The payload integrity covers the header: cut-and-mix attacks across
  historical vaults fail because each vault has its own random salt.

Keys:

```
KEK_pw   = Argon2id(password, salt, 64 MiB, t=3, p=4, 32-byte tag)
KEK_dev  = HKDF-SHA256(ikm=deviceSecret, salt=0x00×32,
                       info="bnb-wallet/device-kek-v2", L=32)

Where deviceSecret lives: Android/iOS keep it in the platform keyring
(Android Keystore-backed), read at most once per session. Desktops (Linux,
macOS, Windows) deliberately keep it in an owner-only (0600) drawer file
beside the vault in the app's data directory — the Linux keyring plugin
performs libsecret calls synchronously inside the GTK window thread, which
froze weak machines mid-wallet-creation. Machine binding is defense-in-depth, not a required second factor: on Linux
the device secret is an owner-only file beside the vault, so an attacker who
copies the whole data directory and knows the password can open the vault.
The password wrapper alone is sufficient to recover the payload. Existing vaults
migrate once (keyring → drawer on the first vault operation after the
update); if a vault's keyring secret cannot be read, the wallet retries once
and FAILS CLOSED — it never mints a replacement that would orphan the vault.
DEK      = 32 random bytes (CSPRNG), never stored in the clear
paperBox = XChaCha20-Poly1305(KEK_pw,  DEK, AAD=header)
deviceBox= XChaCha20-Poly1305(KEK_dev, DEK, AAD=header)
payload  = XChaCha20-Poly1305(DEK, plaintext-JSON, AAD=header)
```

## Argon2id backend and measured cost

The production parameters are fixed at **64 MiB, t=3, p=4, 32-byte tag**
(RFC 9106 low-memory profile). The implementation is selected in
`lib/kdf.dart`:

1. The reference C Argon2 library bundled by `dargon2_flutter`
   (`libargon2.so` on Linux, `argon2.dll` on Windows, the macOS dylib), or
   the platform's `libargon2.so.1`.
2. The pure-Dart `cryptography` Argon2id only when no native library can be
   loaded. This is the same algorithm and parameters, but much slower.

Android 1.5.0 ships the same reference C library as `libargon2-arm.so`,
built from `android/app/src/main/cpp/` and loaded through the FFI path in
`lib/kdf.dart`. The 64 MiB / t=3 / p=4 parameters are identical to Linux. The
release APK contains that library; device-level timing is **NOT TESTED** in this
environment.

Measured on the release-check machine (Ubuntu 24.04, 2 physical cores,
3.8 GiB RAM, Flutter 3.47.6 / Dart 3.13.5): **344 ms** for one 64 MiB,
t=3, p=4 derivation through the native reference library. The same
derivation through the debug-mode pure-Dart fallback took roughly **110 s**,
which is why the native path is the production requirement and why the
fallback must never be silently accepted for a release.

Tests:

- `test/kdf_production_test.dart` asserts the fixed parameters, cross-checks
  the native output against the independent pure-Dart Argon2id at 1 MiB, and
  performs one real 64 MiB vault round-trip with a 60 s performance guard.
- Envelope/format suites use `VaultCipher.debugKdfOverride`, an
  assert-guarded test seam compiled out of release builds. It changes no
  production parameter and cannot be reached in a release binary.

A time-out, OOM, or native-library crash is recorded as `FAILED` or
`INCOMPLETE`; it is never treated as a passing KDF test.

Decryption opens both wrappers and compares the two recovered DEKs in
constant time; a mismatch ("both boxes authenticate but disagree") is a
tampering indicator and fails closed. The payload is then decrypted with the
password-derived DEK, so the password wrapper is sufficient on its own; the
device wrapper is an additional at-rest factor, not a required one. Any failure surfaces one generic
message — "Wrong password, device key unavailable, or corrupted vault" — so
there is no oracle that says which factor was wrong.

Device secret: 32 fresh CSPRNG bytes, base64 in the platform secure store
under key `device_secret_v2` (Android: Keystore-backed
flutter_secure_storage; Linux: libsecret). It is created on first vault
write and destroyed by "Erase all data". If the secure store is unreadable,
vault operations fail closed with DeviceKeyException rather than weaken.

## Legacy read-only path (v1, "BNBVL003", version byte 1)

v1.0.2 envelopes are single-box: header(AAD) ‖ nonce ‖ ct ‖ mac, keyed by
Argon2id(password, salt) directly. v1.0.3 accepts them with the same
parameter floor and upgrades nothing silently: the next vault save re-wraps
the data in v2. The version byte must be 1 for the v1 path.

## App-lock PIN

- Record format: `a2:<saltB64(16 bytes)>:<hashB64(32 bytes)>` in secure
  storage key `app_lock_pin_hash`.
- `hash = base64(Argon2id(pin, nonce=ascii(saltString), 64 MiB, t=3, p=4))`
  — the base64 salt string itself (22 bytes) is the Argon2 salt, so the
  record is deterministic for a given PIN+salt.
- Comparison is constant-time over the raw bytes.
- Records without the `a2:` prefix (v1.0.2 SHA-256) are refused and
  deleted; the lock screen then takes the user to a fresh setup.
- Failed-unlock backoff: after the n-th failure, the next attempt waits
  `min(2^(n-1), 900)` seconds. State is `"<count>:<untilEpochMs>"` in
  secure-storage key `app_lock_backoff`; reading the remaining window
  re-anchors it to "now + remaining", so booting backward/forward does
  not reset it. Vault password attempts are already rate-limited by
  Argon2id's cost.

## Cold-wallet transaction format (EIP-1559)

Implemented in `lib/cold_tx_codec.dart`; used by the cold signer, the strict
response verifier and the online broadcast gate.

Unsigned payload:

```
0x02 || rlp([
  chainId, nonce, maxPriorityFeePerGas, maxFeePerGas,
  gasLimit, to, value, data, accessList
])
```

Signing digest: `keccak256(unsigned payload)`. Signed payload appends
`yParity, r, s` to the same list. `yParity` is 0 or 1. `r` and `s` must be in
`[1, n-1]` and `s <= n/2` (low-s); the parser rejects non-canonical RLP,
non-minimal integers, trailing bytes, wrong field counts and access lists
(the cold protocol does not support them).

The internal `ColdTxSignature.v` stores the **full ECDSA recovery id** (0–3),
while the serialized EIP-1559 transaction contains only `yParity`. The
verifier checks that `v & 1 == yParity`, parses the raw transaction, compares
every field and the transaction hash, and recovers the signer with secp256k1.
Exactly one recovery candidate must match the paired address. No private key
or seed is stored in a request or response.

The independent fixture is in `verification/fixture.json`; it uses the public
Hardhat/Anvil test mnemonic (`test test ... junk`) and no funded key. The
fixture values are reproduced by ethers.js, not accepted on trust from the
Dart implementation.

## TLS SPKI pinning

`lib/net/privacy_client.dart` performs a normal `SecureSocket.connect` with
standard CA and hostname validation first. If the node has pinned SPKI
hashes, the peer certificate's SubjectPublicKeyInfo is extracted and hashed
with SHA-256; the base64 value must match one of the pins. A wrong pin closes
the connection. A pin cannot make an untrusted chain or wrong hostname
acceptable, and an empty pin list fails closed.

SPKI extraction follows RFC 5280: the subjectPublicKeyInfo is element 6 of
`TBSCertificate` when the explicit `[0]` version field is present, element 5
otherwise. The earlier code used index 7 for v3 certificates, which hashed
the extensions block instead of the public key. `test/tls_pinning_test.dart`
compares the Dart result with OpenSSL's independent extraction.

Pinned HTTP CONNECT is refused before opening a socket; that transport does
not yet enforce pins.

## Process memory hardening (Linux)

`lib/memory_protection.dart` calls the kernel through FFI:

- `prctl(PR_SET_DUMPABLE, 0)` — prevents same-UID `ptrace`/core inspection
  of the wallet process (subject to kernel policy);
- `setrlimit(RLIMIT_CORE, 0)` — no core files;
- `mlockall(MCL_CURRENT | MCL_FUTURE)` — best effort; may fail under a low
  `RLIMIT_MEMLOCK`, and the app reports failure instead of claiming success.

This is not a secure enclave, not encrypted memory, and does not protect
against a compromised OS or a process running as the same user before the
call. `test/memory_protection_test.dart` reads back the real kernel state.

## Preferences and secrets separation

SharedPreferences (`*Preferences` plugin, plaintext files) may contain ONLY:
`network`, `rpc`, `nodes`, `tokens`, `profiles`, `auto_lock_seconds`,
`tor_enabled`, `tor_host`, `tor_port` — public configuration, no secrets.

Secure storage (`flutter_secure_storage`) contains ONLY:
`device_secret_v2`, `app_lock_pin_hash`, `app_lock_backoff`,
`bscscan_api_key` — all of which "Erase all data" removes.

The live Home history is never written to disk (in-memory only). The receipt
archive (`bnb-wallet-receipts.bin`, `BNBRCPT1`) and the activity log
(`bnb-wallet-log.bin`, `BNBLOG01`) are encrypted at rest with per-file keys
derived from the wallet key plus the device drawer secret; the plain pending-tx
status list holds public data only.

## Vault write path

`AppStorage.writeVaultAtomic`: serialize base64 → write `<file>.tmp`
→ flush → `rename(tmp, file)` (atomic on POSIX; unlink+rename fallback on
platforms refusing replace) → `chmod 600` on Linux/macOS. A crash before
the rename leaves the previous vault byte-identical; after the rename, the
new one.

## Erase all data

1. Overwrite vault + `.tmp` with CSPRNG bytes of equal size (best effort;
   flash wear-leveling prevents guarantees) then unlink both.
2. Delete secure-storage keys. This removes the device factor; it does NOT
   make a retained vault copy undecryptable with the password.
3. Remove every preference key the app owns.
4. Clear in-memory caches and UI state.

Recovery afterward requires the 24-word seed phrase. Nothing in the app
can recover funds without it.

## Honest caveats

- The composition (this repo) has no third-party audit. See THREAT_MODEL.
- Argon2id in a Dart VM is software-level: it provides the standard
  64 MiB/t=3 cost per guess; it is not a memory-hardness innovation.
- CSPRNG is `Random.secure()` (getrandom(2) on Linux/Android).
- On-chain data is public; Tor mode protects the transport path only.
