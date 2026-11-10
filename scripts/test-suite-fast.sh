#!/usr/bin/env bash
# Fast full-suite runner for a 2-core release machine.
#
# `scripts/test-suite.sh` starts one `flutter test` process per file so a leak
# or hang is attributed to one file. That is the strongest gate, but process
# startup dominates on 2 cores. This runner groups the stateless files in one
# process with concurrency 1, then runs the files that own real filesystem or
# device-secret state each in their own process (the same isolation the
# canonical script gives them).
set -euo pipefail
cd "$(dirname "$0")/.."
umask 0077

readonly -a stateful=(
  test/backup_restore_e2e_test.dart
  test/drawer_secret_test.dart
  test/erase_flow_test.dart
  test/filesystem_security_test.dart
  test/log_canary_test.dart
  test/rollback_injection_test.dart
  test/vault_import_rollback_kdf_test.dart
  test/vault_multi_wallet_test.dart
  test/vault_rename_test.dart
)

is_stateful() {
  local candidate="$1"
  local item
  for item in "${stateful[@]}"; do
    [ "$candidate" = "$item" ] && return 0
  done
  return 1
}

mapfile -t all < <(
  find test -type f -name '*_test.dart' ! -path 'test/integration/*' \
    -print | LC_ALL=C sort
)
grouped=()
for file in "${all[@]}"; do
  if is_stateful "$file"; then
    continue
  fi
  grouped+=("$file")
done

echo "fast suite: ${#grouped[@]} grouped files, ${#stateful[@]} isolated files"
flutter test --concurrency=1 --timeout=900s "${grouped[@]}"

for file in "${stateful[@]}"; do
  echo "==> isolated $file"
  flutter test --concurrency=1 --timeout=900s "$file"
done

echo "fast suite: PASS (${#all[@]} files)"
