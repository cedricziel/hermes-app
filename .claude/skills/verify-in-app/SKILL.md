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
   conclude the backend can't be run. If Hermes reports another dashboard
   already running on this host, use the isolated-mode fallback below.
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

### When another Hermes dashboard is already running

The normal `dev-backend.sh start` can exit with "Hermes dashboard already
running on this host" even though this checkout has its own `HERMES_HOME`.
Do not stop the other dashboard. Start this checkout's backend with
`--isolated` in a separate terminal; keep that terminal open:

```bash
mkdir -p .dart_tool/hermes-dev/home
HERMES_HOME="$PWD/.dart_tool/hermes-dev/home" \
  hermes dashboard --isolated --no-open --port 0
```

After it prints `HERMES_DASHBOARD_READY port=<port>`, register **that port**
for `dev-app.sh` from another terminal in the same checkout:

```bash
HERMES_TEST_PORT=55479 # replace with the port Hermes printed
printf '%s\n' "$HERMES_TEST_PORT" > .dart_tool/hermes-dev/port
lsof -tiTCP:"$HERMES_TEST_PORT" -sTCP:LISTEN | head -n1 > .dart_tool/hermes-dev/pid
scripts/dev-backend.sh status
```

Before launching the app, confirm `/api/status` reports this checkout's
`.dart_tool/hermes-dev/home` as `hermes_home`. Finish with the usual
`scripts/dev-app.sh stop` and `scripts/dev-backend.sh stop`; the latter kills
only the PID listening on the registered port. The `--isolated` fallback was
verified with Hermes on 2026-10-05. If Hermes's web UI assets are already
built, add `--skip-build` to the isolated command to avoid rebuilding them.

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

- Hermes 0.21.4 runs one dashboard per machine: with another worktree's
  backend up, `dev-backend.sh start` exits with "Hermes dashboard already
  running on this host". Start it yourself with `--isolated`
  (`HERMES_HOME=$PWD/.dart_tool/hermes-dev/home hermes dashboard --no-open
--port 0 --isolated`), then write the port from the `HERMES_DASHBOARD_READY`
  log line to `.dart_tool/hermes-dev/port` and its listening pid to `pid`, so
  `dev-backend.sh url` and `dev-app.sh` find it.
- Chats without model calls: insert rows into the throwaway home's
  `state.db` (`sessions` with `title`, `started_at`, `last_activity_at`,
  `pinned`, `profile_name`; `messages` with `session_id`, `role`, `content`,
  `timestamp`). Search indexes them by trigger. A second profile
  (`POST /api/profiles {"name": "work"}`) has its own
  `profiles/<name>/state.db`, created on its first read.
- `ax press` takes the first element whose name contains the text, so "work"
  also matches a path with "worktrees" in it. Click by the frame `texts`
  prints instead; the frames are global screen points.
- The window moves between runs; read its position before converting
  screenshot pixels to clicks.
- macOS doesn't paint a covered window. `screenshot` brings the app forward
  for a moment and hands focus back; a hand-rolled capture of a background
  window shows a stale frame that makes a hot reload look like it did nothing.
- The macOS build rewrites tracked `ios/` and `macos/` Xcode/xcconfig files.
  Don't commit them: stage files by name, never
  `git add -A`, and `git restore` the tracked ones afterwards.
- In a detached command runner, `dev-app.sh start` may print `app up` but its
  background Flutter process may exit as the command session closes. Check
  the recorded Flutter PID with `kill -0 "$(cat .dart_tool/hermes-dev/flutter.pid)"`
  before driving it. If it exited,
  keep `flutter run -d macos --dart-define=HERMES_SERVER_URL=<throwaway URL>`
  attached to a terminal session during verification.
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

When `cua_repl` is available, use it for native UI actions and screenshots.
Bind the exact app path under this checkout's
`build/macos/Build/Products/Debug/Hermes.app`; the installed app can share its
name and bundle ID. Read the accessibility tree after each action before
reusing element indices. Check that the account row shows the throwaway
server URL before interacting.

