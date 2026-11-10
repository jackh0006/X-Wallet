#!/usr/bin/env bash
# Build a signed Android arm64 release APK of X Wallet.
#
# Signing material is NEVER stored in this repository. The caller must provide
# an existing keystore and its credentials through the environment:
#
#   BNB_KEYSTORE   absolute or relative path to a .jks/.keystore file
#   BNB_KEY_ALIAS  key alias inside that keystore
#   BNB_STORE_PASS keystore password
#   BNB_KEY_PASS   key password (may equal BNB_STORE_PASS)
#   BNB_EXPECTED_SIGNER_SHA256 SHA-256 certificate digest of the approved,
#                              rotated Android release signer (64 hex digits)
#
# Optional:
#   BNB_VERSION    version string used in the output filename (default: from pubspec.yaml)
#   BNB_OUTDIR     output directory (default: ./dist)
#   BNB_GPG_KEY    GPG key id for the detached signature (default: skip signing)
#
# The keystore is not generated here. A missing keystore is a hard error:
# silently minting a new signing identity would produce an APK that cannot be
# upgraded over previous installs and would hide a lost release key.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${BNB_KEYSTORE:?BNB_KEYSTORE must point to a release keystore (never commit it)}"
: "${BNB_KEY_ALIAS:?BNB_KEY_ALIAS is required}"
: "${BNB_STORE_PASS:?BNB_STORE_PASS is required}"
: "${BNB_KEY_PASS:?BNB_KEY_PASS is required}"
: "${BNB_EXPECTED_SIGNER_SHA256:?BNB_EXPECTED_SIGNER_SHA256 is required (the approved release signer certificate SHA-256)}"
: "${BNB_RELEASE_OWNER_APPROVED:?BNB_RELEASE_OWNER_APPROVED=1 is required after the incident runbook is complete}"

EXPECTED_SIGNER="${BNB_EXPECTED_SIGNER_SHA256,,}"
if [[ ! "$EXPECTED_SIGNER" =~ ^[0-9a-f]{64}$ ]]; then
  echo "ERROR: BNB_EXPECTED_SIGNER_SHA256 must be a 64-character hex digest." >&2
  exit 1
fi

if [[ "$BNB_RELEASE_OWNER_APPROVED" != "1" ]]; then
  echo "ERROR: the release owner has not approved an Android build." >&2
  echo "Complete docs/security/INCIDENT_2026-11-KEYSTORE.md first." >&2
  exit 1
fi

DENYLIST="$ROOT/release/android-signer-denylist.txt"
if [[ ! -f "$DENYLIST" ]]; then
  echo "ERROR: missing $DENYLIST; the compromised signer is not denylisted." >&2
  exit 1
fi
if ! grep -Eq '^[[:space:]]*[0-9a-fA-F:]{64,95}[[:space:]]*(#.*)?$' "$DENYLIST"; then
  echo "ERROR: $DENYLIST contains no confirmed compromised fingerprint." >&2
  echo "Refusing to build Android until the historical signer is denylisted." >&2
  exit 1
fi

if [[ ! -f "$BNB_KEYSTORE" ]]; then
  echo "ERROR: keystore not found: $BNB_KEYSTORE" >&2
  echo "Provide an existing release keystore. This script never creates one." >&2
  exit 1
fi

