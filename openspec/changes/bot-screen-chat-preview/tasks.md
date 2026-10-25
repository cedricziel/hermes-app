# Tasks

One PR, `feat(bot-screen): preview the screen in the transcript`, about 400 changed lines including catalog and `design/web`. Depends on `bot-screen-card`.

## 1. Catalog first

- [ ] 1.1 Add `BotScreenPreview` and the `preview` slots on `ToolCallCard` and `ToolCallGroup`, with Widgetbook use cases: a single running `computer_use` card with a preview, a folded group whose header carries it, suppressed, Apple and Material, both themes, phone and desktop. Verify `flutter test test/widgetbook_test.dart` passes.
- [ ] 1.2 Mirror them in `design/web` (`preview` props, `BotScreenPreview` with `docs/BotScreenPreview.md`, `category: Agent activity`) and verify `npm run build` passes.

## 2. Placement

- [ ] 2.1 Write failing widget tests: only the run holding the reply's latest running `computer_use` call shows the preview; a folded group shows it in its header; a later `computer_use` run takes it over; the preview leaves when the reply ends; nothing shows while the screen is not running; method-not-found shows nothing.
- [ ] 2.2 Pass the preview from `chat_builders.dart`; verify 2.1 passes.

## 3. Demand and tap

- [ ] 3.1 Write failing widget tests: a preview scrolled into the cache extent but off screen holds no watch and causes no `display.thumbnail` request; one on screen does; tapping it opens the Activity panel and a second tap leaves it open; with the inspector already open a tap keeps it open.
- [ ] 3.2 Add `visibility_detector`, the binding and `_openActivity`; verify 3.1 passes.

## 4. Observability

- [ ] 4.1 Write failing tests: `bot_screen.preview.shown` is recorded once per reply, `bot_screen.preview.tapped` once per tap, both without attributes; the thumbnail span carries `watchers` equal to the visible surfaces. Implement and verify.

## 5. Docs and skills

- [ ] 5.1 Extend `CLAUDE.md`'s Bot Screen paragraph (where the transcript preview sits, on-screen demand, the open-only action), and give the reason for `visibility_detector` in the PR description, as CLAUDE.md's Dependencies section asks.
- [ ] 5.2 No skill change.

## 6. Verify

- [ ] 6.1 Run format, analyze and the full test suite, all clean.
- [ ] 6.2 Run `verify-in-app` per the `verify-bot-screen` skill: start a `computer_use` turn on the container backend, screenshot the preview on a single call and in a folded group, tap it and screenshot the opened panel.