If the terminal accessibility helper reports `NOT_TRUSTED`, use `cua_repl`
instead of changing system permissions. For hot reload after an attached
runner loses stdin, use `flutter attach -d macos --debug-url=<VM service URL>`
in a persistent terminal with the same `HERMES_SERVER_URL` build flag.

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
- `screencapture -x out.png` captures the whole screen. It has worked without
  Screen Recording permission on some machines but failed on others with
  "could not create image from display" (2026-10-09); then use the VM-service
  dump below. Use it to find a Finder window to
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

To set up state the screen needs (a second profile, say), use the CLI against
the backend's own home, e.g. `HERMES_HOME="$PWD/.dart_tool/hermes-dev/home"
hermes profile create work`: the REST routes answer 401 without the session
token from the dashboard page.

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

## The watch app

The watch app has no network of its own: every request goes over
WatchConnectivity to the phone app, which may be woken in the background to
answer. To check a watch change, use a booted iPhone and Apple Watch simulator
pair (`xcrun simctl list pairs`).

- Build once with `flutter build ios --simulator --debug -d <phone udid>
--dart-define=HERMES_SERVER_URL=<dev backend url>`. The watch app is embedded
  at `build/ios/iphonesimulator/Runner.app/Watch/HermesWatch.app`. Install the
  phone app and the watch app separately with `xcrun simctl install`. The
  bundle IDs are `com.cedricziel.hermesApp` and
  `com.cedricziel.hermesApp.watchkitapp`, with no `.dev` suffix.
- To test a cold start, the case users hit most, run
  `xcrun simctl terminate` on the phone app, then `xcrun simctl launch` the
  watch app.
- The relay between the simulators is slow and lossy. A message can take a
  minute or more to arrive, and now and then one is lost and times out after
  5 minutes (`WCErrorCodeMessageReplyTimedOut`). Poll the logs instead of
  waiting a fixed time, and run a failure twice before trusting it.
- Read the relay in the unified log on each simulator:
  `xcrun simctl spawn <udid> log show --last 5m --predicate 'subsystem ==
"com.apple.wcd"' --style compact`. `responseDataSize` on the phone shows
  that an answer was sent and how big it was: an empty thread list is 15
  bytes, `{ok: false, error: unavailable}` is 24. "Firing background task
  expiration handlers" with `watch-relay` means Dart did not answer in time.
- `print` output from Dart shows up in the same log under process `Runner`.
- The phone can't be locked on a simulator, so behaviour on a locked phone,
  such as keychain access, can only be checked on a device.

## Live Activities

The macOS loop never shows them; they exist only on iOS. On an iPhone 17 Pro
simulator:

- A temporary `integration_test/` file that builds `LiveActivities` on
  `PluginLiveActivityService` and calls `begin`/`onEvent` drives the real
  ActivityKit without a backend: `flutter test integration_test/<file> -d
  <udid>`. Delete the file afterwards.
- `xcrun simctl io <udid> screenshot` does not capture the Dynamic Island,
  and the simulator can't be locked. Check the outcome in the unified log
  instead: `xcrun simctl spawn <udid> log show --last 5m --predicate
  'process == "HermesLiveActivity" OR (process == "Runner" AND eventMessage
  CONTAINS "activity")'`. "Updating activity ... to state: active" is an
  update, "Ending activity" an end, and WidgetKit's "Batch end ... success"
  from `HermesLiveActivity` a render. `Live Activity call failed` from Dart
  means a plugin call threw.
- Sending the app to the background (`xcrun simctl launch <udid>
  com.apple.Preferences`) suspends it within seconds, so Dart timers stop;
  `xcrun simctl launch <udid> com.cedricziel.hermesApp` resumes it.

## Sign-in against a real server

The loopback backend skips sign-in. To exercise it, run `flutter run -d macos
--dart-define=HERMES_SERVER_URL=<gated server>` (the App Review demo server
works; its credentials are in the `hermes-demo` app config on hive).

