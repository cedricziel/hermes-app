# Tasks

One PR, `feat(bot-screen): watch the screen live`, about 500 changed lines including catalog and `design/web`. Depends on `bot-screen-rfb-client`.

## 1. Viewer controller

- [x] 1.1 Write failing tests for `BotScreenViewerController` with a fake gateway and a fake socket opener: observe sends `profile` and the stream opens with its ticket and path; each row of the close-code table (1000, 4000, 4001, 4401 once and twice, 1003, HTTP 403, 1006 with backoff and give-up after 5 attempts); an observe failure reads status and shows Off when not running, Error otherwise; pausing closes with 1000 and drops the framebuffer, resuming observes again; a lease held by someone else blanks the picture and keeps the stream.
- [x] 1.2 Add `BotScreenRepository.observe` and implement the controller; verify 1.1 passes.

## 2. Catalog first

- [x] 2.1 Build `BotScreenViewerView` from a plain model (connecting, live with a picture, reconnecting over a dimmed picture, off with Start Screen, someone else in control, not allowed, cannot reach with Try Again) with Widgetbook use cases on iPhone, Android and desktop widths, as page and overlay, Apple and Material, both themes. Verify the catalog test passes.
- [x] 2.2 Mirror it in `design/web` (`BotScreenViewer`, `docs/BotScreenViewer.md` with `category: Screens`) and verify `npm run build` passes.

## 3. Wiring

- [x] 3.1 Write failing widget tests: the card's Enlarge is visible and opens the viewer, as does tapping its picture; (the transcript preview's part is 3.3) a phone width pushes a page and 1200 pt shows the full-window overlay; Escape and Close close the overlay; backgrounding, App Lock and a profile switch close the stream; no input message is sent when the user taps or clicks the picture.
- [x] 3.2 Wire the openers and presentation in `ChatScreen`; verify 3.1 passes.
- [ ] 3.3 Open the viewer from the transcript preview (`_openViewer('preview')`, replacing its `_openActivity` tap) and test it beside 3.1's. Waits for `bot-screen-chat-preview`, which is not on `main` yet; the first PR leaves this open.

## 4. Observability

- [x] 4.1 Write failing tests: a stream records `bot_screen.stream` with only the named attributes; an ending the app did not cause logs `bot_screen.stream_failed` with `step` and `error_type`; opening and closing record the breadcrumbs with `surface` and `source`; no attribute value contains the ticket, the URL or the viewer id. Implement and verify.

## 5. Docs and skills

- [x] 5.1 Extend `CLAUDE.md`'s Bot Screen paragraph: the viewer, its presentation, the close-code table, blanking while someone else is in control, and when the stream closes.
- [x] 5.2 Add a "watch the screen live" step to the `verify-bot-screen` skill (open the viewer, background the app, return).

## 6. Verify

- [x] 6.1 Run format, analyze and the full test suite, all clean.
- [ ] 6.2 (not run: no Docker host here) Run `verify-in-app` per the `verify-bot-screen` skill: open the viewer from the card and from the preview, screenshot it live on macOS, stop the screen and screenshot Off.
