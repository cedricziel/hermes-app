# Tasks

One PR, `feat(bot-screen): show the bot's screen in the Activity panel`, about 500 changed lines including the catalog use cases and the `design/web` component. Depends on `bot-screen-status`.

## 1. Card model

- [ ] 1.1 Write failing tests for `BotScreenCardModel.from`: the state order (not offered → not installed → blocked → starting → off → error → frame or suppressed); not installed with sandbox placement carries no command; blocked carries the memory figure only when `memory_available_mb` is present.
- [ ] 1.2 Implement the model; verify 1.1 passes.

## 2. Catalog first

- [ ] 2.1 Build `BotScreenCard` in `lib/src/bot_screen/widgets/` with Widgetbook use cases in `widgetbook/bot_screen_use_cases.dart` for every state (Hermes in control with a frame, someone else in control, off, off after a failed start, starting, error, not installed with a command, not installed in a sandbox, blocked with and without memory, not offered) and Enlarge shown and hidden; phone and desktop width; Apple and Material; both themes. Verify `flutter test test/widgetbook_test.dart` passes.
- [ ] 2.2 Add `design/web/src/components/BotScreenCard/` and `design/web/docs/BotScreenCard.md` (`category: Agent activity`), export it from `src/index.ts`, and verify `cd design/web && npm ci && npm run build` passes.

## 3. Wiring

- [ ] 3.1 Write failing widget tests: with a running screen Now lists the card with a frame and the strip shows nothing for it; with a stopped screen and no `computer_use` call nothing is listed; method-not-found lists nothing; closing the panel, hiding the inspector, a non-resumed lifecycle, App Lock and (macOS) a windowless app stop the polling and drop the frame; switching to a chat of another profile shows that profile's screen; Start Screen sends `display.start`; a conversation window's panel shows no card.
- [ ] 3.2 Own the controller in `ChatScreen`, pass it to `BoundActivityPanel` from the inspector and the phone sheet, add `ActivityKind.screen`, and drive the gates; verify 3.1 passes.

## 4. Observability

- [ ] 4.1 Write failing tests with a recording event logger and breadcrumbs: Start Screen logs `bot_screen.start` with `outcome` only; `bot_screen.card.shown` is recorded once per state change and not per refreshed frame; `bot_screen.start.pressed` has no attributes. Implement and verify.

## 5. Docs and skills

- [ ] 5.1 Extend `CLAUDE.md`'s Bot Screen paragraph: the card in Now, when it is listed, the polling gates, and that conversation windows and the quick panel show none. Add a Bot screen step to the chat workflow test (`test/workflows/`) and check the screenshots per the `workflow-screenshots` skill.
- [ ] 5.2 No skill change beyond `verify-bot-screen` from `bot-screen-status`; amend it if the card's check needs a step it lacks.

## 6. Verify

- [ ] 6.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all clean.
- [ ] 6.2 Following the `verify-bot-screen` skill, run the macOS app against the container backend with a started screen, open the Activity panel and screenshot the card running, then stop the screen and screenshot Off.
