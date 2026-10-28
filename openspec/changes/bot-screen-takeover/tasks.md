# Tasks

One PR, `feat(bot-screen): take over and hand back the screen`, about 500 changed lines including catalog and `design/web`. Depends on `bot-screen-rfb-input`.

## 1. Lease and pinned requests

- [ ] 1.1 Write failing tests: `requestOn` sends on the given connection and throws `GatewayConnectionClosed` without opening one when it is gone; `acquire` and `release` go over the connection that answered `display.observe`; a `viewer_mismatch` or a closed connection observes again and retries once, a second failure is refused; `inControl` follows the acquire answer's lease without waiting for a broadcast; release returns to watching from its answer; force release sends `force: true` and no viewer id.
- [ ] 1.2 Add `requestOn`, `BotScreenRepository.acquire`/`release`, `BotScreenViewerIds` and the controller's lease states; verify 1.1 passes.

## 2. Lifecycle

- [ ] 2.1 Write failing tests with a fake clock: in control, backgrounding closes with 4100; covered for 1 s then uncovered keeps the stream; covered for 3 s closes with 4100; returning observes with the old id and re-acquires without asking when a new id was minted and the hash names the old one; sign-out, profile switch and Change Server release (pinned) then close with 1000; closing the viewer releases then closes with 1000; 4000 and a foreign holder move to lost; watching pauses still close with 1000.
- [ ] 2.2 Implement; verify 2.1 passes.

## 3. Catalog first

- [ ] 3.1 Add viewer use cases (watching with Take over, the confirmation on iOS, Material and desktop, in control with key bar, in control with desktop toolbar on macOS and Windows, trackpad with cursor, lost control, someone in control with Hand back to Hermes, the force confirmation) and card use cases ("You're in control", someone in control with the force action); both themes. Verify the catalog test passes.
- [ ] 3.2 Mirror them in `design/web` (`BotScreenViewer`, `BotScreenCard`) and verify `npm run build` passes.

## 4. Wiring input

- [ ] 4.1 Write failing widget tests: Take over asks once per account and not after "Don't ask again"; in control a tap sends a click at the mapped point; the hidden field has autocorrect, suggestions and learning off, smart quotes and dashes disabled and `visiblePassword`, and sends composing text only on commit; Paste sends the text, Control+V, then an empty cut text after 500 ms; text outside Latin-1 shows the refusal and sends nothing; on macOS ⌘V pastes, ⌘Q/⌘W/⌘H/⌘M are not handled by the picture, ⌘A sends Ctrl+A, Escape reaches the screen and ⌘. closes the viewer; on Windows Ctrl+V pastes and F8 closes; Hand Back returns to watching.
- [ ] 4.2 Wire the chrome, `ScreenGestureLayer`, keyboard focus, the hidden field, paste and the confirmations; verify 4.1 passes.

- [ ] 4.3 Give trackpad mode a way to drag with a button held (tap and drag: a tap followed at once by a press that moves holds the primary button), which `ScreenGestureLayer` does not offer: there the one-finger pan only moves the virtual pointer. Add a test with the other gesture tests.

## 5. Observability

- [ ] 5.1 Write failing tests: `bot_screen.takeover`, `bot_screen.handback`, `bot_screen.lost_control` and `bot_screen.paste_refused` carry only their fixed attribute; the stream span gets `took_over` and bucketed `input_events`; breadcrumbs carry fixed values; no recorded value contains typed text, a key name, coordinates or a viewer id. Implement and verify.

## 6. Docs and skills

- [ ] 6.1 Extend `CLAUDE.md`'s Bot Screen paragraph: the lease and pinned connection, viewer ids, 4100 on background and the 2 s cover debounce, reserved keys per platform, paste and clipboard clearing, force hand back. Add a takeover step to a workflow test.
- [ ] 6.2 Add a takeover section to the `verify-bot-screen` skill (take over, type, switch apps and return, hand back, force hand back after restarting the app).

## 7. Verify

- [ ] 7.1 Run format, analyze and the full test suite, all clean.
- [ ] 7.2 Run `verify-in-app` per the `verify-bot-screen` skill on macOS: take over, type into a page on the screen, paste, hide and show the app, hand back; quit and relaunch while in control and use Hand back to Hermes; screenshot each state.
