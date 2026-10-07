#!/usr/bin/env bash
# Runs one shard of the Flutter tests: scripts/test-shard.sh <index> <total>.
#
# Shards split by file, not with `flutter test --total-shards`, which still
# compiles every test file in every shard. Shard 0 runs only the Widgetbook
# test, as slow as a whole shard of the rest; the other files are dealt
# round-robin over shards 1 to total-1. Extra arguments go to `flutter test`.
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

files=()
if [ "$index" -eq 0 ]; then
  files=("$catalog")
else
  while IFS= read -r file; do
    files+=("$file")
  done < <(find test -name '*_test.dart' ! -path "$catalog" | LC_ALL=C sort |
    awk -v n=$((total - 1)) -v i=$((index - 1)) '(NR - 1) % n == i')
fi

if [ ${#files[@]} -eq 0 ]; then
  echo "shard $index of $total has no test files" >&2
  exit 1
fi

exec flutter test "$@" "${files[@]}"
