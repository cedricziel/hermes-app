# Proposal

## Why

A still frame every 3 seconds shows where the agent is, not what it does. The live picture comes from the profile's Xvnc over RFB, which Hermes bridges onto a dashboard WebSocket. No maintained Dart RFB client fits (`dart_rfb` and `flutter_rfb` are from 2022 and TCP only; `vnc_viewer` is Android only), and a WebView with noVNC would leave out Linux. This change adds the display socket and a watch-only RFB 3.8 client with no UI, so `bot-screen-live-view` only adds the viewer.

Design: https://claude.ai/artifact/Vh36BWznGNK6NZHJsqKQPJ

The series, one PR each, shipped and archived in this order:

1. `bot-screen-status`: repository and controller for the screen's state and still frames. No UI.
2. `bot-screen-card`: the Bot screen card in the Activity panel.
3. `bot-screen-chat-preview`: the still preview in the transcript while a turn uses `computer_use`.
4. `bot-screen-rfb-client` (this change): the display socket and a watch-only RFB 3.8 client. No UI.
5. `bot-screen-live-view`: the live, watch-only viewer.
6. `bot-screen-rfb-input`: pointer, key and clipboard messages, keysyms and gesture math. No UI.
7. `bot-screen-takeover`: take over and hand back control.
8. `bot-screen-host-install`: install the desktop packages on the server from the app.

Minimum Hermes version: `/api/display/ws` and the `display.observe` ticket it needs first ship in Hermes v2026.9.24 (every later release, v0.21.x and v0.22.x, has them).

## What Changes

- A display socket opener that returns a `WebSocketChannel` (so the close code is readable and the app can close with a status code), with the same TLS and user-CA handling as the other dashboard sockets. The URL keeps the dashboard base URL's path prefix and carries only `display_ticket`, never the gateway token or ticket. An upgrade the server refuses before accepting (Host/Origin policy, seen as HTTP 403) becomes a typed "not allowed" error; no error the opener raises contains the URL or the ticket.
- An RFB 3.8 client: version exchange, security type None with the security result read, shared ClientInit, ServerInit, a fixed 32-bit true-colour pixel format, the Raw, CopyRect, ZRLE and DesktopSize encodings, and incremental update requests.
- ZRLE with one persistent zlib stream per connection and every subencoding Xvnc uses.
- Clipboard text the server sends is read past and discarded.
- The client sends no input of any kind.

## Non-goals

- Any UI, `display.observe` and reconnects (`bot-screen-live-view`).
- Input messages (`bot-screen-rfb-input`).
- Encodings beyond Raw, CopyRect, ZRLE and DesktopSize (Tight, JPEG, H.264), cursor pseudo-encodings, continuous updates, fences, audio.
- Reading the server's clipboard.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bot-screen`: the display stream and the RFB client behaviour.

## Impact

- New `lib/src/bot_screen/rfb/`: `display_socket.dart` (opener and typed errors), `rfb_client.dart` (reader, handshake, framebuffer, messages), `zrle.dart`.
- `lib/src/chat/gateway/gateway_connection.dart`: the shared connect step factored so `openMixedWebSocket` and the display opener use the same path.
- Tests from hand-built and recorded byte sequences.

## Security and privacy

- The display ticket travels in the URL query, as the server requires. The opener never logs the URL, and maps every connect failure to a typed error whose message holds neither URL nor ticket, so the crash reporter (which logs full messages) can never record them. Nothing rethrows the raw `WebSocketException`.
- The gateway credential is never put on the display socket.
- ServerCutText (the agent's desktop clipboard, which can hold secrets) is discarded unread and never logged. The desktop name from ServerInit is not logged.
- Framebuffer pixels stay in memory.

## Observability

None in this change: nothing calls the client yet. It counts received bytes and the encodings seen so the `bot_screen.stream` span in `bot-screen-live-view` can report them, and its typed errors carry a fixed `step` (`connect`, `handshake`, `decode`) for that change's failure log.
