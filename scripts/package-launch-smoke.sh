#!/usr/bin/env bash
# Structural + launch smoke for the built .deb without root.
#
# The full scripts/package-smoke.sh installs with apt and needs root plus Xvfb.
# This variant extracts the package, checks the dependency closure and the
# desktop identity, then launches the real binary under Xvfb for a fixed
# window. It proves the package contents run; it does NOT prove apt
# install/upgrade/uninstall, which remains a separate CI job.
set -euo pipefail

DEB="${1:-}"
SECONDS_TO_RUN="${2:-10}"
if [ -z "$DEB" ] || [ ! -f "$DEB" ]; then
  echo "usage: $0 <deb> [seconds]" >&2
  exit 2
fi

XVFB_BIN="${XVFB_BIN:-Xvfb}"
if ! command -v "$XVFB_BIN" >/dev/null 2>&1; then
  echo "ERROR: Xvfb not found (set XVFB_BIN)." >&2
  exit 1
fi

WORK="$(mktemp -d /tmp/x-wallet-pkg-smoke-XXXXXX)"
XVFB_PID=""
cleanup() {
  if [ -n "$XVFB_PID" ]; then kill "$XVFB_PID" 2>/dev/null || true; fi
  rm -rf "$WORK"
}
trap cleanup EXIT

dpkg-deb -x "$DEB" "$WORK/root"
BIN="$WORK/root/usr/lib/x-wallet/bnb_wallet_gui"
[ -x "$BIN" ] || { echo "ERROR: binary missing from package" >&2; exit 1; }

echo "== dependency closure =="
if ldd "$BIN" 2>&1 | grep -q 'not found'; then
  ldd "$BIN" 2>&1 | grep 'not found' >&2
  exit 1
fi
echo "ldd: all libraries resolve"

echo "== desktop identity =="
grep -qx 'Name=X Wallet' "$WORK/root/usr/share/applications/x-wallet.desktop"
if grep -q '^Name=.*[0-9]' "$WORK/root/usr/share/applications/x-wallet.desktop"; then
  echo "ERROR: desktop Name carries a version" >&2
  exit 1
fi
echo "desktop Name=X Wallet"

echo "== launch under Xvfb for ${SECONDS_TO_RUN}s =="
"$XVFB_BIN" :97 -screen 0 1280x900x24 >"$WORK/xvfb.log" 2>&1 &
XVFB_PID=$!
sleep 2
set +e
DISPLAY=:97 timeout "${SECONDS_TO_RUN}s" "$BIN" >"$WORK/launch.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 124 ]; then
  echo "ERROR: the app exited early (rc=$rc)" >&2
  tail -40 "$WORK/launch.log" >&2 || true
  exit 1
fi
echo "launch: stayed alive for ${SECONDS_TO_RUN}s (expected timeout 124)"
echo "package launch smoke: PASS"
