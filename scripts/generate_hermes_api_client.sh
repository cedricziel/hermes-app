#!/usr/bin/env bash
# Regenerates packages/hermes_api from openapi/hermes-agent.openapi.json.
#
# Requires: a JDK (for the openapi-generator-cli jar, run via npx) and the
# Dart SDK (`dart` on PATH) to fetch dependencies and rebuild the
# json_serializable/copy_with_extension output that gets committed alongside
# the generated client.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC="$ROOT_DIR/openapi/hermes-agent.openapi.json"
OUT_DIR="$ROOT_DIR/packages/hermes_api"
CONFIG="$ROOT_DIR/scripts/dart-dio-config.yaml"
PATCHED_SPEC="$(mktemp -t hermes-agent-openapi-dart.XXXXXX.json)"
trap 'rm -f "$PATCHED_SPEC"' EXIT

echo "==> Patching spec for dart-dio codegen quirks"
python3 "$ROOT_DIR/scripts/patch_openapi_for_dart.py" "$SPEC" "$PATCHED_SPEC"

echo "==> Running openapi-generator-cli (dart-dio)"
rm -rf "$OUT_DIR"
npx --yes @openapitools/openapi-generator-cli generate \
  -i "$PATCHED_SPEC" \
  -g dart-dio \
  -o "$OUT_DIR" \
  -c "$CONFIG" \
  --skip-validate-spec

echo "==> Patching generated sources for dart-dio template bugs"
python3 "$ROOT_DIR/scripts/patch_generated_dart_client.py" "$OUT_DIR"

echo "==> Pinning generated package's Dart SDK constraint"
# The generator hardcodes a >=3.5.0 lower bound, whose default language
# version predates null-aware collection elements that a current
# json_serializable emits. Match the app's own SDK constraint instead.
sed -i.bak "s/sdk: '>=3.5.0 <4.0.0'/sdk: '>=3.13.0 <4.0.0'/" "$OUT_DIR/pubspec.yaml"
rm -f "$OUT_DIR/pubspec.yaml.bak"

echo "==> dart pub get"
(cd "$OUT_DIR" && dart pub get)

echo "==> Building generated sources (json_serializable, copy_with_extension)"
(cd "$OUT_DIR" && dart run build_runner build --delete-conflicting-outputs)

echo "==> dart format"
# The generator never ran a formatter over its own templated output (only
# build_runner's json_serializable step formats the .g.dart it writes), so
# do it ourselves — otherwise `dart format --set-exit-if-changed .` at the
# repo root fails on every commit that regenerates this package.
dart format "$OUT_DIR"

echo "==> dart analyze"
(cd "$OUT_DIR" && dart analyze)

echo "==> Done. Review the diff under packages/hermes_api before committing."
