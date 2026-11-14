#!/usr/bin/env bash
# Installs Hermes Agent at the revision this checkout's API contracts are
# pinned to (openapi/HERMES_REF and openrpc/HERMES_REF), the way
# .github/workflows/real-backend-contract.yml does, and prints the install
# directory. Reuses a finished install.
#
#   DIR=$(scripts/install-hermes.sh)
#   PATH="$DIR/.venv/bin:$PATH" HERMES_WEB_DIST="$DIR/hermes_cli/web_dist" ...
#
# The install lives in ${HERMES_AGENT_CACHE:-~/.cache/hermes-agent}/<sha>,
# outside the working tree, and holds code only: no HERMES_HOME, no state.
# Older revisions there can be deleted by hand. Needs git, node/npm, uv,
# flock and network access. Progress goes to stderr.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="$(cd "$ROOT_DIR" && python3 -I scripts/hermes_contracts.py resolve)"
[[ "$REF" =~ ^[0-9a-f]{40}$ ]] || {
  echo "install-hermes: pinned revision is not a commit id: '$REF'" >&2
  exit 1
}
CACHE="${HERMES_AGENT_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/hermes-agent}"
[[ -n "$CACHE" && "$CACHE" != / ]] || {
  echo "install-hermes: refusing cache root '$CACHE'" >&2
  exit 1
}
mkdir -p "$CACHE"
CACHE="$(cd "$CACHE" && pwd -P)"
DIR="$CACHE/$REF"
DONE="$DIR/.hermes-app-install-complete"

for tool in git npm uv flock; do
  command -v "$tool" >/dev/null || {
    echo "install-hermes: $tool not found on PATH" >&2
    exit 1
  }
done

# One installer per revision at a time; a second one waits, then reuses it.
exec 9>"$CACHE/.$REF.lock"
flock 9

if [[ -f "$DONE" && -x "$DIR/.venv/bin/hermes" && -f "$DIR/hermes_cli/web_dist/index.html" ]]; then
  echo "$DIR"
  exit 0
fi

# A half-finished install is not trusted: start over. $DIR is <cache>/<sha>.
rm -rf "${CACHE:?}/${REF:?}"
mkdir -p "$DIR"
# Fetched by commit id, so git checks the tree against the pinned revision.
echo "install-hermes: fetching hermes-agent $REF" >&2
git -C "$DIR" init -q
git -C "$DIR" fetch -q --depth 1 https://github.com/NousResearch/hermes-agent "$REF"
git -C "$DIR" checkout -q FETCH_HEAD
[[ "$(git -C "$DIR" rev-parse HEAD)" == "$REF" ]] || {
  echo "install-hermes: checked out $(git -C "$DIR" rev-parse HEAD), not $REF" >&2
  exit 1
}

# The dashboard serves a Vite build that is not in the source tree, and its
# session token is injected into the built index.html. npm ci runs the
# packages' install scripts, as it does in CI.
echo "install-hermes: building the web UI" >&2
(cd "$DIR" && npm ci --workspace web --include=dev --no-audit --no-fund >&2 && npm run build --workspace web >&2)
# Only the built web_dist is needed from here on.
rm -rf "$DIR/node_modules" "$DIR/web/node_modules"

echo "install-hermes: installing into $DIR/.venv (Python 3.14)" >&2
UV_NO_CONFIG=1 uv venv -q --python 3.14 "$DIR/.venv" >&2
UV_NO_CONFIG=1 uv pip install -q --python "$DIR/.venv/bin/python" -e "${DIR}[mcp]" >&2

touch "$DONE"
echo "$DIR"
