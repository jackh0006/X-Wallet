# X Wallet self-audit — final report

## 1. Repository and commits

- Repository: https://github.com/jackh0006/X-Wallet
- Baseline `main`: `8583393bf3dc98400bc772346ea7608ad1c104be`
- Latest release tag: `v1.5.3` at `34d31e1cc8375b5bbd491edba751c9f1760b9df0`
- Tested code commit for the published artifacts: `b84c6feeeb1a7feb2aa7123939b206606adbec84`
- Audit branch: `audit/1.5.3-self-audit` (local; fixes committed locally, **not pushed**)
- Audit docs commit: `c5810ae`
- Version: `1.5.3+15`

## 2. Scope inspected

- 414 tracked files; all inventoried in `AUDIT/FILE_INVENTORY.md` and `docs/SOURCE_MAP.md`.
- Full reads of vault, KDF, portable backup, wallet core, security/PIN, storage/posix, log/receipt stores, RPC/price/privacy/Tor, send/fee/tx/policy, cold wallet/codec/protocol/service, Android manifest/Kotlin/Gradle, Linux runner/CMake, all CI workflows and release scripts, and the security/threat/crypto/network docs.
- Test suite: 69 files / 391 declarations; 68 non-integration files executed.

## 3. Vulnerabilities discovered

**Critical**
1. `AppState.eraseAll` self-deadlocked on Linux: it held the non-reentrant process lock, then `EncryptedLogStore.clear()` re-acquired it. "Erase everything" and the PIN wipe could hang.
2. Cold ERC-20 `approve`/`increaseAllowance`/`transferFrom` did not bind `assetInfo.contractAddress` to `request.to`, and the cold review did not show the contract. A request could display token A while signing an allowance on token B.

**High**
3. Per-node Tor/custom transport could fall back to public built-ins over the global (possibly direct) route.
4. Tor setup failure switched the route off and used direct HTTPS.
5. Cold mode still allowed fee quotes and IP/route probes.
6. Cold signing/broadcast bypassed `SpendingPolicy` (a frozen wallet could sign offline).
7. Unknown-broadcast rows could be removed after 120 s, clearing the double-payment guard.
8. PIN backoff overflowed after 64 failures and could become an expired cooldown; `verifyPin` did not enforce backoff itself.
9. Mobile keyring could mint a replacement device secret while a vault existed, orphaning it.
10. Node proxy/bearer credentials survived "erase all data".
11. EIP-55 mixed-case typos were silently re-checksummed.
12. CI built and uploaded debug-signed "release" APKs.

## 4. Fixed with regression tests

- Erase deadlock (`test/erase_all_appstate_test.dart`).
- Cold contract binding (`test/audit_regressions_test.dart`).
- PIN backoff overflow (`test/audit_regressions_test.dart`).
- EIP-55 mixed-case rejection (`test/audit_regressions_test.dart`).
- Cold spending policy + chain check.
- Unknown-row removal blocked.
- Per-node fallback + Tor fail-closed + cold fee/probe gates.
- Mobile re-key fail-closed (code; platform test not available).
- Node-secret erase.
- Hot review shows the token contract.
- CI no longer publishes debug-signed APKs; universal CI build is ARM-only.
- Debian `util-linux` dependency and distinct cold desktop entry.

## 5. Fixed but not fully proven

- Mobile keyring path has no platform-channel test.
- Universal APK build was not re-run after the workflow change.
- `.deb` was not rebuilt after `util-linux`/desktop-entry changes.
- Erase still does not cover pre-1.2 legacy directories.

## 6. Remaining vulnerabilities / gaps

- No independent audit, independent rebuild, physical Android run, two-device cold test or screen-reader session.
- Linux device secret is a same-user 0600 drawer; the vault is not a true 2-of-2.
- No zeroisation; secrets are immutable strings.
- Legacy v1 vaults are password-only and accepted indefinitely.
- Legacy app-ID directories can survive erase.
- Multi-vault registry/active-id writes are not atomic or locked.
- Receipts/log are shared across vaults in one directory.
- web3dart/history paths bypass the full 2 MiB/method choke point.
- BscScan API key is in the URL; custom headers are not strictly allowlisted.
- `package-smoke.yml` installs an unpinned 1.0.9 deb as root.
- Release gate accepts PARTIALLY VERIFIED; identity CI does not verify artifact hashes/signatures.
- Tag `v1.5.3` ≠ evidence commit ≠ tested commit; tag tree has CITATION 1.1.0 and no VERSION.
- No Argon2 RFC/BIP-32 official/Wycheproof vectors; one ethers fixture.

## 7. Cryptography

Argon2id 64 MiB/t=3/p=4, XChaCha20-Poly1305, HKDF-SHA256, RFC-6979 low-s secp256k1, BIP-39/32/44, EIP-55. Official BIP-39 Trezor vector and known Ethereum address pass. Vault header is authenticated and KDF parameters are exact-matched. See `AUDIT/CRYPTOGRAPHY.md`, `AUDIT/CRYPTO_TEST_VECTORS.md`.

