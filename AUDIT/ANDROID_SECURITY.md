# Android security audit

## Verified from source/artifacts

- Permissions: INTERNET, USE_BIOMETRIC, USE_FINGERPRINT only.
- One exported component: launcher `MainActivity`; no services/receivers/providers/deep links.
- `allowBackup=false`, `fullBackupContent=false`, dataExtractionRules exclude root.
- `FLAG_SECURE`, `filterTouchesWhenObscured`, `usesCleartextTraffic=false`, system CAs only.
- R8 + resource shrinking; Dart obfuscation + split debug info in `build-apk.sh`.
- Native Argon2 (`libargon2-arm.so`) is vendored; ABI checks in start script/CI.
- 1.5.3 APKs are signed with `2a96a384…3ba9a`; the 1.5.1 signer is different, so no in-place upgrade. The exposed historical key is denylisted.

## Findings

**CRITICAL — fixed in this audit branch:** Gradle `release` used `signingConfig = debug`, and CI uploaded those APKs as release artifacts. The CI upload is removed; CI now explicitly states the output is not publishable. Only `scripts/build-apk.sh` (owner keystore, signer allowlist + denylist) produces release APKs.

**HIGH — remaining:** the physical APK was not installed or run; `FLAG_SECURE`, biometrics, keystore behavior and native KDF timing are **UNVERIFIED** on a device.

**MEDIUM:** APK MethodChannel `openBytes` buffers a whole SAF file with no size cap (OOM DoS).

**MEDIUM:** the vendored Argon2 CMake uses `-Os` without stack-protector/fortify flags.

**MEDIUM:** Gradle wrapper distribution is not checksum-pinned.

**LOW:** stale R8 keep rule for the old package; redundant NSC domain list.

## Upgrade

A new certificate cannot upgrade 1.5.1 in place. The release must instruct: portable backup → uninstall 1.5.1 → install 1.5.3. This is documented in README/ANDROID_RELEASE/CLAIM_REGISTER.
