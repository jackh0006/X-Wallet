# Audit-known limitations

- No independent professional audit.
- No independent-machine rebuild; fixed-path same-host only.
- No physical Android install/run; no native KDF timing.
- No physical two-device cold signing.
- No real screen-reader/assistive-technology session.
- No packet capture/`strace` artifact.
- No Anvil in this environment; the 3 real-EVM tests are BLOCKED here.
- No root/apt install/upgrade/uninstall smoke; only a rootless extract+launch smoke.
- `unshare -rn` blocked by the container; the offline launcher is shipped fail-closed, success path untested.
- No Argon2 RFC/BIP-32 official/Wycheproof vectors; one ethers.js cold fixture.
- No zeroisation; Dart managed memory cannot guarantee erasure.
- Linux device secret is a same-user 0600 drawer, not hardware-bound.
- Vault format is not a true 2-of-2.
- Legacy pre-1.2 data directories can survive erase.
- Cold pairing fingerprint is 4 bytes of address[0]; no cryptographic pairing authentication.
- Cold derivation path/passphrase is fixed; custom paths unsupported.
- Release tag ≠ evidence/tested code; tag CITATION is stale.
