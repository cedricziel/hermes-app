# Proposal

## Why

A Linux server without TigerVNC and Xfce has no Bot Screen. `bot-screen-card` shows the install command, but a user on a phone cannot easily run it. Hermes can run the distro's package install itself and asks the client that started it for the server's sudo password. This change adds **Install on Server**.

Design: https://claude.ai/artifact/Vh36BWznGNK6NZHJsqKQPJ

The series, one PR each, shipped and archived in this order:

1. `bot-screen-status`: repository and controller for the screen's state and still frames. No UI.
2. `bot-screen-card`: the Bot screen card in the Activity panel.
3. `bot-screen-chat-preview`: the still preview in the transcript while a turn uses `computer_use`.
4. `bot-screen-rfb-client`: the display socket and a watch-only RFB 3.8 client. No UI.
5. `bot-screen-live-view`: the live, watch-only viewer.
6. `bot-screen-rfb-input`: pointer, key and clipboard messages, keysyms and gesture math. No UI.
7. `bot-screen-takeover`: take over and hand back control.
8. `bot-screen-host-install` (this change): install the desktop packages on the server from the app.

Minimum Hermes version: `display.install`, its log and done broadcasts and the `display.install.sudo` server request first ship in Hermes v2026.9.24 (every later release, v0.21.x and v0.22.x, has them).

## What Changes

- The card's Not installed state offers **Install on Server** when the screen would run on the gateway host (`placement: gateway`) and the server reports an install command. A sandboxed profile keeps the sandbox-image sentence and gets no button.
- While installing, the card shows the package manager's latest lines (`display.install.log`), a spinner and "You can close this; the install keeps going".
- When the server asks for the sudo password (`display.install.sudo`, a server request with an empty session), the app shows a masked password prompt naming the dashboard's host, with Install and Cancel. The prompt is hosted at app level, so it appears even if the user has left the chat or switched profile since starting the install. The answer goes back once; Cancel answers empty, which declines.
- `display.install.done` ends it: code 0 shows the state from its status (Off with Start Screen); -1 cancelled; -2 the server has no sudo, with the status' install command to run by hand; any other code failed, with the last log lines and Install on Server again. If `display.install` itself is refused (another install running, unsupported host, sandbox, no package manager), the card shows "Couldn't start the install" with the server's message.
- Because the done broadcast can be missed, the app reads the status again on resume and after the gateway connection was lost, and leaves Installing when the status reports the packages installed or after 22 minutes.
- Today an unhandled server request is refused only when its session is replying, so `display.install.sudo` (session `""`) is silently ignored and the server waits out its 300 s timeout. This change refuses it explicitly when no install handler is registered.

## Non-goals

- Installing the browser package (`chromium`) or switching sandbox images (`display.switchSandboxImage`).
- Remembering the sudo password or offering it to other features.
- Installing into a terminal sandbox image.
- Cancelling an install that runs (Hermes has no cancel method).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bot-screen`: installing the desktop packages from the app; the card's states gain Installing and the install results.

## Impact

- `BotScreenRepository.install`; a new app-level `BotScreenInstalls` (one per gateway connection, provided by `AppShell`) that holds install state per `profile_key`, the sudo handler and the prompt host.
- `hermes_gateway_transport.dart`: a server-request handler registry consulted before the unhandled-request path; `display.install.sudo` without a handler is refused at once.
- `test/gateway/gateway_contract_test.dart`: `display.install.sudo` moves from `refusedRequests` to requests answered by a registered handler; `display.install.log` and `display.install.done` become `Use.transport`.
- `SudoPasswordPrompt` and the card's install states in the catalog and `design/web`.

## Security and privacy

- The sudo password is typed into an obscured field with autocorrect, suggestions, keyboard learning and autofill off, sent once in the server request's answer over the authenticated TLS gateway socket, and the field is cleared right after. The app keeps no reference to it, never stores, logs or shows it again, and sends it nowhere else. (Dart cannot guarantee a string is wiped from memory; the app only ensures it holds none.)
- The app answers a sudo request only while an install it started on that connection is running for that `profile_key`; any other `display.install.sudo` is refused.
- Install log lines and the install command are shown, never logged or sent to telemetry (they can name paths and packages).

## Observability

- Log event `bot_screen.install` with `outcome` (`installed`, `cancelled`, `no_sudo`, `failed`, `refused`, `unknown`, `error`) and `asked_password` (bool): an outcome worth counting; `unknown` is the timeout path when done never arrived.
- Span `bot_screen.install` from the request to done, or to the status read or timeout that ends it, with `hermes.*` attributes and `outcome`.
- Breadcrumbs `bot_screen.install.pressed` and `bot_screen.install.password` (`answered`, `cancelled`).
- Never the password, the command or log lines.
