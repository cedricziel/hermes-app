# Tasks

This work fits in two PRs of about 300 changed lines each. PR 1 (groups 1–2) changes the widget and the pure builder and keeps today's behaviour, because the screen only ever passes generic prompts. PR 2 (groups 3–5) loads the context and wires in the actions.

## 1. Prompt model and builder (PR 1, `feat(chat): …`)

- [x] 1.1 Write failing unit tests in `test/starter_prompts_test.dart` for `buildStarterPrompts`: an empty context gives the four generic prompts with action `send`; a full context gives job, Kanban, chat and skill prompts in that order with the spec's wording and actions (`prefill`, `prefill`, `openThread` with the thread id, `prefill`); a partial context puts contextual prompts first and pads with generics; a review task gets the "What's left before…" wording; a name longer than 60 characters is cut with "…"
- [x] 1.2 Add `StarterPrompt`, `StarterSource`, `StarterAction`, `StarterContext` and `buildStarterPrompts` in `lib/src/chat/starter_prompts.dart`, and move `kStarterPrompts` there from `mock_chat_data.dart` with the generic wording from design.md; verify 1.1 passes

## 2. Welcome view (PR 1)

- [x] 2.1 Extend `test/welcome_view_test.dart` (failing first): `WelcomeView` renders the given prompts in order with each source's icon (a lightbulb for generic), and tapping a card calls `onPick` with that `StarterPrompt`; keep the existing width tests
- [x] 2.2 Add Widgetbook use cases in `widgetbook/chat_use_cases.dart` before wiring: "Generic prompts" (no context), "Full context" (all four sources, long task title), "Kanban off" (job, chat, skill, one generic), with and without a greeting name; check them in both themes at phone and desktop width (component-catalog skill); verify `flutter test test/widgetbook_test.dart` passes
- [x] 2.3 Change `WelcomeView` to take `List<StarterPrompt> prompts` and `ValueChanged<StarterPrompt> onPick` and show the source icon on each card; thread the list through `buildChatBuilders`; in `ChatScreen` pass the generic prompts and handle `send` as today; verify 2.1 and the existing tests that tap `kStarterPrompts.first` pass

## 3. Context loader (PR 2, `feat(chat): …`)

- [x] 3.1 Write failing tests in `test/starter_context_loader_test.dart` against `FakeHermesServer`: it picks the failed job with the latest `last_run_at`; it skips `/api/plugins/kanban/board` when `/api/dashboard/plugins` has no enabled `kanban`; it picks a blocked task over a review task; it picks the enabled skill with the highest `usage` above zero; a 500 or a timeout on one route leaves that field null and keeps the others
- [x] 3.2 Implement `StarterContextLoader` in `lib/src/chat/starter_context_loader.dart` using `HermesRepositories` (`cron`, `plugins`, `kanban`, `skills`) with parallel calls, a timeout per call and errors swallowed per source; verify 3.1 passes

## 4. Wiring into the chat screen (PR 2)

- [x] 4.1 Write failing chat screen tests against `FakeHermesServer` (in `test/chat_screen_hermes_test.dart`): with a failed job and a used skill on the server, the welcome view first shows generics and then the job prompt, the recent-chat prompt and the skill prompt; tapping the job prompt puts its text in the composer and sends nothing; tapping "Pick up '<title>'" opens that thread; switching profile reloads the context for the new profile; a load that finishes after a profile switch is discarded
- [x] 4.2 In `ChatScreen` state, load the context for the active profile, keep it with its profile and time, reload it on profile change or when the welcome view is shown and the load is more than five minutes old, pick the recent thread from `ChatController.threads` (titled, not the one on screen), and handle `prefill` (set `_composerController.value`, cursor at end) and `openThread` (select through `ChatController`); verify 4.1 passes
- [x] 4.3 Telemetry: none, as the proposal says; confirm no span or log event was added

## 5. Screenshots, skills and verification (PR 2)

- [x] 5.1 Give the fake server in `test/workflows/chat_workflow_test.dart` a failed job, a used skill and an earlier chat so the `welcome` screenshot shows contextual prompts; run the workflow and look at `build/workflow_screenshots/` on phone and desktop in both themes (workflow-screenshots skill)
- [x] 5.2 Check that the store `welcome` screenshot (`scripts/store-screenshots.sh`, dev backend with seeded chats) still looks deliberate now that the prompts depend on the backend's jobs, chats and skills; if the seeding has to change, record it in `.claude/skills/store-screenshots/SKILL.md`
- [x] 5.3 Update `CLAUDE.md`'s Chat section with one line on where starter prompts come from
- [ ] 5.4 Verify: `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test` pass, then run the verify-in-app loop against `scripts/dev-backend.sh` with a failing cron job and check the welcome view on macOS, including the prefill and open-chat taps
