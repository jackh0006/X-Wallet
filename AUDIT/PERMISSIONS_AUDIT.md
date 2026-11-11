# Permissions audit

## Android

- Declared: `INTERNET`, `USE_BIOMETRIC`, `USE_FINGERPRINT`. No storage, camera, contacts, location, notification, accessibility or overlay permission.
- One exported component: the launcher `MainActivity`. No services, receivers, providers or deep links.
- `allowBackup=false`, `fullBackupContent=false`, `dataExtractionRules` excludes root.
- `usesCleartextTraffic=false`; NSC trusts system CAs only.
- `FLAG_SECURE` and `filterTouchesWhenObscured` are applied.
- Release Gradle buildType still uses the debug signing config; CI outputs are no longer uploaded as release artifacts in this audit branch. Only `scripts/build-apk.sh` produces publishable APKs with the owner keystore and signer pin.

## Linux

- Launcher runs as the user; no setuid/setgid files in the `.deb`.
- `umask(077)` before Flutter; data dir 0700; vault/log/receipt/drawer 0600.
- `postinst` only refreshes icon/desktop caches; no network.
- Offline launcher uses `unshare -rn` and fails closed; `util-linux` is now declared.
- The app forces `GDK_BACKEND=x11` under Wayland, losing Wayland client isolation. Documented residual.
