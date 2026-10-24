#!/usr/bin/env bash
# Prints the --dart-define flags of a release build, one per line:
#
#   mapfile -t defines < <(scripts/release-dart-defines.sh 0.1.9)
#   flutter build linux --release "${defines[@]}"
#
# Telemetry is on only when OTLP_INGEST_URL and OTLP_INGEST_KEY are both set;
# otherwise nothing is printed and the app builds with telemetry off. The
# fastlane lanes have their own copy (telemetry_dart_defines in the Fastfile).
set -euo pipefail

VERSION="${1:?usage: release-dart-defines.sh <version>}"
url="${OTLP_INGEST_URL:-}"
key="${OTLP_INGEST_KEY:-}"

[ -n "$url" ] && [ -n "$key" ] || exit 0

# Mirrors Telemetry.isExportableEndpoint. The app drops any other endpoint at
# start-up, so the build would ship with telemetry off. Never print the value:
# it can carry credentials.
shopt -s nocasematch
if ! [[ "$url" =~ ^https:// ]] \
  && ! [[ "$url" =~ ^http://(localhost|127\.0\.0\.1|\[::1\])([:/?#]|$) ]]; then
  echo "::error::OTLP_INGEST_URL must start with https:// (http:// is only allowed for localhost, 127.0.0.1 and [::1]); the app would drop the endpoint and export nothing." >&2
  exit 1
fi

printf '%s\n' \
  "--dart-define=OTEL_EXPORTER_OTLP_ENDPOINT=$url" \
  "--dart-define=OTEL_EXPORTER_OTLP_HEADERS=authorization=Bearer $key,x-tenant-id=homelab,x-dataset-id=apps" \
  "--dart-define=OTEL_SERVICE_NAME=hermes-app" \
  "--dart-define=OTEL_SERVICE_VERSION=$VERSION"
