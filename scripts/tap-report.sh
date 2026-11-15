#!/usr/bin/env bash
# Measures tap targets: the workflow screens first (they append to
# build/tap_targets/workflows/), then the Widgetbook catalog, which writes
# build/tap_targets/report.json and prints the totals. Reports only, never
# fails on a violation. WORKFLOWS=0 skips the workflow screens. A failing
# workflow test does not stop the catalog report; the script then exits
# non-zero at the end, because the screens of that test may be missing.
set -euo pipefail
cd "$(dirname "$0")/.."
export HERMES_TAP_REPORT=1
rm -rf build/tap_targets
workflows_failed=0
if [ "${WORKFLOWS:-1}" != 0 ]; then
  flutter test test/workflows || workflows_failed=$?
  if [ "$workflows_failed" != 0 ]; then
    echo "WARNING: some workflow tests failed (exit $workflows_failed); their screens may be missing from this report." >&2
  fi
fi
flutter test test/tap_targets/tap_target_report.dart
if [ "$workflows_failed" != 0 ]; then
  echo "WARNING: some workflow tests failed; the report above is incomplete." >&2
  exit 1
fi
