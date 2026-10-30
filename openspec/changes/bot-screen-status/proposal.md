# Proposal

## Why

Hermes can give each profile its own desktop on a Linux server (Bot Screen: Xvnc and Xfce), which its `computer_use` tool and headed browser act on. Hermes Desktop shows that screen; this app shows nothing, so a user on a phone or another computer cannot see what the agent is doing on it or tell that it is stuck at a login. This change lays the groundwork without any UI: it reads a profile's screen state over the gateway, follows it, and fetches still frames on demand, so the next changes only add surfaces.

Design: https://claude.ai/artifact/Vh36BWznGNK6NZHJsqKQPJ

The series, one PR each, shipped and archived in this order:

1. `bot-screen-status` (this change): repository and controller for the screen's state and still frames. No UI.
2. `bot-screen-card`: the Bot screen card in the Activity panel.
3. `bot-screen-chat-preview`: the still preview in the transcript while a turn uses `computer_use`.
4. `bot-screen-rfb-client`: the display socket and a watch-only RFB 3.8 client. No UI.
5. `bot-screen-live-view`: the live, watch-only viewer.
6. `bot-screen-rfb-input`: pointer, key and clipboard messages, keysyms and gesture math. No UI.
7. `bot-screen-takeover`: take over and hand back control.
8. `bot-screen-host-install`: install the desktop packages on the server from the app.

Minimum Hermes version: the `display.*` methods, `viewer_hash` and `display.install.sudo` first ship in Hermes v2026.9.24, and every later release (v0.21.x, v0.22.x) has them. An older server answers method-not-found and gets no Bot Screen; nothing else changes for it.

## What Changes

- A repository over the gateway's `display.status`, `display.start` and `display.thumbnail`, always sending an explicit `profile` (the chat's profile, or `default` for a chat on the server's default profile).
- A per-profile controller that holds the screen's status and the latest still frame, follows the `display.status` and `display.lease` broadcasts on the shared gateway connection, re-reads the status where broadcasts can be missed (after the connection is lost, on app resume, and every 10th frame request, since lease changes made by other server processes are not broadcast), and fetches a frame every 3 seconds while some surface asks for one.
- Display calls get their own timeout that fails only that call: today a request that times out drops the shared gateway connection, which would cut a running chat reply because a screenshot was slow.
- `GatewayRpcException` carries the error's `data`, so `data.code` (such as `viewer_mismatch`) is readable by this and later changes.
- Answers that arrive after App Lock covered the app, or after the chat switched profile, are discarded.
- The gateway contract test classifies `display.status` and `display.lease` as read by the transport.
- `test/real_backend_contract_test.dart` checks the `display.*` shapes against a live backend.
- A new project skill, `verify-bot-screen`, starts a throwaway Linux Hermes with the desktop packages in a container, because a macOS dev backend reports `supported: false` and can never show a screen.

## Non-goals

- Any UI (`bot-screen-card` and later).
- Stopping the screen (`display.stop`) or switching sandbox images (`display.switchSandboxImage`).
- Polling while nothing asks for frames.
- The live stream, input and control (later changes).
- A screen for a profile other than the one a surface asks about.

## Capabilities

### New Capabilities

- `bot-screen`: a profile's Bot Screen as the app reads, shows and controls it.

### Modified Capabilities

None.

## Impact

- New `lib/src/bot_screen/`: `BotScreenRepository`, `BotScreenController` and their models.
- `lib/src/chat/gateway/hermes_gateway_transport.dart`: a `request` variant whose timeout does not drop the connection.
- `lib/src/chat/gateway/gateway_rpc_client.dart`: `GatewayRpcException.data`.
- `test/gateway/gateway_contract_test.dart`, `test/real_backend_contract_test.dart`.
- New `.claude/skills/verify-bot-screen/SKILL.md`.
- No REST route, so no OpenAPI change.

## Security and privacy

- Frames are JPEGs of the agent's desktop and can show anything it sees (mail, documents). The controller keeps them in memory only, never writes, logs or exports them, and drops them on App Lock, sign-out and profile switch.
- `profile_key` (a server path) is used only to match broadcasts in memory, never shown or logged.
- The install command and blocker text are kept for display only, never logged.
- No tokens or storage change.

## Observability

- Span `bot_screen.thumbnail` per frame request (it crosses the socket and takes time), with the connection's `hermes.*` attributes, `outcome` (`frame`, `suppressed`, `stopped`, `timeout`, `error`) and `bytes_kib` (the JPEG's size in KiB, bucketed). The `GatewayRpcClient` request span for `display.thumbnail` also appears per request; both are kept, since the RPC span is shared by every method.
- Log event `bot_screen.unsupported` once per repository (built for one connection) when `display.status` answers method-not-found: how many servers are too old.
- Log event `bot_screen.read_failed` with `method` and `error_type` (`timeout`, `display_error`, `closed`) when a display call fails, once per failure streak: how often the screen cannot be read.
- No breadcrumbs: this change has no user step.
