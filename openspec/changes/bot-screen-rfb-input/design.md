# Design

## Context

Hermes' bridge (`tools/bot_desktop/rfb_filter.py`) frames KeyEvent (8 bytes), PointerEvent (6), ClientCutText (8 + |n|, rejecting |n| above 256 KiB, the `-MaxCutText` Xvnc is started with) and drops them unless the viewer holds the lease. A negative ClientCutText length is TigerVNC's extended clipboard. `RfbClient` from `bot-screen-rfb-client` sends only non-input messages and keeps its framebuffer size. `bot-screen-live-view` draws the picture with `RawImage` inside an `InteractiveViewer` driven by a `TransformationController`.

## Decisions

- **Client methods.** `pointer(int x, int y, int buttonMask)`, `key(int keysym, {required bool down})` and `cutText(String text)` on `RfbClient`; each throws `StateError` before ServerInit and after the stream ended. `pointer` clamps to `0..width-1` and `0..height-1`. Button mask bits: 1 primary, 2 middle, 4 secondary, 8/16 wheel up/down, 32/64 wheel left/right. `scroll(x, y, {dx, dy})` sends one press and one release of the matching wheel bit per notch, keeping the held buttons.
- **Clipboard encoding.** `cutText` checks every code unit: anything above 0xFF throws `RfbClipboardError.notLatin1` and nothing is sent; more than 256 KiB of bytes throws `RfbClipboardError.tooLarge`. Line breaks are sent as `\n`. The extended clipboard is not used (see the proposal's non-goals); SetEncodings is unchanged, so Xvnc never sends extended clipboard messages to this client.
- **`KeysymMapper`** (`lib/src/bot_screen/input/keysyms.dart`): a table from `LogicalKeyboardKey` to keysyms for non-printing keys (Escape 0xff1b, Tab 0xff09, Return 0xff0d, BackSpace 0xff08, Insert 0xff63, Delete 0xffff, Home 0xff50, End 0xff57, Page Up 0xff55, Page Down 0xff56, arrows 0xff51–0xff54, F1–F12 0xffbe–0xffc9, Shift L/R 0xffe1/0xffe2, Control L/R 0xffe3/0xffe4, Alt L/R 0xffe9/0xffea, Super L/R 0xffeb/0xffec, Caps Lock 0xffe5). Characters: 0x20–0x7e and 0xa0–0xff as their code point, every other code point as `0x01000000 + codepoint`. Option `commandAsControl` maps Meta L/R to Control L/R (used by takeover on macOS). `KeysymMapper.text(String)` yields press/release pairs per character (grapheme clusters split into code points).
- **Coordinate math** (`screen_geometry.dart`): `ScreenGeometry(framebufferSize, pictureRect, Matrix4 transform)` maps a local position through the inverse of the `InteractiveViewer` transform into picture space, then scales to framebuffer pixels and clamps; positions outside the picture clamp to its edge. Trackpad mode keeps a virtual pointer in framebuffer pixels and moves it by `delta * framebufferWidth / (pictureWidth * scale)`. Wheel deltas from a mouse are one notch per event; trackpad scroll deltas accumulate, one notch per 40 logical pixels.
- **`ScreenGestureLayer`** (`screen_gesture_layer.dart`) sits over the picture and calls an `RfbInputSink` (the three client methods behind an interface, so tests record calls). `mode: touch` — tap is move, press and release of button 1; long press is button 3; one-finger pan moves with button 1 held; two-finger gestures are left to the `InteractiveViewer` by not claiming them. `mode: trackpad` — one-finger pan moves the virtual pointer, tap clicks at it, and the layer exposes the pointer's position for a cursor overlay. Mouse input uses a `Listener` (hover moves, buttons map to the mask, `PointerScrollEvent` to wheel notches) so it never competes in the gesture arena. `enabled: false` (the default) claims nothing and sends nothing.

Platforms: iOS, Android, macOS, Windows, Linux. No native change.

Invariants touched: none recorded. Telemetry is untouched in this change; the typed errors carry no text.

## Risks / Trade-offs

- [Keyboard layouts: keysyms from characters assume Xvnc can produce them] → Xvnc maps keysyms to keycodes itself and assigns spare keycodes to Unicode keysyms.
- [No non-Latin-1 paste] → Refused clearly rather than corrupted; typing such characters on the keyboard still works through Unicode keysyms.
