---
name: verify-in-app
description: Use when a change to hermes-app should be checked in the running app before calling it done — UI, layout, connection/auth or API behaviour — or when asked to run the app, take a screenshot, or try it against a real Hermes Agent backend.
---

# Verify in the running app

Prove a change works by looking at the real app talking to a real, throwaway
Hermes Agent backend. Tests and `flutter analyze` come first; this is the
check that a screen actually looks and behaves right. For UI work this comes
after the widget is right in the Widgetbook catalog (`component-catalog`
skill), not instead of it.

Safe with many agents at once: every command keeps its state in this
checkout's `.dart_tool/hermes-dev/`, the backend gets an OS-assigned port and
its own `HERMES_HOME`, and the app is told its server by a build flag.

## The loop

1. `dart format . && flutter analyze && flutter test`. Fix before going on.
   Analyze and test print a long dependency-update block; read the last lines.
2. `scripts/dev-backend.sh start`. Prints `ready: <url>`; needs `hermes` on
   PATH. Run `command -v hermes` first: if it is missing, do the install in
   "Hermes Agent setup" below (about two minutes) before anything else. Don't
   conclude the backend can't be run.
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

- Buttons and tabs can be pressed by name, and clicks and keys can be sent
  (see "Driving the window" below). Test input in widget tests first and use
  this to confirm.
- Threads, profiles, skills, plugins, MCP servers and Kanban come from the
  real backend; a fresh home has none of them, so seed some (see below). Mock
  chat data (`lib/src/chat/mock_chat_data.dart`) is only a fallback when the
  app has no repository.
- A fresh backend home has no model keys, so no real replies, and the
  loopback dashboard needs no sign-in, so login isn't exercised.
- Real replies without an API key: point the throwaway home at a local
  Ollama (see "A local model" below).

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

## Driving the window

Try the accessibility tree first: it presses buttons, tabs, list rows and
dialog actions by name, without moving the pointer or taking focus, so it
works while the user keeps using the machine. Fall back to the mouse and
keyboard below for text entry, drags and native dialogs.

### Through the accessibility tree

`scripts/ax.swift` reads and presses Flutter's semantics through the macOS
Accessibility API. It needs Accessibility permission for the terminal.

```bash
xcrun swiftc -O scripts/ax.swift -o .dart_tool/hermes-dev/ax   # once
A=.dart_tool/hermes-dev/ax
PID=$(pgrep -f "$PWD/build/macos/.*Hermes.app/Contents/MacOS" | head -1)
$A $PID wake              # always first
$A $PID texts             # what is on screen, with roles and frames
$A $PID press Kanban      # first pressable element whose name contains the text
screencapture -x -o -l "$($A $PID wid)" /tmp/shot.png
```

- Flutter builds its tree only after an accessibility client asks, and the
  content appears on a later request. Until then only the window frame and
  menus show up. `wake` asks until the content is there.
- A name can span lines ("Kanban", then "Tab 2 of 3"). `texts` prints line
  breaks as spaces, so press with one line of it.
- Hit-testing a point returns the whole window. Find elements by name.
- Setting a text field's value is accepted and ignored. Use `focus <n>` and
  then `type` (real key events, which bring the app forward), then `key 36`
  for Return.
- `screencapture -l <window id>` captured each change made this way while the
  window sat behind other apps. After a hot reload, use
  `dev-app.sh screenshot` instead (see Gotchas).
- `texts` doubles as an accessibility check: controls that read as
  `AXStaticText` or have no name are what VoiceOver users get too.
- The installed app has the same process name. Take the pid of your build,
  never the user's app, unless they asked for it.

### With the mouse and keyboard

Worked for the attach menu, the native file dialog, paste and a real drag and
drop. It needs Accessibility permission for the terminal, and it briefly
moves the real mouse pointer, so tell the user first if they are working.

- Screenshot pixels are twice the window's points, and the `screenshot`
  output is scaled again to 2000 px wide. Get the window origin and size in
  points with
  `osascript -e 'tell application "System Events" to tell process "<PRODUCT_NAME>" to get {position, size} of window 1'`
  and convert: `x = shot_x / (2000 / width)`, `y = origin_y + shot_y / (2000 / width)`.
- Keys: `osascript -e 'tell application "System Events" to keystroke "v" using {command down}'`.
  In the macOS open dialog, Cmd+Shift+G, type a path, Return, Return picks it.
- Clipboard: `osascript -e 'set the clipboard to (POSIX file "/tmp/x.txt")'`,
  `set the clipboard to "text"`, or
  `set the clipboard to (read (POSIX file "/tmp/x.png") as «class PNGf»)`.
- Mouse: System Events `click at` does nothing in a Flutter view. Post real
  events instead: compile a small program with `xcrun swiftc` that sends
  `CGEvent` mouse moved, down and up (and `leftMouseDragged` steps for a
  drag) with `.post(tap: .cghidEventTap)`, then restore the pointer with
  `CGWarpMouseCursorPosition`. For a drag, hold the button over the target
  for a second before releasing, so a screenshot can catch the drop hint.
