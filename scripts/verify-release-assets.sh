#!/usr/bin/env bash
# Verify a published GitHub release against its signed hashes and evidence.
set -euo pipefail

TAG="${1:?usage: $0 <tag> [assets-dir]}"
ASSETS="${2:-release-assets}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXPECTED_SIGNER="${EXPECTED_ANDROID_SIGNER:-2a96a384eb0db55bb4fb0fb2107df386ecc595b38bc46225ef9b18309d93ba9a}"

EXPECTED_GPG="${EXPECTED_GPG_FINGERPRINT:-CC819EF5E109A1518E840379D8C0CEC84BCCE06B}"

# Verify against the repository's published public key only. A clean runner has
# no owner keyring; importing the committed public key keeps the check
# reproducible without trusting a keyserver.
if ! gpg --batch --list-keys "$EXPECTED_GPG" >/dev/null 2>&1; then
  gpg --batch --import "$ROOT/docs/keys/x-wallet-signing-key.asc" >/dev/null 2>&1
fi
actual_fpr="$(gpg --batch --with-colons --fingerprint "$EXPECTED_GPG" 2>/dev/null | sed -n 's/^fpr:::::::::\([^:]*\):/\1/p' | head -1)"
[ "$actual_fpr" = "$EXPECTED_GPG" ] || {
  echo "ERROR: signing key fingerprint $actual_fpr != $EXPECTED_GPG" >&2
  exit 1
}

mkdir -p "$ASSETS"
gh release download "$TAG" --dir "$ASSETS" --clobber

(
  cd "$ASSETS"
  echo "== signed checksums =="
  gpg --batch --verify SHA256SUMS.asc SHA256SUMS
  echo "== artifact hashes =="
  sha256sum -c SHA256SUMS
  echo "== detached artifact signatures =="
  for sig in *.deb.asc *.apk.asc; do
    [ -f "$sig" ] || continue
    gpg --batch --verify "$sig" "${sig%.asc}"
  done
  echo "== deb identity =="
  DEB="$(find . -maxdepth 1 -name '*.deb' -print -quit)"
  dpkg-deb -f "$DEB" Package Version Description >/dev/null
  echo "package: $(dpkg-deb -f "$DEB" Package) $(dpkg-deb -f "$DEB" Version)"
  [ "$(dpkg-deb -f "$DEB" Package)" = "x-wallet" ]
  desc="$(dpkg-deb -f "$DEB" Description)"
  case "$desc" in
    "X Wallet —"*) ;;
    *) echo "ERROR: unexpected deb description: $desc" >&2; exit 1 ;;
  esac
  echo "== APK signer =="
  if command -v apksigner >/dev/null 2>&1; then
    for apk in ./*.apk; do
      [ -f "$apk" ] || continue
      actual="$(apksigner verify --print-certs "$apk" | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | tr -d ':' | tr '[:upper:]' '[:lower:]')"
      [ "$actual" = "$EXPECTED_SIGNER" ] || { echo "ERROR: $apk signer $actual" >&2; exit 1; }
      apksigner verify "$apk" >/dev/null
      echo "PASS signer $apk"
    done
  else
    echo "apksigner unavailable; APK signer check SKIPPED"
  fi
)

echo "== release gate against downloaded assets =="
cd "$ROOT"
python3 scripts/release-gate.py --require-verified --artifacts-dir "$(cd "$ASSETS" && pwd)"
echo "release assets: PASS ($TAG)"
