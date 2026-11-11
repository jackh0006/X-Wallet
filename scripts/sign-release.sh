#!/usr/bin/env bash
# Sign a release package with an existing owner-controlled GPG key.
#
# This script never generates, imports, or stores a private key. It refuses to
# run unless the requested secret key already exists in the active GNUPGHOME.
#
# Usage:
#   scripts/sign-release.sh --deb <path> --key <fingerprint-or-uid> [--outdir DIR]
set -euo pipefail

# Optional non-interactive signing for a passphrase-protected key.
GPG_EXTRA=()
if [ -n "${BNB_GPG_PASSPHRASE_FILE:-}" ]; then
  GPG_EXTRA=(--pinentry-mode loopback --passphrase-file "$BNB_GPG_PASSPHRASE_FILE")
fi

DEB=""
KEY=""
OUTDIR=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --deb) DEB="${2:?}"; shift 2 ;;
    --key) KEY="${2:?}"; shift 2 ;;
    --outdir) OUTDIR="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$DEB" ] || { echo "ERROR: --deb is required" >&2; exit 2; }
[ -n "$KEY" ] || { echo "ERROR: --key is required" >&2; exit 2; }
[ -f "$DEB" ] || { echo "ERROR: package not found: $DEB" >&2; exit 1; }
DEB="$(cd "$(dirname "$DEB")" && pwd)/$(basename "$DEB")"
OUTDIR="${OUTDIR:-$(dirname "$DEB")}"
mkdir -p "$OUTDIR"

if ! gpg --batch --list-secret-keys --with-colons "$KEY" 2>/dev/null | grep -q '^sec:'; then
  echo "ERROR: no secret key matches '$KEY' in this GNUPGHOME." >&2
  echo "This script never creates or imports a signing key." >&2
  exit 1
fi

# Refuse an ambiguous selector: exactly one primary secret key must match.
# A key may have subkeys, so count `sec` records, not every `fpr` record.
SEC_COUNT="$(
  gpg --batch --list-secret-keys --with-colons "$KEY" 2>/dev/null |
    awk -F: '$1=="sec"{count++} END{print count+0}'
)"
if [ "$SEC_COUNT" -ne 1 ]; then
  echo "ERROR: selector matched $SEC_COUNT primary secret keys; specify one fingerprint." >&2
  exit 1
fi
FPR="$(
  gpg --batch --list-secret-keys --with-colons --fingerprint "$KEY" 2>/dev/null |
    awk -F: '$1=="sec"{in_sec=1; next} $1=="fpr" && in_sec{print $10; exit}'
)"
if [[ ! "$FPR" =~ ^[0-9A-Fa-f]{40}$ ]]; then
  echo "ERROR: could not resolve a 40-hex primary fingerprint." >&2
  exit 1
fi

SUMS="$OUTDIR/SHA256SUMS"
SIG="$OUTDIR/SHA256SUMS.asc"
(
  cd "$(dirname "$DEB")"
  sha256sum "$(basename "$DEB")" >"$SUMS"
)
gpg "${GPG_EXTRA[@]}" --batch --yes --armor --detach-sign --local-user "$FPR" \
  --output "$SIG" "$SUMS"
gpg --batch --verify "$SIG" "$SUMS" >/dev/null

echo "Signed checksum manifest: $SIG"
echo "Package: $DEB"
echo "SHA256SUMS: $SUMS"
echo "Signing fingerprint: $FPR"
echo "Verify with: scripts/verify-release-signature.sh --deb \"$DEB\" --sums \"$SUMS\" --sig \"$SIG\" --fingerprint \"$FPR\""
