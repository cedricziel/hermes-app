# Proposal

## Why

Watching the agent fill a form or follow a page needs the live picture, not a frame every 3 seconds. `bot-screen-rfb-client` provides the stream and the decoder; this change adds the watch-only viewer and opens it from the Activity card and the transcript preview.

Design: https://claude.ai/artifact/Vh36BWznGNK6NZHJsqKQPJ

The series, one PR each, shipped and archived in this order:

1. `bot-screen-status`: repository and controller for the screen's state and still frames. No UI.
2. `bot-screen-card`: the Bot screen card in the Activity panel.
3. `bot-screen-chat-preview`: the still preview in the transcript while a turn uses `computer_use`.
4. `bot-screen-rfb-client`: the display socket and a watch-only RFB 3.8 client. No UI.
5. `bot-screen-live-view` (this change): the live, watch-only viewer.
6. `bot-screen-rfb-input`: pointer, key and clipboard messages, keysyms and gesture math. No UI.
7. `bot-screen-takeover`: take over and hand back control.
8. `bot-screen-host-install`: install the desktop packages on the server from the app.

Minimum Hermes version: `display.observe` and `/api/display/ws` first ship in Hermes v2026.9.24 (every later release, v0.21.x and v0.22.x, has them). An older server shows no card or preview, so the viewer cannot be opened.

## What Changes

- A **screen viewer**: on phones a full-screen page (portrait and landscape, pinch to zoom, pan); from 760 pt a new full-window overlay (Close or Escape to leave). The inspector's overlay is a 380 pt side panel and is not reused.
- It opens from the Activity card's picture and its Enlarge action, which becomes visible, and from the transcript preview, which now opens the viewer instead of the Activity panel.
- The viewer calls `display.observe` for a ticket and viewer id, opens the stream with `bot-screen-rfb-client`, and draws the framebuffer as updates arrive.
- The header names the profile and who is in control. While a person other than this device holds control, the viewer blanks the picture and says someone else is in control, as the still preview does.
- Each close code has one meaning: 1000 the app closed it; 4000 reconnect as a watcher; 4001 the screen is off (no retry); 4401 observe again once, then show an error; 1003 a protocol error (no retry); an upgrade refused with HTTP 403 means viewing is not allowed (no retry); anything else reconnects with full-jitter backoff (300 ms to 15 s, 5 attempts). When observe fails, the viewer reads the status again to tell Off from an error.
- The stream is closed whenever the viewer is not visible: closed viewer, app not resumed, App Lock, sign-out, profile switch. An open viewer keeps the screen alive, because the server counts an attached viewer as use and skips its idle stop.
- Watch only: the viewer sends no input. Escape closes it.
- The viewer chrome is in the catalog and in `design/web`.

## Non-goals

- Input and control (`bot-screen-rfb-input`, `bot-screen-takeover`).
- A separate Mac window for the screen; the overlay covers the main window. No viewer in conversation windows or the quick panel.
- Live pictures in the card or the preview; they stay still frames.
- Watching while the app is in the background.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bot-screen`: the live, watch-only viewer; the preview and the card's Enlarge now open it.

## Impact

- `BotScreenRepository.observe`.
- New `lib/src/bot_screen/viewer/`: `BotScreenViewerController` (observe, socket, close codes, reconnect, pause), `BotScreenViewerView` (plain model) and the presentation (page route, `BotScreenViewerOverlay`).
- `lib/src/chat/chat_screen*.dart`: the viewer opener passed to the card's `onEnlarge` and the preview's `onTap`.
- `test/gateway/gateway_contract_test.dart` is unchanged (it lists notifications and server requests only, and observe is neither).
- Widgetbook use cases and `design/web` `BotScreenViewer` (`category: Screens`).

## Security and privacy

- The ticket is single use, valid 30 s, and travels only in the stream URL; it is never logged, put in a span or breadcrumb, or stored. The viewer id is held in memory for the viewer's life and never logged.
- The stream carries the agent's desktop live. The framebuffer stays in memory and is dropped when the viewer closes; the stream closes whenever the viewer is not visible, on App Lock and on sign-out.
- While someone else holds control, the viewer shows no picture, matching the server's thumbnail suppression: the person may be typing a credential. Hermes Desktop's own live viewers still see the screen then; that is outside this app.
- The socket uses the same certificate trust as the other dashboard sockets.

## Observability

- Span `bot_screen.stream` for the life of one stream, with the connection's `hermes.*` attributes, `outcome` (`closed`, `gone`, `ticket`, `not_allowed`, `protocol`, `error`), `close_code`, `encodings_used` (fixed names) and `kib_received` (bucketed): a long-running socket boundary.
- Log event `bot_screen.stream_failed` with `step` (`observe`, `connect`, `handshake`, `decode`) and `error_type` when a stream ends without the app closing it: a failure worth counting.
- Breadcrumbs `bot_screen.viewer.opened` (`surface`: `page`, `overlay`; `source`: `card`, `preview`) and `bot_screen.viewer.closed`: user steps.
