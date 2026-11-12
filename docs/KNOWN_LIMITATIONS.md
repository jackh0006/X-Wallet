# Known Limitations

| ID | Limitation | Status |
|---|---|---|
| LIM-001 | A same-user process with write access to the wallet directory can race filesystem operations. Linux verifies destination device/inode against the committed descriptor immediately after rename, but no pathname check can prevent a replacement after that final check (or after return). The 0700 application data directory is the primary boundary. | Documented residual risk |
| LIM-002 | Non-Linux uses a less capable `dart:io` storage pipeline. | Not release-verified |
| LIM-003 | Directory fsync failure after rename leaves crash durability uncertain. | Explicitly surfaced; never reported as verified durability |
| LIM-004 | Hardware-wallet integration is outside the 1.x product scope. Cold/offline signing is the supported isolation path. | Out of scope |
| LIM-005 | Clean install/launch/upgrade/uninstall passes in the Ubuntu 24.04 CI smoke test (run `42302764476`), but a full interactive UI walkthrough and Debian/Fedora installs are still untested. | Partially verified |
| LIM-006 | A historical Android release keystore was exposed in public Git history. The current signer is `2a96a384…3ba9a`, the historical `10c13a…25b85` is in `release/android-signer-denylist.txt`, and rotation is verified for the sideloaded APK line. Users who skip signer verification can still install a forged APK. | Rotation verified; residual distribution risk documented |
| LIM-007 | Linux now uses a shared nonblocking `flock(2)` advisory lock on a no-follow, 0600 object in the app-data directory for vault and encrypted-log operations. It coordinates cooperating wallet processes only; it does not stop a same-UID program that ignores locks or replaces the lock pathname after the bounded identity check. Non-Linux remains process-local only. Independent-process race and crash-kill coverage is still incomplete. | Partially tested; release blocker |
| LIM-009 | This wallet has **no independent third-party security audit**. The self-audit, tests, SBOM, and gate are engineering evidence, not an audit opinion. | Unverified |
| LIM-010 | The wallet only builds plain transfers. It has no token-approval or unlimited-allowance UI, so that class of approval abuse is absent today. Adding approvals later requires an explicit cap and a separate review. | Scope limitation |
| LIM-011 | Dart strings and garbage-collected memory cannot be reliably zeroised. `mlockall` is best-effort and `PR_SET_DUMPABLE=0`/core-limit are Linux-only. No secure-erase guarantee is made. | Documented residual risk |
| LIM-012 | Balances, nonces, fees, and history are trusted from the selected RPC endpoint. No light-client or Merkle-proof verification is implemented; a lying endpoint can mislead the review screen, though it cannot forge a local signature. | Documented residual risk |
| LIM-013 | Bit-for-bit reproducibility passes only when both builds use the same absolute path (Flutter embeds `libapp.so`/plugin paths). Two clean 1.5.5 builds at `/tmp/bnb-repro-1.5.5` matched (`440aff80…8e08`), but builds at different paths differ. An independent-machine proof is still required. | Partially verified; documented constraint |
| LIM-014 | Linux camera QR scanning is not implemented. Offline cold-wallet transport is file/paste plus QR **display** only. | Not implemented |
| LIM-015 | Ethereum support shares the EVM engine and is covered by chain, explorer, signing and UI tests, but it has not been exercised against a live Ethereum node or a physical device in this environment. | NOT TESTED against live Ethereum |
| LIM-016 | Hardware-wallet integration is not implemented. No proprietary protocol was invented. | Not implemented |
| LIM-017 | Multisignature/threshold custody is not implemented. A password-protected vault is not multisig security. | Not implemented |
| LIM-018 | The cold signer builds EIP-1559 type-2 transactions only. Legacy-fee transactions are available on the hot path. | Scope boundary |
| LIM-019 | Ethereum history requires an Etherscan API key; BNB history requires a BscScan key. Keys are per chain and optional. | Documented |
| LIM-020 | A pinned price provider that fails leaves the last prices visible and marks them stale; it never silently switches. | Documented behaviour |
| LIM-021 | Default Ethereum token contracts are canonical at the time of writing; token metadata must still be verified by the user. | User verification required |
| LIM-022 | BTC/LTC/DOGE UTXO support is implemented at the core and UI level, but no live testnet transaction has been performed. | NOT TESTED on live testnet |
| LIM-023 | Taproot signing has build/determinism tests but no independent P2TR spend vector. | PARTLY verified |
| LIM-024 | PSBT, output descriptors, xprv/xpub, watch-only, RBF bumping and gap-limit discovery are not implemented. | Not implemented |
| LIM-025 | UTXO indexers (mempool.space, litecoinspace.org, BlockCypher) learn the public address and source IP unless Tor/proxy is used. | Documented privacy residual |
| LIM-026 | The UTXO UI derives only from a wallet with a recovery phrase; raw-key-only wallets cannot open it. | Scope limitation |
