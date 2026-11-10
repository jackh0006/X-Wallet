#!/usr/bin/env bash
# Static Android hardening checks that do not need a device.
#
# These are source-level assertions. The built APK is checked separately by
# the android-build workflow for ABI and native-KDF contents.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/android/app/src/main/AndroidManifest.xml"
NETWORK="$ROOT/android/app/src/main/res/xml/network_security_config.xml"
GRADLE="$ROOT/android/app/build.gradle.kts"

fail() { echo "FAIL: $*" >&2; exit 1; }

grep -q 'android:allowBackup="false"' "$MANIFEST" || fail "allowBackup is not false"
grep -q 'android:usesCleartextTraffic="false"' "$MANIFEST" || fail "cleartext traffic is not disabled"
grep -q 'android:dataExtractionRules="@xml/data_extraction_rules"' "$MANIFEST" || fail "dataExtractionRules missing"
grep -q 'android:networkSecurityConfig="@xml/network_security_config"' "$MANIFEST" || fail "networkSecurityConfig missing"

# Only these permissions are allowed. A new permission must be a deliberate,
# documented change to this list.
permissions="$(grep -oE 'android:name="android.permission.[A-Z_]+"' "$MANIFEST" | sort -u)"
expected="$(printf '%s\n' \
  'android:name="android.permission.INTERNET"' \
  'android:name="android.permission.USE_BIOMETRIC"' \
  'android:name="android.permission.USE_FINGERPRINT"' | sort -u)"
[ "$permissions" = "$expected" ] || {
  echo "Unexpected permissions:" >&2
  printf '%s\n' "$permissions" >&2
  fail "permission set changed"
}

# Exactly one exported component: the launcher activity.
exported="$(grep -c 'android:exported="true"' "$MANIFEST")"
[ "$exported" -eq 1 ] || fail "expected exactly one exported component, found $exported"

grep -q '<certificates src="system" />' "$NETWORK" || fail "system-only trust anchors missing"
if grep -q 'cleartextTrafficPermitted="true"' "$NETWORK"; then
  fail "a domain still permits cleartext"
fi
grep -q 'api.coingecko.com' "$NETWORK" || fail "CoinGecko host missing from network policy"
grep -q 'api.ipify.org' "$NETWORK" || fail "ipify host missing from network policy"

grep -q 'isMinifyEnabled = true' "$GRADLE" || fail "R8 minification is not enabled"
grep -q 'isShrinkResources = true' "$GRADLE" || fail "resource shrinking is not enabled"
grep -q 'externalNativeBuild' "$GRADLE" || fail "native Argon2 build is not wired"
grep -q "if (Platform.isAndroid)" "$ROOT/lib/kdf.dart" || fail "Android KDF candidate missing"
grep -q 'libargon2-arm.so' "$ROOT/lib/kdf.dart" || fail "Android Argon2 library name missing"

echo "Android hardening source checks: PASS"