- macOS first shows a system consent prompt ("… möchte zum Anmelden …
  verwenden"). It is not in the app's accessibility tree, and Return only
  works while it has focus: click "Fortfahren" with a real `CGEvent` click.
- The sign-in page then opens in a Safari window (Safari's pid, not the
  app's). Fill it with `ax <safari pid> focus 0|1` and `type`, press Escape
  after each field to close the password manager's popup, then
  `press "SIGN IN"`. Never press Return there: 1Password's "Save login?"
  sheet can take it.
- A local debug build is signed ad hoc, which the data protection keychain
  refuses (`-34018`, "A required entitlement is not present"). Debug builds
  therefore keep the token in the login keychain (`TokenStore.defaultStorage`).
  If a sign-in ends with "Signed in, but this device could not save the
  sign-in.", the keychain write failed.
- Sign out at the end (account row, then "Sign out") so the demo token does
  not stay in the login keychain.

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

## A reply across a dropped socket

Check the reconnect path by cutting the app's websocket mid-reply while the
backend keeps running: the server goes on with the turn and the app has to pick
it up again. Needs a model that streams for a few seconds (see "A local model",
or the scripted one under "Scripted tool calls" with "slow" in the prompt) and
`socat`.

1. Put a forwarding proxy in front of the throwaway backend and run the app
   against the proxy, not the backend (`dev-app.sh` always uses the backend's
   own address, so start the app by hand as in "Sign-in against a real
   server"):

   ```bash
   BACKEND=$(scripts/dev-backend.sh url | sed 's|.*://||')
   socat TCP-LISTEN:18777,fork,reuseaddr TCP:$BACKEND &
   echo $! > .dart_tool/hermes-dev/proxy.pid
   flutter run -d macos --dart-define=HERMES_SERVER_URL=http://127.0.0.1:18777
   ```

2. Send a prompt that makes a long reply, such as "Count from 1 to 60, one
   number per line", and wait for the first lines to stream.
3. Drop the connections, not the server. From a second terminal (`flutter run`
   holds the first), `kill $(pgrep -P "$(cat .dart_tool/hermes-dev/proxy.pid)")`
   ends every connection the proxy holds (each `socat` child is one) and leaves the
   listener, so the app can reconnect through it. Never kill the backend or run
   `hermes dashboard --stop`.
4. The reply must finish on its own. Screenshot it: it completes once, with no
   duplicated or missing lines and no second bubble, and the thread is not
   marked failed, and the `flutter run` console shows no uncaught errors.
5. Repeat once between turns, with the reply already finished: nothing should
   appear or repeat.
6. Stop the proxy (`kill "$(cat .dart_tool/hermes-dev/proxy.pid)"`) with the app and the backend.

If a drop loses or repeats text, reproduce it first in
`test/gateway/transport_reconnect_test.dart`, which drives the same path with a
fake gateway.

## Exported telemetry

To check spans and logs the app exports, give it a loopback collector. Plain
http is allowed only for loopback hosts, and the exporter sends OTLP as JSON,
so a small Python server that writes each POST body to a file is enough
(listen on `127.0.0.1`, answer `200 {}`, one file per request under the
scratchpad). Run it in the background, then:

```bash
HERMES_DEV_DART_DEFINES="OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4399" \
  scripts/dev-app.sh start
```

Exports arrive batched within a few seconds, at `/v1/logs` and `/v1/traces`.
Read attributes from `resourceLogs[].scopeLogs[].logRecords[].attributes` and
`resourceSpans[].scopeSpans[].spans[].attributes`; int values come as
strings (`intValue: "49"`), as protobuf JSON encodes them. Exports sent
before the collector was up are lost, so start it first, or
`scripts/dev-app.sh restart` after. Stop the collector with the app.

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


## Dictation

The composer shows a microphone when the dev backend's profile has usable
speech-to-text (`GET /api/audio/voice-config` with the page's session token as
`X-Hermes-Session-Token`; `stt.reason` must not be `stt disabled` or
`no credentials`). Hermes' default `local` provider reports usable even when
`faster-whisper` is missing; the upload then answers an empty transcript and
the app says "No speech detected".

- `transcribe-stream` and `stt-lease` came in Hermes v0.21.6. The version CI
  pins may be older: the socket is refused (the app uploads) and the lease
  answers 405 (ignored). To try the real socket, build v0.21.6 or newer with
  the recipe above, which needs `python3.14` (its dependencies are pinned for
  3.14), and add `faster-whisper` to that venv. faster-whisper 1.2.1 fails
  with "open() got an unexpected keyword argument 'metadata_errors'" on
  PyAV 16 or newer; `pip install "av<16"` fixes it.
- Local Whisper does not stream (`stt.streaming: false`), so dictation
  uploads the whole clip after stop; live partials need a provider that
  streams.
- Without a microphone in the loop, drive `DictationController` from a
  throwaway test: read PCM from a WAV made with
  `say -o speech.wav --data-format=LEI16@16000 "…"`, feed it through
  `FakeVoiceRecorder.speak`, and point the repository at the dev backend.
  Delete the test before committing.
- The first tap on the microphone in the dev build asks macOS for microphone
  access; allow it by hand. A screenshot can show the waveform but not what
  was heard: speak, tap stop and read the draft.

### On this device

- Account menu (Settings… on macOS) > Dictation > On this device. The dev app
  has to request the language's model once even when the system already has it
  (the request then finishes in well under a second); `swift`/command-line
  probes see the system's models, the sandboxed app only its own.
- The backend logs no requests, so to prove no `/api/audio/` call goes out,
  put a logging TCP forwarder in front of it (a dozen lines of `asyncio` that
  forward bytes and write each `GET /path HTTP` line to a file; `socat` is not
  installed) and launch `flutter run -d macos
  --dart-define=HERMES_SERVER_URL=http://127.0.0.1:<proxy port>` yourself:
  `dev-app.sh start` refuses a port the backend's pid doesn't listen on.
  Saving the engine and restarting caught a `voice-config` read made before
  the setting had loaded.
- The iOS simulator has no on-device recognizer (`SpeechTranscriber.isAvailable`
  is false), so it shows "Not available for your language". Use a device.
- Without a microphone in the loop, a throwaway `lib/*_tmp.dart` entry run with
  `flutter run -d macos -t` can feed `say` PCM through `OnDeviceSpeech` in
  3200-byte chunks. Print with `print`, not `stdout`, so it also shows on iOS,
  and delete the file before committing.

## Verify Apple Handoff

Use an isolated backend and invented saved chats. Never install a test build
under an identifier that would replace an existing user app. Inspect the built
bundle IDs first. The macOS Debug app uses `com.cedricziel.hermesApp.dev`, but
the iOS Debug target currently uses the release ID. A physical iOS test needs
an isolated installation and valid signing before it can run safely.

Both test apps must use the same developer Team ID and activity type. Debug
builds advertise `com.cedricziel.hermesApp.continueChat.dev`; release builds
advertise `com.cedricziel.hermesApp.continueChat`. Verify the resolved
`NSUserActivityTypes` in each built Info.plist. Simulator builds and Dart
channel tests do not prove cross-device delivery.

On physical devices signed into the same Apple Account with Wi-Fi, Bluetooth,
and Handoff enabled, open an invented saved chat and choose Hermes from the
other device's Handoff suggestion. Repeat in both directions with the receiver
running and terminated. Check sign-in and app lock, identical thread IDs on
different profiles, a missing chat, an unreachable dashboard followed by retry,
and a reply already running. Confirm that continuing sends no new prompt and
does not stop the source reply. Check a different dashboard with both Cancel
and Connect. Keep addresses and credentials confined to test instances.

The source should withdraw its activity when leaving the chat or locking.
Backgrounding with app lock off should still allow continuation. Open another
chat while a target loads and confirm the late result cannot change selection.
Record any unavailable device or signing checks as outstanding. Do not mark
the physical-device task complete from simulator or method-channel evidence.
