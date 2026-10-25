# Tasks

One PR, `feat(bot-screen): send input over RFB`, about 500 changed lines including tests. Depends on `bot-screen-live-view`; no UI.

## 1. Client input messages

- [ ] 1.1 Write failing tests for `RfbClient.pointer`, `key`, `scroll` and `cutText`: byte layouts per RFC 6143 (PointerEvent 6 bytes, KeyEvent 8 bytes, ClientCutText 8 + n with a positive length), coordinates clamped, wheel notches as press and release of buttons 4/5 and 6/7 with held buttons kept, Latin-1 text sent byte for byte, a non-Latin-1 character throws `notLatin1` and sends nothing, more than 256 KiB throws `tooLarge`, calls before ServerInit and after the end throw; SetDesktopSize is still never sent.
- [ ] 1.2 Implement; verify 1.1 passes.

## 2. Keysyms

- [ ] 2.1 Write failing tests for `KeysymMapper`: the non-printing table, Latin-1 characters, a non-Latin-1 character as `0x01000000 + codepoint`, a character outside the BMP, `commandAsControl` mapping Meta to Control only when set, and `text()` producing press/release pairs.
- [ ] 2.2 Implement; verify 2.1 passes.

## 3. Coordinate math and gestures

- [ ] 3.1 Write failing tests for `ScreenGeometry`: absolute mapping at fit, at 2× zoom and panned, with letterboxing, clamping outside the picture; trackpad relative movement at 1× and 3×; trackpad scroll accumulating to notches at 40 px.
- [ ] 3.2 Write failing widget tests for `ScreenGestureLayer` with a recording sink: touch tap, long press and one-finger drag produce the right calls at mapped coordinates; two-finger pinch reaches the `InteractiveViewer` and sends nothing; trackpad pan moves the virtual pointer and a tap clicks there; mouse hover, buttons and wheel are sent; `enabled: false` sends nothing.
- [ ] 3.3 Implement `ScreenGeometry` and `ScreenGestureLayer`; verify 3.1 and 3.2 pass.

## 4. Observability

- [ ] 4.1 None in this change: nothing calls these methods. `bot-screen-takeover` adds the counts and the clipboard refusal log.

## 5. Docs and skills

- [ ] 5.1 Add input to `CLAUDE.md`'s Bot Screen paragraph: the client's input methods, keysyms, Latin-1-only clipboard and why the extended clipboard is not used yet.
- [ ] 5.2 No skill change.

## 6. Verify

- [ ] 6.1 Run format, analyze and the full test suite, all clean. No verify-in-app or `verify-bot-screen` run: nothing calls the input path until `bot-screen-takeover`, which verifies it live.
