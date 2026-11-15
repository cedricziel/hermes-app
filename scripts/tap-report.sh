#!/usr/bin/env bash
# Measures tap targets: the workflow screens first (they append to
# build/tap_targets/workflows/), then the Widgetbook catalog, which writes
# build/tap_targets/report.json and prints the totals. Reports only, never
# fails on a violation. WORKFLOWS=0 skips the workflow screens.
set -euo pipefail
cd "$(dirname "$0")/.."
export HERMES_TAP_REPORT=1
rm -rf build/tap_targets
if [ "${WORKFLOWS:-1}" != 0 ]; then
  flutter test test/workflows
fi
flutter test test/tap_targets/tap_target_report.dart
