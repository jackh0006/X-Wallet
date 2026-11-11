# Linux security audit

## Verified

- `umask(077)` before Flutter; data dir 0700; vault/log/receipt/drawer 0600.
- Descriptor-pinned atomic writes with `O_NOFOLLOW`, `O_EXCL`, `renameat`, fsync and read-back.
- `.deb` has no setuid/setgid; `postinst` only refreshes icon/desktop caches, no network.
- Launcher `/usr/bin/x-wallet`, compatibility alias `bnb-wallet`, offline launcher, desktop entries, icons, SBOM.
- Dependency closure: `ldd` on the main binary resolves; the rootless launch smoke stayed alive under Xvfb.
- Offline launcher `unshare -rn` fails closed; `util-linux` is now declared.

## Remaining

- **MEDIUM:** `GDK_BACKEND=x11` forces X11 under Wayland, losing Wayland client isolation.
- **MEDIUM:** `Depends` is hand-written, not `dpkg-shlibdeps`; plugin `.so` closure is not ldd-checked.
- **MEDIUM:** offline `.desktop` used to share `Name=X Wallet`; now `Name=X Wallet (Cold)`.
- **LOW:** `.deb` Version drops the `+15` build suffix; filename/version differs from the app.
- **BLOCKED:** clean apt install/upgrade/uninstall smoke (no root/apt in this environment). The rootless launch smoke is not an install smoke.
