#!/usr/bin/env bash
# Rebuilds openapi/hermes-agent.openapi.json from a hermes-agent commit,
# branch or tag (default: main): installs that Hermes into a throwaway
# virtualenv and dumps the dashboard's FastAPI schema in-process, with a
# throwaway HERMES_HOME. A tarball has no history for Hermes to take its
# version from, so the spec's info.version becomes the short commit SHA.
# Regenerate packages/hermes_api afterwards.
#
#   scripts/fetch_openapi_spec.sh [ref]
#
# Requires: gh (authenticated), curl and uv.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="${1:-main}"
REPO="NousResearch/hermes-agent"
OUT="$ROOT_DIR/openapi/hermes-agent.openapi.json"
WORK="$(mktemp -d -t hermes-openapi.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

SHA="$(gh api "repos/$REPO/commits/$REF" --jq .sha)"
echo "==> $REPO@$SHA"
mkdir -p "$WORK/src" "$WORK/home"
curl -fsSL --retry 3 --retry-all-errors "https://codeload.github.com/$REPO/tar.gz/$SHA" |
  tar xz -C "$WORK/src" --strip-components=1

echo "==> Installing Hermes into a throwaway virtualenv"
UV_NO_CONFIG=1 uv venv --quiet --python 3.14 "$WORK/venv"
UV_NO_CONFIG=1 uv pip install --quiet --python "$WORK/venv/bin/python" -e "$WORK/src"

echo "==> Dumping the schema"
(cd "$WORK" && HERMES_HOME="$WORK/home" "$WORK/venv/bin/python" -I -c '
import json, sys
import hermes_cli.web_server as ws
spec = ws.app.openapi()
if spec["info"].get("version") in (None, "", "unknown"):
    spec["info"]["version"] = sys.argv[2]
with open(sys.argv[1], "w") as f:
    json.dump(spec, f, indent=2)
' "$OUT.tmp" "${SHA:0:12}")
mv "$OUT.tmp" "$OUT"
echo "$SHA" >"$ROOT_DIR/openapi/HERMES_REF"
echo "==> Wrote openapi/hermes-agent.openapi.json and openapi/HERMES_REF"
