#!/usr/bin/env bash
# Runs one shard of the Flutter tests: scripts/test-shard.sh <index> <total> [flutter test args].
#
# Shards split by file, not with `flutter test --total-shards`, which still
# compiles every test file in every shard. The files are assigned by measured
# duration (tool/shard_weights.dart, weights in test/shard_weights.json): the
# Widgetbook test is pinned to shard 0, which runs it alone first (it runs out
# of memory when compiled with others), then the other files assigned to it in
# a second `flutter test`. The second run writes lcov-extra and "-extra"
# report files, so nothing is overwritten; its coverage is appended to
# coverage/lcov.info (coverage_summary.py sums duplicate records).
#
# TEST_SHARD_LIST=1 prints the shard's files, one per line, and runs nothing.
set -euo pipefail

if [ $# -lt 2 ] || [ "$2" -lt 2 ] || [ "$1" -ge "$2" ]; then
  echo "usage: $0 <index> <total, at least 2> [flutter test args]" >&2
  exit 64
fi
index=$1
total=$2
shift 2

cd "$(dirname "$0")/.."
catalog=test/widgetbook_test.dart

# Captured first so that `set -e` sees a failing dart (a process substitution
# would hide its status and run a truncated list). Plain `dart <file>`: no build
# hooks, no network.
list=$(dart tool/shard_weights.dart assign "$index" "$total")
files=()
if [ -n "$list" ]; then
  while IFS= read -r file; do files+=("$file"); done <<<"$list"
fi

if [ "${TEST_SHARD_LIST:-}" = 1 ]; then
  if [ "$index" -eq 0 ]; then echo "$catalog"; fi
  if [ ${#files[@]} -gt 0 ]; then printf '%s\n' "${files[@]}"; fi
  exit 0
fi

if [ "$index" -ne 0 ]; then
  if [ ${#files[@]} -eq 0 ]; then
    echo "shard $index of $total has no test files" >&2
    exit 1
  fi
  exec flutter test "$@" "${files[@]}"
fi

for arg in "$@"; do
  case "$arg" in
    --coverage-path | --coverage-path=*)
      echo "$0: --coverage-path is set by this script on shard 0" >&2
      exit 64
      ;;
  esac
done
case " $* " in *" --coverage "*) rm -f coverage/lcov.info ;; esac

status=0
flutter test "$@" "$catalog" || status=$?

if [ ${#files[@]} -gt 0 ]; then
  extra=()
  coverage=0
  for arg in "$@"; do
    case "$arg" in
      --coverage) coverage=1; extra+=("$arg") ;;
      json:*.json) extra+=("${arg%.json}-extra.json") ;;
      --file-reporter=json:*.json) extra+=("${arg%.json}-extra.json") ;;
      *) extra+=("$arg") ;;
    esac
  done
  if [ "$coverage" -eq 1 ]; then
    if [ -f coverage/lcov.info ]; then
      mv coverage/lcov.info coverage/lcov-catalog.info
    fi
    extra+=(--coverage-path coverage/lcov-extra.info)
  fi
  flutter test ${extra[@]+"${extra[@]}"} "${files[@]}" || status=$?
  if [ "$coverage" -eq 1 ]; then
    cat coverage/lcov-catalog.info coverage/lcov-extra.info \
      >coverage/lcov.info 2>/dev/null || true
    rm -f coverage/lcov-catalog.info coverage/lcov-extra.info
  fi
fi
exit "$status"
