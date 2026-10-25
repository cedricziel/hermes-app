# Design

## Context

Hermes (`tui_gateway/methods_display.py`): `display.install` refuses (5300, message only) on a non-Linux host, a sandboxed profile ("give that sandbox an image with the desktop stack"), a host without apt-get, dnf or pacman, and while another install runs; otherwise it claims the install, answers `{started, command, profile_key}` at once and runs the package manager on a thread. Output streams as `display.install.log` broadcasts to every client; the end is `display.install.done` with `code` (0 ok, -1 cancelled, -2 no sudo: the manual command was streamed) and a fresh `status`. When it needs sudo it calls `_ask("display.install.sudo", "", {profile_key}, timeout=300)`, which reaches only the connection that called `display.install` (its transport is carried into the worker thread), with an empty `session_id`; `{value: ""}` declines.

In the app, `HermesGatewayTransport` listens to `client.serverRequests` for methods outside `handledServerRequests` and answers `-32601` only when `_replying.containsKey(request.sessionId)`: other clients attached to a session may answer it, so the app stays silent otherwise. With `session_id: ""` that condition never holds, so `display.install.sudo` is ignored today and the server waits 300 s. `bot-screen-card` owns `BotScreenController` in `ChatScreen`, which is replaced on profile switch and disposed when the chat leaves the screen, so it cannot host a prompt for an install that outlives it.

## Decisions

- **Handler registry.** `HermesGatewayTransport.registerServerRequestHandler(String method, Future<Map<String, Object?>> Function(GatewayServerRequest) handler)` returns an unregister callback. The unhandled-request listener checks the registry first: a registered handler answers with its result (a throw answers `-32603`). For a method in `registrableServerRequests` (`{'display.install.sudo'}`) with no handler, the transport answers `-32601` at once whatever the session, since that request reaches only the connection that started the install. Other unhandled methods keep today's behaviour.
- **App-level host.** `BotScreenInstalls` (`lib/src/bot_screen/install/`), created by `AppShell` per gateway connection and provided below it, holds `Map<profileKey, InstallState>` (`idle`, `running(lines, askedPassword)`, `done(code, status)`, `refused(message)`), follows `display.install.log`/`done` from `connectionEvents`, keeps the last 6 lines per key, and registers the sudo handler while at least one install it started is running. The handler checks `profile_key` against its running installs (else refuses) and shows `SudoPasswordPrompt` through the shell's navigator, so it appears over whatever screen is up. `BotScreenController` reads install state for its key from `BotScreenInstalls` instead of owning it.
- **Gate.** Install on Server shows only when `installed` is false, `placement == "gateway"` and `install_command` is present.
- **Refusal.** A 5300 answer to `display.install` becomes `refused(message)`; the card shows "Couldn't start the install" and the message, with Install on Server again.
- **Missed done.** While an install runs, `BotScreenInstalls` reads `display.status` for that profile on app resume and after `GatewayConnectionEvent.lost`; `installed: true` ends it as `done(0, status)` with outcome `installed`. A 20-minute timer ends it as `unknown` (card: "The install may still be running; check again later", with the status re-read). Both paths end the span.
- **No sudo.** On -2 the card shows the status' `install_command` (from the done payload, falling back to the last status) in monospace with Copy, not log lines.
- **Password UI.** `SudoPasswordPrompt` (iOS sheet with an obscured `CupertinoTextField`, Material `AlertDialog`, Mac sheet) with `obscureText: true`, `autocorrect: false`, `enableSuggestions: false`, `enableIMEPersonalizedLearning: false`, `autofillHints: null`, `keyboardType: TextInputType.visiblePassword`. Install answers `{value: text}` once and clears the `TextEditingController`; Cancel or dismissal answers `{value: ""}`. If the install ends first (done arrives), the prompt closes. App Lock covers the prompt like any screen; it answers only when the user acts.
- **Host label.** The prompt names the dashboard's host from the connection's base URL (shown, never logged).
- **Catalog and design system.** Card states Installing (lines), install refused, cancelled, no sudo with the command, failed, may still be running; `SudoPasswordPrompt` per platform; `design/web` `BotScreenCard` states and a `SudoPasswordPrompt` component (`category: Surfaces`, like the other dialogs).

Platforms: iOS, Android, macOS, Windows, Linux. No native change.

Invariants touched:

- Telemetry: span `bot_screen.install` and log `bot_screen.install` (`outcome`, `asked_password`) in `BotScreenInstalls`; breadcrumbs `bot_screen.install.pressed` (card) and `bot_screen.install.password` (`answered`, `cancelled`) (prompt). No password, command, lines, host or profile.
- Secure storage: the password is never stored, so no secure storage use.

## Risks / Trade-offs

- [A password typed on a phone goes to the server] → It is that server's own sudo password, asked for by its Hermes over the authenticated socket; the alternative is SSH. The prompt names the host.
- [The gateway reconnects during the install] → The sudo request was tied to the old connection; the server's ask times out and done reports a failure; the status re-read after the reconnect catches a success, and the card offers Install on Server again on failure.
- [Refusing `display.install.sudo` explicitly could race another client] → Only the connection that started the install receives it, so there is no other answerer.
