# Tasks

This change is far over the roughly 500 changed lines one PR should hold (the lease, the lifecycle, the viewer chrome, the input wiring, the hidden keyboard, paste and the catalog and `design/web` mirrors, each with tests), so it ships as two PRs, in order, each self-contained and green. Depends on `bot-screen-rfb-input`.

1. `feat(bot-screen): hold the screen's control lease` (PR 1): sections 1, 2, 3a, 5a, 6.1a and 7.1. The lease, the lifecycle and the viewer's lease chrome work and are tested, and the card and the viewer already offer Hand back to Hermes for a lease nobody here holds. The viewer does not offer Take over yet, because nothing it could take over for would accept input.
2. `feat(bot-screen): take over and hand back the bot's screen` (PR 2): sections 3b, 4, 5b, 6.1b, 6.2 and 7.2. Take over, the confirmation, input, the reserved keys, the hidden keyboard and Paste.

## 1. Lease and pinned requests

- [x] 1.1 Write failing tests: `requestOn` sends on the given connection and throws `GatewayConnectionClosed` without opening one when it is gone; `acquire` and `release` go over the connection that answered `display.observe`; a `viewer_mismatch` or a closed connection observes again and retries once, a second failure is refused; `inControl` follows the acquire answer's lease without waiting for a broadcast; release returns to watching from its answer; force release sends `force: true` and no viewer id.
- [x] 1.2 Add `requestOn`, `BotScreenRepository.acquire`/`release`, `BotScreenViewerIds` and the controller's lease states; verify 1.1 passes.

## 2. Lifecycle

- [x] 2.1 Write failing tests with a fake clock: in control, backgrounding closes with 4100; covered for 1 s then uncovered keeps the stream; covered for 3 s closes with 4100; returning observes with the old id and re-acquires without asking when a new id was minted and the hash names the old one; sign-out, profile switch and Change Server release (pinned) then close with 1000; closing the viewer releases then closes with 1000; 4000 and a foreign holder move to lost; watching pauses still close with 1000.
- [x] 2.2 Implement; verify 2.1 passes.

## 3. Catalog first

- [x] 3.1a Add the lease use cases: the viewer watching with Take over, taking over, in control (page and over the window), losing control, someone in control with Hand back to Hermes, the force confirmation, and the card's "Someone in control" with the force action next to "You're in control"; both themes. Verify the catalog test passes.
- [ ] 3.1b Add the rest: the take over confirmation (phone sheet and desktop dialog), in control with the key bar, in control with the desktop toolbar on macOS and Windows, trackpad with its cursor, and the paste notice. Verify the catalog test passes.
- [x] 3.2a Mirror the lease states in `design/web` (`BotScreenViewer`, `BotScreenCard`) and verify `npm run build` passes.
- [ ] 3.2b Mirror the rest in `design/web` and verify `npm run build` passes.

## 4. Wiring input

- [ ] 4.1 Write failing widget tests: Take over asks once per account and not after "Don't ask again"; in control a tap sends a click at the mapped point; the hidden field has autocorrect, suggestions and learning off, smart quotes and dashes disabled and `visiblePassword`, and sends composing text only on commit; Paste sends the text, Control+V, then an empty cut text after 500 ms; text outside Latin-1 shows the refusal and sends nothing; on macOS ⌘V pastes, ⌘Q/⌘W/⌘H/⌘M are not handled by the picture, ⌘A sends Ctrl+A, Escape reaches the screen and ⌘. closes the viewer; on Windows Ctrl+V pastes and F8 closes; Hand Back returns to watching.
- [ ] 4.2 Wire the chrome, `ScreenGestureLayer`, keyboard focus, the hidden field, paste and the confirmations; verify 4.1 passes.
- [ ] 4.3 Give trackpad mode a way to drag with a button held (tap and drag: a tap followed at once by a press that moves holds the primary button), which `ScreenGestureLayer` does not offer: there the one-finger pan only moves the virtual pointer. Add a test with the other gesture tests.

## 5. Observability

- [x] 5.1a Write failing tests: `bot_screen.takeover`, `bot_screen.handback` and `bot_screen.lost_control` carry only their fixed attribute; the stream span gets `took_over`; breadcrumbs `bot_screen.handback.pressed` and `bot_screen.force_handback.pressed` carry nothing; no recorded value contains a viewer id or its hash. Implement and verify.
- [ ] 5.1b Write failing tests: `bot_screen.paste_refused` carries only its reason; the stream span gets bucketed `input_events`; breadcrumbs `bot_screen.takeover.pressed` and `bot_screen.input.mode` carry fixed values; no recorded value contains typed text, a key name or coordinates. Implement and verify.

## 6. Docs and skills

- [x] 6.1a Extend `CLAUDE.md`'s Bot Screen paragraph: the lease and pinned connection, viewer ids, 4100 on background and the 2 s cover debounce, shutting down, force hand back.
- [ ] 6.1b Extend it with the reserved keys per platform, paste and clipboard clearing and the hidden keyboard. Add a takeover step to a workflow test.
- [ ] 6.2 Add a takeover section to the `verify-bot-screen` skill (take over, type, switch apps and return, hand back, force hand back after restarting the app).

## 7. Verify

- [x] 7.1 Run format, analyze and the full test suite, all clean (PR 1; PR 2 runs them again).
- [ ] 7.2 Run `verify-in-app` per the `verify-bot-screen` skill on macOS: take over, type into a page on the screen, paste, hide and show the app, hand back; quit and relaunch while in control and use Hand back to Hermes; screenshot each state.
