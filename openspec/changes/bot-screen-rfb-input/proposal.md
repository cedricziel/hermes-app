# Proposal

## Why

Taking over the screen means sending the remote desktop pointer, key and clipboard messages that line up with what the user sees. Getting keysyms, coordinates under zoom and pan, and the clipboard's encoding right is testable on its own and large enough to be its own PR, so `bot-screen-takeover` only adds the lease, the chrome and the wiring.

Design: https://claude.ai/artifact/Vh36BWznGNK6NZHJsqKQPJ

The series, one PR each, shipped and archived in this order:

1. `bot-screen-status`: repository and controller for the screen's state and still frames. No UI.
2. `bot-screen-card`: the Bot screen card in the Activity panel.
3. `bot-screen-chat-preview`: the still preview in the transcript while a turn uses `computer_use`.
4. `bot-screen-rfb-client`: the display socket and a watch-only RFB 3.8 client. No UI.
5. `bot-screen-live-view`: the live, watch-only viewer.
6. `bot-screen-rfb-input` (this change): pointer, key and clipboard messages, keysyms and gesture math. No UI.
7. `bot-screen-takeover`: take over and hand back control.
8. `bot-screen-host-install`: install the desktop packages on the server from the app.

Minimum Hermes version: the lease-gated input path of `/api/display/ws` first ships in Hermes v2026.9.24 (every later release, v0.21.x and v0.22.x, has it).

## What Changes

- `RfbClient` can send PointerEvent, KeyEvent and ClientCutText. Coordinates are clamped to the framebuffer; the scroll wheel is buttons 4/5 (vertical) and 6/7 (horizontal), pressed and released per notch.
- A keysym mapper from Flutter keys and typed characters to X11 keysyms: a table for non-printing keys, Latin-1 characters as themselves, other characters as X11 Unicode keysyms.
- `ScreenGestureLayer`, a widget with no visuals of its own that turns touch, trackpad and mouse gestures on the zoomed and panned picture into pointer calls: touch maps positions absolutely, trackpad moves a virtual pointer relatively, the mouse wheel and trackpad scrolling become wheel buttons. It is tested with widget tests and not placed in any screen yet.
- Clipboard text is sent as classic ClientCutText in Latin-1, at most 256 KiB. Text with a character outside Latin-1 is refused with a typed error and nothing is sent; no character is silently replaced.
- Nothing calls these yet; the viewer stays watch-only until `bot-screen-takeover`.

## Non-goals

- Any UI, the lease, and deciding when input may be sent (`bot-screen-takeover`).
- SetDesktopSize (resizing the remote desktop), QEMU extended key events.
- The TigerVNC extended clipboard. Hermes' bridge frames it (negative ClientCutText length, `rfb_filter.py`) and Xvnc supports it, but Xvnc accepts clipboard data only when it asked for it: the client must exchange capabilities, announce text with a notify, wait for Xvnc's request when an X application pastes, then provide the zlib-compressed text. That lazy exchange, its interaction with clearing the clipboard after a paste, and the extra pseudo-encoding do not fit this PR; a later change can add it, and with it non-Latin-1 paste.
- Reading the server's clipboard.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bot-screen`: the client's input messages, keysyms, coordinate mapping and clipboard encoding.

## Impact

- `lib/src/bot_screen/rfb/rfb_client.dart`: `pointer`, `key`, `cutText`.
- New `lib/src/bot_screen/input/keysyms.dart` (`KeysymMapper`), `screen_geometry.dart` (coordinate math) and `screen_gesture_layer.dart` (`ScreenGestureLayer`).
- Unit and widget tests only; no catalog entry, since the layer draws nothing.

## Security and privacy

- Text and keys go to the server only as RFB messages; the mapper and client never log, keep or export them.
- Refusing non-Latin-1 text instead of replacing characters means a pasted secret never arrives altered.
- The server's lease gate drops input from a viewer that does not hold control; the client adds no bypass.

## Observability

None: nothing calls the input methods yet. `bot-screen-takeover` records counts on its stream span and logs the clipboard refusal.
