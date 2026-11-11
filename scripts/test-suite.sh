#!/usr/bin/env bash
# Deterministic, serial release test driver. Every test file gets its own
# Flutter process and wall-clock watchdog, so a leaked timer, isolate, or
# plugin call is attributed to one file and cannot silently hang the suite.
set -u -o pipefail
cd "$(dirname "$0")/.."

# The production Linux launcher starts with a restrictive umask.  Tests that
# exercise real storage must run under the same invariant; otherwise temp
# application directories are deliberately rejected as group-readable.
umask 0077

readonly LIGHT_TIMEOUT_SECONDS=240
readonly KDF_TIMEOUT_SECONDS=900
readonly GLOBAL_TIMEOUT_SECONDS=3600

started_epoch="$(date +%s)"
passed=0
failed=0
timed_out=0
executed=0
declare -a failed_files=()

run_one() {
  local file="$1"
  local timeout_seconds="$LIGHT_TIMEOUT_SECONDS"
  # CI images do not guarantee ripgrep.  Use POSIX grep so tag detection is
  # available everywhere the Flutter SDK is supported.
  if grep -Eq "@Tags[[:space:]]*\\([[:space:]]*\\[[[:space:]]*['\"]kdf['\"]" "$file"; then
    timeout_seconds="$KDF_TIMEOUT_SECONDS"
  fi
  printf '\n==> %s (wall limit: %ss)\n' "$file" "$timeout_seconds"
  executed=$((executed + 1))
  timeout --signal=TERM --kill-after=15s "${timeout_seconds}s" \
    flutter test --concurrency=1 --timeout="${timeout_seconds}s" "$file"
  local status=$?
  if [ "$status" -eq 0 ]; then
    passed=$((passed + 1))
    printf '<== PASS %s (exit 0)\n' "$file"
  else
    failed=$((failed + 1))
    failed_files+=("$file:$status")
    if [ "$status" -eq 124 ] || [ "$status" -eq 137 ]; then
      timed_out=$((timed_out + 1))
      printf '<== TIMEOUT %s (exit %s)\n' "$file" "$status"
    else
      printf '<== FAIL %s (exit %s)\n' "$file" "$status"
    fi
  fi
}

if [ "$#" -gt 0 ]; then
  files=("$@")
else
  # Real-EVM tests run in the separate integration workflow and are not part
  # of the default 66-file suite; they require a live Anvil node.
  mapfile -t files < <(find test -type f -name '*_test.dart' ! -path 'test/integration/*' -print | LC_ALL=C sort)
fi

discovered=${#files[@]}
if [ "$discovered" -eq 0 ]; then
  printf 'No test files discovered; refusing to report success.\n' >&2
  exit 1
fi

for file in "${files[@]}"; do
  if [ ! -f "$file" ]; then
    printf 'Required test file is missing: %s\n' "$file" >&2
    exit 1
  fi
done

for file in "${files[@]}"; do
  elapsed=$(( $(date +%s) - started_epoch ))
  if [ "$elapsed" -ge "$GLOBAL_TIMEOUT_SECONDS" ]; then
    failed=$((failed + 1))
    timed_out=$((timed_out + 1))
    failed_files+=("global-watchdog:$elapsed")
    printf '\nGLOBAL TIMEOUT after %ss; remaining files were not run.\n' "$elapsed" >&2
    break
  fi
  run_one "$file"
done

elapsed=$(( $(date +%s) - started_epoch ))
skipped=$((discovered - executed))
printf '\n=== test-suite summary ===\n'
printf 'files discovered: %s\nfiles executed: %s\nfiles passed: %s\nfiles failed: %s\nfiles skipped: %s\nfiles timed out: %s\nelapsed seconds: %s\n' \
  "$discovered" "$executed" "$passed" "$failed" "$skipped" "$timed_out" "$elapsed"
if [ "$skipped" -ne 0 ]; then
  printf 'unexecuted files (global watchdog): %s\n' "${files[*]:$executed}" >&2
  exit 1
fi
if [ "${#failed_files[@]}" -gt 0 ]; then
  printf 'non-passing files: %s\n' "${failed_files[*]}" >&2
  exit 1
fi
exit 0
