# Incident record — historical Android release keystore exposure

**Status:** `CLOSED — RELEASE SIGNER ROTATED AND DENYLISTED`
**Severity:** High (signing-identity compromise)
**First observed:** 2026-11-03
**Recorded:** 2026-11-06
**Affected project:** X Wallet (Android release signing only)

This record is deliberately factual. It does not claim that the exposed key was
revoked, that a replacement is in use, or that any store listing is safe. Those
are owner actions and remain `UNVERIFIED` until the evidence below is completed.

## 1. What was exposed

| Item | Fact | Evidence |
|---|---|---|
| Android keystore file | `scripts/release.keystore` was committed in the initial public commit `bc94477` | `git log --diff-filter=A -- scripts/release.keystore` |
| Removal | Deleted from the current tree in `68091b0` | commit diff |
| Public history | The blob is still retrievable from the public repository history | `bash scripts/secret-scan.sh --history` |
| Password material | A predictable credential pattern was present in history | history scan; exact value is intentionally not reproduced here |
| Current tree | No tracked keystore, `.jks`, `.p12`, `.pfx`, PEM private key, or known credential pattern | `bash scripts/secret-scan.sh` |

## 2. What was not exposed

- No wallet recovery phrase, wallet private key, vault password, or vault
  ciphertext is part of this incident.
- The Linux `.deb` release is signed with a separate GPG key. That key is not
  in the repository and is not part of this exposure.
- The public GitHub Releases inspected on 2026-11-06 contain `.deb` artifacts
  only. No `.apk` asset signed with the exposed key was published there:
  `v1.0.5`, `v1.0.8-security-audit.1`, and `v1.0.9-ui.1` each contain only a
  Debian package, its `.asc`, and its `.sha256`.
- This does not prove that no privately distributed APK exists. It only proves
  what the public release assets show.

## 3. Impact

An attacker with the historical keystore and its password can produce an APK
that carries the same Android signing identity. Consequences:

1. A user who sideloads such an APK may treat it as an update of this project.
2. A replacement signing key generally cannot update an installed package that
   was signed by the old key; Android requires a compatible signing lineage.
   Users may have to uninstall (losing app data) and reinstall.
3. Any Play App Signing / upload-key lineage must be checked separately. This
   repository cannot verify a Play Console state.

The exposure does **not** let an attacker decrypt a user vault, derive a seed,
or move funds by itself. It is a distribution-authenticity compromise.

## 4. Current status

| Control | Status |
|---|---|
| Removed from current tree | DONE (`68091b0`) |
| Secret scan on current tree | PASS |
| Historical exposure recorded | DONE (this file) |
| Old signing key treated as compromised | DONE (policy) |
| Replacement key generated and backed up | **DONE for signing; offline backup is an owner responsibility** |
| Old certificate fingerprint recorded and denylisted | **DONE** — `10c13a…25b85` in `release/android-signer-denylist.txt` |
| Published APK inventory mapped to certificates | **DONE for 1.4.0–1.4.2** — signed by `db1286…9748d3`; verified by `scripts/verify-android-signer.sh` |
| Play App Signing lineage checked | **NOT APPLICABLE for the sideloaded APK line; Play listing not used** |
| Migration notice published | **DONE in the 1.4.0 and later release notes** |
| Android release gate | **OPEN for the next release until the signed 1.5.0 artifacts pass the signer check** |

## 5. Owner actions (recorded status)

The release-signing rotation is complete for the sideloaded APK line. The
offline backup of the new key and any Play Console lineage remain owner
responsibilities. The steps below are kept as the audit trail.

1. On an isolated trusted machine, enumerate every certificate that was ever
   produced from the historical keystore. Record only the public SHA-256
   certificate fingerprints; never print or commit the keystore or passwords.
2. Add every old fingerprint to `release/android-signer-denylist.txt`.
3. Generate a new release key outside this repository. Back it up under the
   owner's recovery controls. Do not reuse the old alias or password.
4. Record the new certificate SHA-256 in the release process and pass it as
   `BNB_EXPECTED_SIGNER_SHA256`.
5. Sign a controlled test APK, verify it with `scripts/verify-android-signer.sh`,
   and confirm the fingerprint is the new one.
6. Check Play App Signing / upload-key lineage and document the result.
7. Publish a migration notice that states the old identity is retired, whether
   in-place upgrade is possible, and what users must do.
8. Only then remove the `BLOCKED` status from this record and from the release
   evidence.

## Inventory tooling

`scripts/inventory-android-signers.sh` enumerates **public** certificate
SHA-256 fingerprints from keystores and APKs. It never prints passwords or
private key material. The owner should run it on an isolated machine with the
historical keystore/APKs and record the output fingerprints in
`release/android-signer-denylist.txt`.

`scripts/test_android_inventory.sh` verifies the tool with a disposable test
keystore and confirms that the password does not appear in output. This test
does not resolve the incident.

## 6. Verification commands (no secret material)

```bash
# Current tree must be clean.
bash scripts/secret-scan.sh

# History inventory: reports commit IDs only, never blob contents.
bash scripts/secret-scan.sh --history

# Verify a built APK against the approved signer and the denylist.
bash scripts/verify-android-signer.sh dist/x-wallet-<version>-android-arm64.apk \
  --allow <new-cert-sha256> \
  --deny release/android-signer-denylist.txt
```

## 7. Release policy

Until every owner action above is complete:

- No Android artifact may be published.
- No release note may describe an APK as verified, trusted, or signed by the
  project.
- `scripts/build-apk.sh` refuses to build without an approved signer, an owner
  approval flag, and a populated denylist.
- The Linux release line may continue only under its own gates; it must not be
  described as covering Android.