case "$BNB_KEYSTORE" in
  "$ROOT"/*)
    if git ls-files --error-unmatch "${BNB_KEYSTORE#"$ROOT"/}" >/dev/null 2>&1; then
      echo "ERROR: the keystore is tracked by git. Remove it from the index and rotate the key." >&2
      exit 1
    fi
    ;;
esac

VERSION="${BNB_VERSION:-$(sed -n 's/^version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' pubspec.yaml | head -1)}"
VERSION="${VERSION:-0.0.0}"
OUTDIR="${BNB_OUTDIR:-$ROOT/dist}"
APK="$OUTDIR/x-wallet-${VERSION}-android-arm64.apk"

mkdir -p "$OUTDIR"

echo "[1/5] Building arm64 release APK ..."
SPLIT_DEBUG_DIR="${BNB_SPLIT_DEBUG_DIR:-$OUTDIR/debug-info}"
mkdir -p "$SPLIT_DEBUG_DIR"
ORG_GRADLE_PROJECT_xwalletAbi=arm64-v8a \
  flutter build apk --release --target-platform android-arm64 --no-pub \
    --obfuscate --split-debug-info="$SPLIT_DEBUG_DIR/arm64"
ARM_UNSIGNED="$OUTDIR/x-wallet-${VERSION}-android-arm64-unsigned.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$ARM_UNSIGNED"
ARM_LIST="$(unzip -l "$ARM_UNSIGNED")"
case "$ARM_LIST" in
  *'lib/arm64-v8a/libapp.so'*) ;;
  *) echo "ERROR: arm64 APK does not contain arm64-v8a/libapp.so" >&2; exit 1 ;;
esac
case "$ARM_LIST" in
  *'lib/x86_64/libapp.so'*) echo "ERROR: arm64 APK unexpectedly contains x86_64 libraries" >&2; exit 1 ;;
esac

echo "[2/5] Building universal (ARM 32/64) release APK ..."
ORG_GRADLE_PROJECT_xwalletAbi= \
  flutter build apk --release --no-pub \
    --target-platform android-arm,android-arm64 \
    --obfuscate --split-debug-info="$SPLIT_DEBUG_DIR/universal"
UNIVERSAL_UNSIGNED="$OUTDIR/x-wallet-${VERSION}-android-universal-unsigned.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$UNIVERSAL_UNSIGNED"
UNIVERSAL_LIST="$(unzip -l "$UNIVERSAL_UNSIGNED")"
for abi in arm64-v8a armeabi-v7a; do
  case "$UNIVERSAL_LIST" in
    *"lib/$abi/libapp.so"*) ;;
    *) echo "ERROR: universal APK is missing $abi" >&2; exit 1 ;;
  esac
done
case "$UNIVERSAL_LIST" in
  *'lib/x86_64/libapp.so'*) echo "ERROR: universal APK unexpectedly contains x86_64 libraries" >&2; exit 1 ;;
esac

ANDROID_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-$HOME/Android/Sdk/build-tools/36.0.0}"
APKSIGNER="$ANDROID_BUILD_TOOLS/apksigner"
ZIPALIGN="$ANDROID_BUILD_TOOLS/zipalign"
if [ ! -x "$APKSIGNER" ] || [ ! -x "$ZIPALIGN" ]; then
  echo "ERROR: Android build-tools not found under $ANDROID_BUILD_TOOLS" >&2
  echo "Set ANDROID_BUILD_TOOLS to a directory containing apksigner and zipalign." >&2
  exit 1
fi

sign_one() {
  local unsigned="$1"
  local apk="$2"
  echo "[3/5] Signing $(basename "$apk") ..."
  "$APKSIGNER" sign \
    --ks "$BNB_KEYSTORE" \
    --ks-key-alias "$BNB_KEY_ALIAS" \
    --ks-pass env:BNB_STORE_PASS \
    --key-pass env:BNB_KEY_PASS \
    --min-sdk-version 26 \
    --v3-signing-enabled true \
    --v4-signing-enabled false \
    --out "$apk" \
    "$unsigned"
  "$ZIPALIGN" -c -p 4 "$apk" >/dev/null
  echo "[4/5] Verifying $(basename "$apk") ..."
  CERT_INFO="$("$APKSIGNER" verify --print-certs "$apk")"
  "$APKSIGNER" verify "$apk" >/dev/null
  ACTUAL_SIGNER="$(printf '%s\n' "$CERT_INFO" | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | tr -d ':' | tr '[:upper:]' '[:lower:]')"
  if [[ "$ACTUAL_SIGNER" != "$EXPECTED_SIGNER" ]]; then
    echo "ERROR: APK signer certificate does not match BNB_EXPECTED_SIGNER_SHA256." >&2
    echo "Refusing to emit an artifact signed by an unapproved key." >&2
    exit 1
  fi
  bash "$ROOT/scripts/verify-android-signer.sh" "$apk" \
    --allow "$EXPECTED_SIGNER" \
    --deny "$DENYLIST" \
    --require-deny
  sha256sum "$apk" > "$apk.sha256"
  echo "Signer certificate SHA-256: $ACTUAL_SIGNER"
}

ARM_APK="$OUTDIR/x-wallet-${VERSION}-android-arm64.apk"
UNIVERSAL_APK="$OUTDIR/x-wallet-${VERSION}-android-universal.apk"
sign_one "$ARM_UNSIGNED" "$ARM_APK"
sign_one "$UNIVERSAL_UNSIGNED" "$UNIVERSAL_APK"

echo "[5/5] Done"

if [ -n "${BNB_GPG_KEY:-}" ]; then
  for apk in "$ARM_APK" "$UNIVERSAL_APK"; do
    gpg --batch --yes --digest-algo SHA256 \
      --default-key "$BNB_GPG_KEY" \
      --detach-sign --armor "$apk"
    echo "      $apk.asc"
  done
else
  echo "      (no GPG key supplied; set BNB_GPG_KEY for detached signatures)"
fi

echo "APK arm64:     $ARM_APK"
echo "APK universal: $UNIVERSAL_APK"
echo "SHA256 arm64:  $(cat "$ARM_APK.sha256")"
echo "SHA256 universal: $(cat "$UNIVERSAL_APK.sha256")"
echo "Signer certificate SHA-256: $ACTUAL_SIGNER"
