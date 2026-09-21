#!/usr/bin/env bash
# Builds the Widgetbook catalog (widgetbook/) for the web into build/web.
# The app has no web platform, so the page it needs is copied to web/ for the
# length of the build and removed again. With a web/ folder present Flutter
# also edits analysis_options.yaml; the script puts that file back.
#
#   BASE_HREF=/hermes-app/ scripts/build-widgetbook.sh   # for GitHub Pages
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -e web ]; then
  echo "web/ already exists; remove it first (the app has no web platform)" >&2
  exit 1
fi
backup="$(mktemp)"
cp analysis_options.yaml "$backup"
trap 'rm -rf web; cp "$backup" analysis_options.yaml; rm -f "$backup"' EXIT

rm -rf build/web
mkdir web
cp widgetbook/web/index.html web/index.html
cp design/icon.svg web/favicon.svg

flutter build web -t widgetbook/main.dart --release --no-wasm-dry-run \
  --base-href "${BASE_HREF:-/}"
