#!/usr/bin/env bash
# Copies Hermes' generated gateway contract (the /api/ws JSON-RPC protocol)
# into openrpc/, from a hermes-agent commit, branch or tag (default: main).
#
#   scripts/fetch_gateway_contract.sh [ref]
#
# Requires: gh (authenticated) and python3.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="${1:-main}"
REPO="NousResearch/hermes-agent"
SRC="apps/shared/src/gateway-contract.openrpc.json"
OUT="$ROOT_DIR/openrpc/hermes-gateway.openrpc.json"

SHA="$(gh api "repos/$REPO/commits/$REF" --jq .sha)"
echo "==> $REPO@$SHA"
gh api -H "Accept: application/vnd.github.raw" \
  "repos/$REPO/contents/$SRC?ref=$SHA" >"$OUT.tmp"
python3 -I -c 'import json, sys; json.load(open(sys.argv[1]))' "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
echo "$SHA" >"$ROOT_DIR/openrpc/HERMES_REF"
echo "==> Wrote openrpc/hermes-gateway.openrpc.json and openrpc/HERMES_REF"
