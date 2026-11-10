#!/usr/bin/env bash
# Fast full-suite runner for a 2-core release machine.
#
# `scripts/test-suite.sh` starts one `flutter test` process per file so a leak
# or hang is attributed to one file. That is the strongest gate, but process
# startup dominates on 2 cores. This runner compiles the same non-integration
# files in one process with concurrency 1. It is still serial at the test level
# (the KDF suites never overlap) and it runs every default test file.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 0077

mapfile -t files < <(
  find test -type f -name '*_test.dart' ! -path 'test/integration/*' \
    -print | LC_ALL=C sort
)
echo "fast suite: ${#files[@]} files, concurrency 1, 900s per test"
flutter test --concurrency=1 --timeout=900s "${files[@]}"
