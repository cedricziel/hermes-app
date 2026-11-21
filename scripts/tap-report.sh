#!/usr/bin/env bash
# Measures tap targets: the workflow screens first (twice: a default run, then
# a second with WORKFLOW_PLATFORM=macOS for a real Mac render; each writes to
# build/tap_targets/workflows/<run>/), then the Widgetbook catalog, which writes
# build/tap_targets/report.json and prints the totals. Reports only, never
# fails on a violation. WORKFLOWS=0 skips the workflow screens;
# MAC_WORKFLOWS=0 skips the macOS pass; KEEP_WORKFLOWS=1 (with WORKFLOWS=0)
# reuses those of the last run. A failing
# workflow test does not stop the catalog report; the script then exits
# non-zero at the end, because the screens of that test may be missing.
set -euo pipefail
cd "$(dirname "$0")/.."
export HERMES_TAP_REPORT=1
if [ "${KEEP_WORKFLOWS:-0}" = 1 ] && [ "${WORKFLOWS:-1}" != 0 ]; then
  echo "KEEP_WORKFLOWS=1 needs WORKFLOWS=0: rerunning the workflows would append to the kept data and count every screen twice." >&2
  exit 2
fi
if [ "${KEEP_WORKFLOWS:-0}" = 1 ]; then
  # Keep the workflow screens of an earlier run, drop the rest.
  find build/tap_targets -mindepth 1 -maxdepth 1 ! -name workflows -exec rm -rf {} + 2>/dev/null || true
else
  rm -rf build/tap_targets
fi
workflows_failed=0
if [ "${WORKFLOWS:-1}" != 0 ]; then
  flutter test test/workflows || workflows_failed=$?
  if [ "$workflows_failed" != 0 ]; then
    echo "WARNING: some workflow tests failed (exit $workflows_failed); their screens may be missing from this report." >&2
  fi
  if [ "${MAC_WORKFLOWS:-1}" != 0 ]; then
    # Tests that cannot run as macOS fail here; list them, never abort.
    mac_failed=0
    WORKFLOW_PLATFORM=macOS flutter test test/workflows || mac_failed=$?
    if [ "$mac_failed" != 0 ]; then
      echo "WARNING: some workflow tests failed under WORKFLOW_PLATFORM=macOS (exit $mac_failed); see the failures listed above. Their macOS screens may be missing." >&2
      workflows_failed=1
    fi
  fi
fi
flutter test test/tap_targets/tap_target_report.dart
if [ "$workflows_failed" != 0 ]; then
  echo "WARNING: some workflow tests failed; the report above is incomplete." >&2
  exit 1
fi