- `screencapture -x out.png` captures the whole screen and works without the
  Screen Recording problem noted below; use it to find a Finder window to
  drag from (`open` a directory of throwaway files, or script Finder to
  place its window over an empty part of the app).
- Focus the app by pid, not by name: an installed Hermes app has the same
  process name, so `set frontmost of (first process whose name is "Hermes")`
  can raise the user's own window over yours and the clicks land in it. Take
  the pid from `pgrep -fl "<repo>/build/macos/.*Hermes.app"` and use
  `whose unix id is <pid>`. If clicks seem to do nothing, take a full-screen
  `screencapture -x` to see which window is on top.
- The `screenshot` command brings the app to the front and hands focus back,
  so key presses sent right after it can land in the wrong app. Send them
  after focusing the app (`set frontmost to true`).

## When the screenshot can't be taken

Without Screen Recording (and Accessibility) permission, the running app can
still be inspected through its Dart VM service: `dev-app.sh logs` prints the
`ws://127.0.0.1:<port>/<token>=/ws` address. Over that socket, `getVM` gives
the isolate id and `ext.flutter.debugDumpApp` returns the live widget tree as
text: grep it for keys and `Text("…")` to see what a screen shows. An
`IconButton(… disabled, disabled …)` there means hover and long-press are
unset, not that the button is disabled. The semantics dump is empty unless a
screen reader is on.

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

Custom MCP servers: `GET /api/config` returns `mcp_servers` with `${VAR}` references expanded (a bearer token added
through `POST` shows in plain text there), and `GET /api/config/raw` returns the YAML as stored, where the
`${MCP_<NAME>_API_KEY}` reference stays. `PUT /api/mcp/servers` with the expanded values unchanged keeps the reference.
Seed a harmless command server with `{"name":"x","command":"true"}`; nothing starts it.

MCP catalog and sign-in: `GET /api/mcp/catalog` lists about 65 approved entries; `POST /api/mcp/catalog/install`
with `{"name":"context7","enable":true}` installs one that needs no credential and no build (config write
only). Every entry but `n8n` is a remote URL, so nothing is built. To see the sign-in waiting screen without
the internet, serve the loopback OAuth provider `_serveMinimalOAuthProvider` in
`test/real_backend_contract_test.dart` (a 401 on `/mcp` pointing at its metadata, plus dynamic client
registration; the same few lines in Python work) and add a server with `"auth":"oauth"` at its URL:
`POST /api/mcp/servers/{name}/auth` then answers a real `authorization_url`. Nothing can approve at that
provider, so the flow ends by Cancel or after Hermes' five minute timeout. A cancelled flow keeps the server's
"already in progress" slot for a moment until Hermes' worker ends, so an immediate second start answers 409.

Screens behind a tap: press your way there with `scripts/ax.swift` (see
"Through the accessibility tree"). If the control has no name, add a
temporary change that opens the screen (a post-frame callback calling the `_open…` method) or
selects a row and runs the action in `initState`, `dev-app.sh restart` (hot reload keeps `State`),
screenshot, then revert it. Check a diff before committing so none of it ships.

The Kanban tab appears only because the backend lists the bundled `kanban`
plugin (`GET /api/dashboard/plugins`); nothing needs enabling.

## Scripted tool calls

Tool-call rendering (cards, groups, approvals inside a call, diffs, stop)
needs a model that calls tools. `scripts/fake_tool_model.py` is one: a
scripted OpenAI-compatible endpoint (its docstring lists the turns). Write
this home config before `dev-backend.sh start`, run the script, and send any
prompt; "slow" in the prompt runs `sleep 60` for trying Stop.

```yaml
model:
  default: "fake-tools"
  provider: "custom"
  base_url: "http://127.0.0.1:18555/v1"
  api_key: "fake"
  context_length: 131072
```

- Its commands run on this machine: keep `SANDBOX` (default
  `/tmp/hermes-verify`) a throwaway directory holding `backup.timer` with an
  `OnCalendar=*-*-* 02:00` line and a `sandbox/` folder.
- Hermes holds `chmod -R 777` for approval only for a client that sent
  `client.capabilities` with `server_requests: true`, as the app does. A bare
  websocket script without it sees the command blocked instead.
- Hermes runs some agent-level tools (`todo_list`) without `tool.start` or
  `tool.complete`: only `tool.generating` arrives.

## On Linux (cloud containers)

The macOS loop above does not run here; build the Linux app and drive it under
Xvfb instead.

- Packages: `libgtk-3-dev libsecret-1-dev libjsoncpp-dev` (as CI), plus
  `xdotool gnome-keyring dbus-x11 lsof` and ImageMagick's `import`.
- Dart does not read `SSL_CERT_FILE`; behind a TLS-intercepting proxy
  `pub get` hangs retrying until the proxy's CA is in
  `/etc/ssl/certs/ca-certificates.crt`.