## 8. Local storage

Atomic descriptor-pinned writes, 0600/0700, no-follow, fsync, rollback are strong. Erase now completes and removes current vaults/log/receipts/drawer/prefs/secure keys, but legacy dirs, registry corruption and shared log/receipts remain. See `AUDIT/STORAGE_AUDIT.md`, `AUDIT/DATA_CLASSIFICATION.md`.

## 9. Privacy / remote access

No telemetry, analytics, ads, AI, cloud, remote config or developer server. Prices are off by default. All HTTP construction is in one module (static test). Per-node fallback and Tor fail-open are fixed. See `AUDIT/PRIVACY_AUDIT.md`, `AUDIT/TELEMETRY_AUDIT.md`.

## 10. Network

TLS validation before pinning, SOCKS5h remote DNS, 2 MiB/allowlist on `_postJson`, URL policy. Gaps: web3dart/history bypass, chain-ID not rechecked on every call, no pcap. See `AUDIT/NETWORK_AUDIT.md`, `AUDIT/NETWORK_BEHAVIOR.md`.

## 11. Android

Permissions minimal, one exported launcher, backup disabled, FLAG_SECURE/obscured touch, system CAs, native Argon2. New 1.5.3 signer; 1.5.1 not upgradeable in place. Debug-signed CI output no longer uploaded. No physical device run. See `AUDIT/ANDROID_SECURITY.md`.

## 12. Linux

umask 077, 0700/0600, no setuid, postinst offline, offline launcher, dependency closure, launch smoke. No clean apt install/upgrade. X11 forced under Wayland. See `AUDIT/LINUX_SECURITY.md`.

## 13. Blockchain / transactions

BSC 56/97; EIP-155/1559; review binding; ERC-20 spender/contract now correct; hold-to-confirm; uncertain-broadcast guard. Nonce/`from` not in `SendIntent.verify`; speed-up/cancel and cold derivation/pairing gaps remain. See `AUDIT/TRANSACTION_SECURITY.md`, `AUDIT/BLOCKCHAIN_COMPATIBILITY.md`.

## 14. Cold signing

Canonical RLP, field-by-field verify, hash/signature/recovery, expiry, replay cap 20, payload caps. Pairing fingerprint is 4 bytes of address[0]; custom derivation/passphrase unsupported. See `AUDIT/COLD_SIGNING_AUDIT.md`.

## 15. Documentation consistency

Fixed CITATION 1.1.0→1.5.3, README 1.5.1/116-package/cross-runner claims, release-note result table, Android checksum wording, threat-model 1.0.10/rotation text. Remaining tag/evidence/main mismatch and stale 1.5.1 package-smoke. See `AUDIT/DOCUMENTATION_CONSISTENCY.md`, `AUDIT/RELEASE_TRACEABILITY.md`.

## 16. Tests

| Check | Result |
|---|---|
| `dart format --set-exit-if-changed` | PASS |
| `flutter analyze --no-pub` | PASS |
| `bash scripts/test-suite-fast.sh` | PASS — 68 non-integration files, 391 declarations, exit 0 |
| New audit regression tests | 9/9 PASS |
| `verification/verify.cjs` | PASS |
| Secret scan / dependency / licence / SBOM | PASS |
| Fixed-path reproducibility | PASS (`40ce258c…`), same host only |
| Rootless package launch smoke | PASS |
| Anvil, apt install, pcap, independent rebuild, physical Android, screen reader | BLOCKED |

## 17. Score

- **Overall self-audit: 61/100** (`AUDIT/FINAL_SCORECARD.md`).
- **Engineering quality: 74/100.**
- **Security assurance for real money: 50/100.**

## 18. Production readiness

- Development ready: **YES** on Linux.
- Internal verification: **PARTLY**.
- Release candidate verified (one identity + all checks): **NO**.
- Independent audit: **NO**.
- Production with documented residual risks: **NO**.
- Approved for substantial real-money holdings: **NO**.

## 19. Blocked

Physical Android, two-device cold signing, independent rebuild, screen reader, clean apt install/upgrade, Anvil, packet capture, `unshare` success path, Argon2/BIP-32/Wycheproof corpora, random differential fuzz.

## 20. Evidence

`AUDIT/EVIDENCE_INDEX.md`, `/tmp/xw-audit-final-suite.log`, `AUDIT/test-results.json`, `AUDIT/SBOM/`, GitHub release v1.5.3 assets, handoff folder `/home/mhh06/Downloads/X Wallet/1.5.3/`.

## 21. Publications

Per the mission rules, **nothing was pushed** and no tag/release/signing credential was changed. The audit branch and fixes are local. A new patch release is required to make the tag, evidence and tested code identical.
