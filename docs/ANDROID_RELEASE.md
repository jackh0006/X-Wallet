# Android release and signing

Status: current release line **1.5.3**. This page describes the release
identity and the owner actions. It never contains private key material.

## Current release signer

- Certificate SHA-256:
  `2a96a384eb0db55bb4fb0fb2107df386ecc595b38bc46225ef9b18309d93ba9a`
- Used by the 1.5.3 APKs.
- The 1.5.1 identity (`db12869c…9748d3`) is a different certificate. Android
  will not install 1.5.3 as an in-place upgrade over 1.5.1. Export a portable
  backup, uninstall the old app, then install 1.5.3.
- Verify:

```bash
ANDROID_BUILD_TOOLS="$HOME/Android/Sdk/build-tools/36.0.0" \
  bash scripts/verify-android-signer.sh \
  x-wallet-1.5.3-android-arm64.apk \
  --allow 2a96a384eb0db55bb4fb0fb2107df386ecc595b38bc46225ef9b18309d93ba9a \
  --deny release/android-signer-denylist.txt \
  --require-deny
```

## Historical compromised signer

- Certificate SHA-256:
  `10c13aa91cc14288df995095c6b620ff60f3c10e77fd6615635b150463e25b85`
- It was committed in the initial public history and must never be used again.
- It is listed in `release/android-signer-denylist.txt`.
- `scripts/build-apk.sh` refuses to emit an APK unless the approved-signer
  fingerprint matches and the denylist is populated.

## Build a signed release

The keystore and passwords are **never** stored in this repository. Use
environment variables on the owner's machine:

```bash
BNB_KEYSTORE=/secure/x-wallet-release.jks \
BNB_KEY_ALIAS=x-wallet \
BNB_STORE_PASS='…' \
BNB_KEY_PASS='…' \
BNB_EXPECTED_SIGNER_SHA256=2a96a384eb0db55bb4fb0fb2107df386ecc595b38bc46225ef9b18309d93ba9a \
BNB_RELEASE_OWNER_APPROVED=1 \
BNB_GPG_KEY=CC819EF5E109A1518E840379D8C0CEC84BCCE06B \
BNB_OUTDIR=/secure/x-wallet-1.5.3 \
  bash scripts/build-apk.sh
```

The script builds arm64 and an ARM-only universal APK (arm64 + armeabi-v7a;
x86_64 is deliberately excluded to keep the download smaller), verifies every ABI, signs with
apksigner v3, verifies the certificate, and writes a detached `.asc` when a GPG
key is supplied.

## Play App Signing

This project currently distributes sideloaded APKs, not a Play listing. No Play
Console lineage is claimed. If a Play listing is created later, the owner must
check the upload-key lineage separately; a locally generated key is not the
same thing as Play App Signing.

## Offline backup

The new signing key must be backed up offline by the owner. The repository
cannot verify that backup. Losing the key prevents in-place updates; users
would need to uninstall and reinstall, losing app data (not funds, if the
recovery words are safe).

## Owner checklist

- [x] Historical fingerprint denylisted.
- [x] Replacement signer generated and used for public APKs.
- [x] APK signer verified against the approved fingerprint.
- [x] Denylist checked on every signed build.
- [ ] Offline backup of the new key verified by the owner.
- [ ] Physical device install/update test recorded.
- [ ] Play Console lineage checked, if a Play listing is ever used.

## Release evidence

Every published APK has a per-file `.sha256` and a detached GPG signature.
The release page also carries a signed `SHA256SUMS` covering the assets.
The exact hashes and source commit are in `release/evidence.json` and
`release/manifest.json`. Do not call an APK verified unless the signer check
and the hash check both pass.
