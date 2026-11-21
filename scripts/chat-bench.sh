#!/usr/bin/env bash
# Runs the chat rendering benchmark N times and aggregates the runs:
#   scripts/chat-bench.sh [--mode test|profile] [runs] [scenario-filter]
#
# --mode test     (default) `flutter test benchmark/chat_render_bench_test.dart`:
#                 debug JIT on the test binding, fake clock, ~18 min a run.
# --mode profile  `flutter drive --profile -d linux` under Xvfb: the real
#                 Linux app in AOT with no debug asserts, measured with the
#                 engine's FrameTiming (buildDuration = UI thread). Needs the
#                 Linux build packages (clang cmake ninja-build pkg-config
#                 libgtk-3-dev libsecret-1-dev libjsoncpp-dev libmpv-dev,
#                 xvfb). Set CHAT_BENCH_DYNAMIC_MIMALLOC=1 where GitHub
#                 downloads are blocked (apt install libmimalloc-dev): it
#                 links mimalloc dynamically for this run by patching
#                 linux/CMakeLists.txt and restoring it, and removing
#                 build/linux, on exit.
#
# `runs` is a positive integer (default 5; anything else exits 64); the filter is a regular expression matched against the
# scenario ids (s1-markdown, s2-code-blocks, s2b-fences-100/300/1000,
# s3-tool-calls, s4a-tables, s4b-lists, s5-open-2000, s6-typing,
# s7-mac-sidebar). Results land in build/chat_bench/<mode>/ (override with
# CHAT_BENCH_DIR): run-<n>.json per run and aggregate.json. Runs go one after
# the other, so they do not compete for CPU; keep the machine otherwise idle.
# Profile mode takes about 13 min a run. Measure one benchmark at a time on a
# machine: wrap runs in `flock -o <lockfile> scripts/chat-bench.sh ...`.
set -euo pipefail

cd "$(dirname "$0")/.."
mode=test
if [ "${1:-}" = "--mode" ]; then
  mode=${2:?--mode needs test or profile}
  shift 2
fi
case "$mode" in test | profile) ;; *) echo "unknown mode: $mode" >&2; exit 64 ;; esac
runs=${1:-5}
case "$runs" in
  '' | *[!0-9]* | 0 | 0[0-9]*)
    echo "usage: $0 [--mode test|profile] [runs] [scenario-filter]" >&2
    echo "runs must be a positive integer, got: $runs" >&2
    exit 64
    ;;
esac
filter=${2:-}
dir=${CHAT_BENCH_DIR:-build/chat_bench}/$mode
mkdir -p "$dir"
rm -f "$dir"/run-*.json "$dir"/aggregate.json

if [ "$mode" = profile ] && [ -n "${CHAT_BENCH_DYNAMIC_MIMALLOC:-}" ]; then
  if ! git diff --quiet -- linux/CMakeLists.txt; then
    echo "linux/CMakeLists.txt has local changes; refusing to patch it" >&2
    exit 1
  fi
  # The forced cache entry lives on in build/linux/CMakeCache.txt, so the
  # build directory goes with the patch, also on Ctrl-C, kill or a failed run.
  restore_cmake() {
    git checkout -- linux/CMakeLists.txt
    rm -rf build/linux
  }
  trap restore_cmake EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  sed -i '/^add_subdirectory(${FLUTTER_MANAGED_DIR})/i set(MIMALLOC_USE_STATIC_LIBS OFF CACHE BOOL "dynamic mimalloc" FORCE)' linux/CMakeLists.txt
  # A build directory configured without it keeps the old install prefix.
  rm -rf build/linux
fi

run_once() {
  if [ "$mode" = test ]; then
    flutter test benchmark/chat_render_bench_test.dart -j 1 --concurrency=1 \
      --reporter=expanded
  else
    xvfb-run -a -s "-screen 0 1280x800x24" \
      flutter drive --profile -d linux \
      --driver=benchmark/profile/driver.dart \
      --target=benchmark/profile/chat_render_profile.dart
  fi
}

files=()
for i in $(seq 1 "$runs"); do
  start=$(date +%s)
  echo "== $mode run $i of $runs"
  # The exit status of the benchmark itself, not of tee or grep: a failing
  # scenario must stop the script before it aggregates a partial run.
  set +e
  CHAT_BENCH_OUT="$dir/run-$i.json" CHAT_BENCH_FILTER="$filter" run_once 2>&1 |
    tee "$dir/run-$i.log" |
    grep -E '^(  s[0-9]|scenario|s[0-9]|.*(Some tests failed|\[E\]|Bad state))'
  status=${PIPESTATUS[0]}
  set -e
  if [ "$status" -ne 0 ]; then
    # The test runner's tearDownAll writes the results of a failed run too.
    rm -f "$dir/run-$i.json"
    echo "run $i failed with exit status $status (see $dir/run-$i.log)" >&2
    exit "$status"
  fi
  [ -f "$dir/run-$i.json" ] || { echo "run $i produced no results (see $dir/run-$i.log)" >&2; exit 1; }
  files+=("$dir/run-$i.json")
  echo "run $i took $(($(date +%s) - start)) s"
done

python3 -I scripts/chat_bench_aggregate.py "$dir/aggregate.json" "${files[@]}"
echo "wrote $dir/aggregate.json"