- If codeload.github.com is refused, `git archive` the pinned `HERMES_REF`
  from a clone into `$DIR` instead of the tarball in "Hermes Agent setup".
- `flutter build linux --debug --dart-define=HERMES_SERVER_URL=http://127.0.0.1:$PORT`
  with `HERMES_DEV_PORT=$PORT scripts/dev-backend.sh start`, so the URL is
  known before the build.
- `export DISPLAY=:99` in the shell first: the app, `xdotool` and `import`
  all need it.
- Run it with `Xvfb :99 -screen 0 1400x900x24 &`, then, under
  `dbus-run-session`, unlock a keyring (`echo -n x | gnome-keyring-daemon
  --unlock --components=secrets`) and start
  `build/linux/x64/debug/bundle/hermes_app`. Without a
  system bus the `dbus` package logs an unhandled `SocketException` at start;
  the app works regardless.
- Drive with `xdotool mousemove X Y click 1`, `xdotool type`, `xdotool key
  Return`; screenshot with `import -window root -crop 1280x720+0+0 out.png`
  (the window opens at 1280x720 at the origin).
- Never `pkill -f` a pattern that appears in your own command line: it kills
  the shell running it. Kill by `pgrep -x hermes_app` and the like.

## A local model

For replies, model switching or anything that needs a turn to run, give the
backend a local Ollama model. `ollama list` shows what is pulled; `qwen3:0.6b`
and `qwen3:1.7b` are small and give two models to switch between. Write
`.dart_tool/hermes-dev/home/config.yaml` before `dev-backend.sh start`:

```yaml
model:
  default: "qwen3:1.7b"
  provider: "local-ollama"
  ollama_num_ctx: 65536
providers:
  local-ollama:
    name: "Local Ollama"
    base_url: "http://127.0.0.1:11434/v1"
    api_key: "ollama"
```

- Hermes refuses a model whose context is under 64K ("has a context window
  of 40,960 tokens"). `ollama_num_ctx` lifts it; without it every turn fails.
- `provider: "custom"` with `base_url` (the unnamed form Hermes documents)
  also works, and is the case to test for provider handling: its slug is
  `custom`, and `/model <m> --provider custom` is refused without `--session`.
- `ollama ps` after a turn shows which model actually answered.
- The backend inherits this shell's environment, so providers with keys or
  tokens here (Anthropic, Copilot) show as signed in. Pick only the local
  models, or a turn is billed to a real account.
- To drive the chat without the UI, speak the gateway's JSON-RPC directly
  from the Hermes venv's Python (`websockets` is installed):
  `ws://<host>/api/ws?token=<session token>`, then `session.create`,
  `prompt.submit`, and read `event` messages until `message.complete`.

## Hermes Agent setup

`hermes` must be on PATH (tested with v0.21.3). Nothing installs it for you,
and the machine's `python3` is usually 3.9, too old: use `python3.11` (Homebrew
has it). `uv` is often missing too, so the recipe below uses `venv` and `pip`.
It builds the version CI pins (`HERMES_REF` in
`.github/workflows/real-backend-contract.yml`) into a cache directory that
survives between sessions, and leaves your real `~/.hermes` alone. Needs Node
and network access.

```bash
REF=$(grep 'HERMES_REF:' .github/workflows/real-backend-contract.yml | awk '{print $2}')
DIR="$HOME/.cache/hermes-agent/${REF:0:7}"
if [ ! -x "$DIR/.venv/bin/hermes" ]; then
  mkdir -p "$DIR" && curl -fsSL --retry 3 "https://codeload.github.com/NousResearch/hermes-agent/tar.gz/$REF" \
    | tar xz -C "$DIR" --strip-components=1
  (cd "$DIR" && npm ci --workspace web --include=dev --no-audit --no-fund && npm run build --workspace web)
  python3.11 -m venv "$DIR/.venv" && "$DIR/.venv/bin/pip" install -q -e "${DIR}[mcp]"
fi
export PATH="$DIR/.venv/bin:$PATH" HERMES_WEB_DIST="$DIR/hermes_cli/web_dist"
scripts/dev-backend.sh start
```

Run all of it in one shell: the two `export`s must be set when
`dev-backend.sh` and `dev-app.sh` run, and they do not carry over to the next
Bash call. Once `$DIR` exists, only the `DIR=` and `export` lines are needed.

- The web build matters: the dashboard page carries the session token the app
  and the contract test read, and it is not in the source tree. Without
  `HERMES_WEB_DIST` the backend has no page.
- `[mcp]` lets the dashboard test MCP servers. In zsh write `"${DIR}[mcp]"`;
  `"$DIR[mcp]"` is read as an array subscript and pip gets an empty path.
- With `uv`, `uv venv --python 3.11` and `uv pip install -e` do the same as
  the `venv` and `pip` lines. `openapi/README.md` has a from-source install
  too.
- A newer Hermes: bump `HERMES_REF` in the workflow (the cache path follows
  it), not a floating tag.
- Its API contract is `openapi/hermes-agent.openapi.json`.
