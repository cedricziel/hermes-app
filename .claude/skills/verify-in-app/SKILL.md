---
name: verify-in-app
description: Use when a change to hermes-app should be checked in the running app before calling it done — UI, layout, connection/auth or API behaviour — or when asked to run the app, take a screenshot, or try it against a real Hermes Agent backend.
---

# Verify in the running app

Prove a change works by looking at the real app talking to a real, throwaway
Hermes Agent backend. Tests and `flutter analyze` come first; this is the
check that a screen actually looks and behaves right.

Safe with many agents at once: every command keeps its state in this
checkout's `.dart_tool/hermes-dev/`, the backend gets an OS-assigned port and
its own `HERMES_HOME`, and the app is told its server by a build flag.

## The loop

1. `dart format . && flutter analyze && flutter test`. Fix before going on.
   Analyze and test print a long dependency-update block; read the last lines.
2. `scripts/dev-backend.sh start`. Prints `ready: <url>`; needs `hermes` on PATH.
3. `scripts/dev-app.sh start`. Prints `app up against <url>` when the app is
   running, and the app window stays open. A cold first build takes minutes,
   a cached one under a minute. Don't close the window: closing it quits the app.
4. `scripts/dev-app.sh screenshot` prints the path of a PNG under
   `.dart_tool/hermes-dev/shots/`; read that file.
5. Compare with what the change was meant to do. Wrong or unclear?
   Edit, `scripts/dev-app.sh reload` (or `restart` after state/initializer
   changes), screenshot again. `scripts/dev-app.sh logs` shows Flutter errors.
6. At most 3 rounds. Then stop and report what is still off.
7. Always finish with `scripts/dev-app.sh stop` and
   `scripts/dev-backend.sh stop`, including when something failed.

Report what you saw and where the screenshots are (they are not committed).
Say plainly what you could not check.

## Rules

- Never point the app or `hermes` at the real `~/.hermes`.
- Never run `hermes dashboard --stop`: it kills every Hermes web server on the
  machine, including other sessions' and the developer's.
- Never rely on the app's saved server address. Only the
  `HERMES_SERVER_URL` build flag (set by `dev-app.sh`) is safe in parallel.

## What this can and can't show

- I can look and read logs, not click. Anything needing input is checked
  in widget tests instead.
- The chat UI runs on mock data (`lib/src/chat/mock_chat_data.dart`); the real
  backend backs the connection and status screens.
- A fresh backend home has no model keys, so no real replies, and the
  loopback dashboard needs no sign-in, so login isn't exercised.

## Gotchas

- macOS doesn't paint a covered window. `screenshot` brings the app forward
  for a moment and hands focus back; a hand-rolled capture of a background
  window shows a stale frame that makes a hot reload look like it did nothing.
- The macOS build rewrites tracked `ios/` and `macos/` Xcode/xcconfig files
  and adds `Podfile`s. Don't commit them: stage files by name, never
  `git add -A`, and `git restore` the tracked ones afterwards.
- Debug builds use bundle ID `com.cedricziel.hermesApp.dev`. Any macOS app
  extension needs a Debug ID that starts with it (`…dev.ShareExtension`), or
  the build fails with "not prefixed with the parent app's bundle identifier".
- Capturing needs Screen Recording permission for the terminal app. Without
  it `screencapture` fails with "could not create image from window" and no
  file appears. You can't grant it from the session, so use the fallback
  below rather than retrying.
- The first `screenshot` compiles `scripts/window-id.swift`, which can take
  about a minute. Run it with a generous timeout, not a short one.
- `flutter screenshot --type=skia` does not work here (Impeller), and there is
  no rasterizer type. Don't spend rounds on it.

## When the screenshot can't be taken

Render the real screen in a throwaway widget test and look at the PNG. Load
Roboto and MaterialIcons from the Flutter SDK
(`<flutter>/bin/cache/artifacts/material_fonts/`) with a `FontLoader`, wrap
the app in a `RepaintBoundary`, and write `boundary.toImage(pixelRatio: 1.5)`
to `/tmp` inside `tester.runAsync`. Drive it with `FakeHermesServer` and the
fixtures in `test/support/`. It shows layout, overflow, clipping and light or
dark themes; it does not prove the running app, so still start the app and read
`scripts/dev-app.sh logs`. Monospace text and the app bar title render as grey
boxes because those fonts aren't loaded; that is the test, not the app. Delete
the test file before committing.

Seeded data helps: an empty backend hides most of what a data screen does.
Get the session token from the page and call the routes directly:

```bash
URL=$(scripts/dev-backend.sh url)
TOK=$(curl -s $URL/ | grep -o '__HERMES_SESSION_TOKEN__="[^"]*"' | cut -d'"' -f2)
curl -s -X POST $URL/api/plugins/kanban/tasks -H "X-Hermes-Session-Token: $TOK" \
  -H 'content-type: application/json' -d '{"title":"Try it","triage":true}'
```

MCP servers: `POST /api/mcp/servers` (`{"name","url"}` or `{"name","command","args","env"}`, add
`"auth":"oauth"`) seeds the list; a test of an `auth: oauth` server without a token answers
`ok:false` with Hermes' "no cached tokens found" wording, a bogus URL answers "All connection
attempts failed". For a passing test, serve a tiny JSON-only MCP endpoint (see `_serveMinimalMcp` in
`test/real_backend_contract_test.dart`) on the loopback and point a server at it.

Screens behind a tap can't be reached by clicking (System Events clicks are refused). Add a
temporary change that opens the screen (a post-frame callback calling the `_open…` method) or
selects a row and runs the action in `initState`, `dev-app.sh restart` (hot reload keeps `State`),
screenshot, then revert it. Check a diff before committing so none of it ships.

The Kanban tab appears only because the backend lists the bundled `kanban`
plugin (`GET /api/dashboard/plugins`); nothing needs enabling.

## Hermes Agent setup

`hermes` must be on PATH (tested with v0.21.1). If missing, install Hermes
Agent from github.com/NousResearch/hermes-agent; `openapi/README.md` shows a
from-source install with `uv`. The first `dev-backend.sh start` builds the
dashboard web UI, which is slow once. Its API contract is
`openapi/hermes-agent.openapi.json`.

### Installing it without `uv`

CI pins the commit in `HERMES_REF` in `.github/workflows/real-backend-contract.yml`.
To match it in a throwaway directory, leaving your real Hermes alone:

```bash
REF=$(grep 'HERMES_REF:' .github/workflows/real-backend-contract.yml | awk '{print $2}')
mkdir -p /tmp/hermes-agent && curl -fsSL "https://codeload.github.com/NousResearch/hermes-agent/tar.gz/$REF" \
  | tar xz -C /tmp/hermes-agent --strip-components=1
cd /tmp/hermes-agent
python3.11 -m venv .venv && .venv/bin/pip install -q -e '.[mcp]'   # Python 3.11+; [mcp] lets the dashboard test MCP servers
npm ci --workspace web --include=dev --no-audit --no-fund && npm run build --workspace web
export PATH=/tmp/hermes-agent/.venv/bin:$PATH HERMES_WEB_DIST=/tmp/hermes-agent/hermes_cli/web_dist
```

The web build matters: the dashboard page carries the session token the app
and the contract test read, and it is not in the source tree. With `uv`, the
workflow's `uv venv --python 3.11` and `uv pip install -e` do the same.
