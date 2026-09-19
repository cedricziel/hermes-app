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
2. `scripts/dev-backend.sh start` (prints the URL; needs `hermes` on PATH).
3. `scripts/dev-app.sh start` (first build takes minutes).
4. `scripts/dev-app.sh screenshot`, then read the PNG it prints.
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
- Capturing needs Screen Recording permission for the terminal app.

## Hermes Agent setup

`hermes` must be on PATH (tested with v0.21.1). If missing, install Hermes
Agent from github.com/NousResearch/hermes-agent; `openapi/README.md` shows a
from-source install with `uv`. The first `dev-backend.sh start` builds the
dashboard web UI, which is slow once. Its API contract is
`openapi/hermes-agent.openapi.json`.
