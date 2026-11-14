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
# Needs git, node/npm, uv and network access. Progress goes to stderr.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="$(cd "$ROOT_DIR" && python3 -I scripts/hermes_contracts.py resolve)"
CACHE="${HERMES_AGENT_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/hermes-agent}"
DIR="$CACHE/$REF"
DONE="$DIR/.hermes-app-install-complete"

# One installer per revision at a time; a second one waits, then reuses it.
mkdir -p "$CACHE"
exec 9>"$CACHE/.$REF.lock"
if command -v flock >/dev/null; then flock 9; fi

if [[ -f "$DONE" && -x "$DIR/.venv/bin/hermes" && -f "$DIR/hermes_cli/web_dist/index.html" ]]; then
  echo "$DIR"
  exit 0
fi

for tool in git npm uv; do
  command -v "$tool" >/dev/null || {
    echo "install-hermes: $tool not found on PATH" >&2
    exit 1
  }
done

# A half-finished install is not trusted: start over.
rm -rf "$DIR"
mkdir -p "$DIR"
echo "install-hermes: fetching hermes-agent $REF" >&2
# Prefer the tarball, as CI does; some proxies refuse codeload.github.com, and
# git over https then still works.
if ! curl -fsSL --retry 3 "https://codeload.github.com/NousResearch/hermes-agent/tar.gz/$REF" 2>/dev/null |
  tar xz -C "$DIR" --strip-components=1 2>/dev/null; then
  rm -rf "$DIR" && mkdir -p "$DIR"
  git -C "$DIR" init -q
  git -C "$DIR" fetch -q --depth 1 https://github.com/NousResearch/hermes-agent "$REF"
  git -C "$DIR" checkout -q FETCH_HEAD
fi

# The dashboard serves a Vite build that is not in the source tree, and its
# session token is injected into the built index.html.
echo "install-hermes: building the web UI" >&2
(cd "$DIR" && npm ci --workspace web --include=dev --no-audit --no-fund >&2 && npm run build --workspace web >&2)

echo "install-hermes: installing into $DIR/.venv (Python 3.14)" >&2
UV_NO_CONFIG=1 uv venv -q --python 3.14 "$DIR/.venv" >&2
UV_NO_CONFIG=1 uv pip install -q --python "$DIR/.venv/bin/python" -e "${DIR}[mcp]" >&2

touch "$DONE"
echo "$DIR"
