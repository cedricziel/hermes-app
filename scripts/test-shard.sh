#!/usr/bin/env bash
# Runs one shard of the Flutter tests: scripts/test-shard.sh <index> <total>.
#
# Shards split by file, not with `flutter test --total-shards`, which still
# compiles every test file in every shard. Shard 0 runs only the Widgetbook
# test, as slow as a whole shard of the rest; the other files are dealt
# round-robin over shards 1 to total-1. Extra arguments go to `flutter test`.
#
# The Widgetbook test is about 17,500 cases and its process grows with each
# one (past 11 GB before the end), so shard 0 runs it in CATALOG_PARTS
# processes (default 6), one after the other, split with `--total-shards`.
# Every part runs even after one failed. `coverage/lcov.info` and a
# `--file-reporter json:<path>` report end up holding all parts.
# With `--name` or `--plain-name` the file runs in one process instead.
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

if [ "$index" -eq 0 ]; then
  parts=${CATALOG_PARTS:-6}
  case "$parts" in
    '' | 0* | *[!0-9]*)
      echo "CATALOG_PARTS must be a whole number of 1 or more, got '$parts'" >&2
      exit 64
      ;;
  esac

  coverage=0
  report=""
  previous=""
  filtered=0
  unsupported=""
  for arg in "$@"; do
    case "$arg" in
      --coverage) coverage=1 ;;
      --file-reporter=json:*) report=${arg#--file-reporter=json:} ;;
      json:*) if [ "$previous" = --file-reporter ]; then report=${arg#json:}; fi ;;
      --name | --name=* | --plain-name | --plain-name=*) filtered=1 ;;
      --coverage-path | --coverage-path=* | --branch-coverage | --merge-coverage)
        unsupported=${arg%%=*}
        ;;
    esac
    previous=$arg
  done

  # A run narrowed to some names is small, and most parts of a split would
  # select no test, which `flutter test` reports as a failure. One process,
  # and its exit code: a name that matches nothing still fails.
  if [ "$filtered" -eq 1 ]; then
    exec flutter test "$@" "$catalog"
  fi

  # Each part writes `coverage/lcov.info`; only that file is carried over.
  if [ -n "$unsupported" ]; then
    echo "$unsupported is not supported with the catalog parts; use --coverage" >&2
    exit 64
  fi

  status=0
  lcovs=()
  reports=()
  for ((part = 0; part < parts; part++)); do
    echo "Catalog part $((part + 1)) of $parts"
    rm -f coverage/lcov.info
    flutter test "$@" --total-shards "$parts" --shard-index "$part" "$catalog" || status=$?
    if [ "$coverage" -eq 1 ] && [ -f coverage/lcov.info ]; then
      mv coverage/lcov.info "coverage/lcov.part$part.info"
      lcovs+=("coverage/lcov.part$part.info")
    fi
    if [ -n "$report" ] && [ -f "$report" ]; then
      mv "$report" "$report.part$part"
      reports+=("$report.part$part")
    fi
  done

  # One record per source file and part: `scripts/coverage_summary.py` adds
  # the hits of records that name the same file.
  if [ ${#lcovs[@]} -gt 0 ]; then
    cat "${lcovs[@]}" > coverage/lcov.info
    rm -f "${lcovs[@]}"
  fi
  if [ ${#reports[@]} -gt 0 ]; then
    python3 scripts/merge_test_reports.py "$report" "${reports[@]}"
    rm -f "${reports[@]}"
  fi
  exit "$status"
fi

files=()
while IFS= read -r file; do
  files+=("$file")
done < <(find test -name '*_test.dart' ! -path "$catalog" | LC_ALL=C sort |
  awk -v n=$((total - 1)) -v i=$((index - 1)) '(NR - 1) % n == i')

if [ ${#files[@]} -eq 0 ]; then
  echo "shard $index of $total has no test files" >&2
  exit 1
fi

exec flutter test "$@" "${files[@]}"
