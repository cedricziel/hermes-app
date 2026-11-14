# Tasks

Six PRs, each under about 500 changed lines with tests, merged in order. Each ends with its own verify task. The Claude Design pass (task 3.0) runs from `docs/design-briefs/toolsets.md` between PR 3 and PR 4.

## 1. PR 1 — `feat(tools): read toolsets and their setup`

- [ ] 1.1 Before any code: against `scripts/dev-backend.sh` (`verify-in-app` rules, never the real `~/.hermes`), record real answers for `GET /api/tools/toolsets`, `…/config` for web, browser, image_gen, tts, computer_use and terminal, `…/models` for image_gen, `GET /api/tools/terminal/backends`, `GET /api/tools/computer-use/status`, and one answer each of `PUT` switch, provider, env, model and backend. Check: (a) does a switch reach a chat that is already open, and a resumed one (decides the "next chat" sentence); (b) what a second `post-setup` does while one runs; (c) the catalog's names against the risk table. Write results and the Hermes revision into design.md and adjust this list if they change the work.
- [ ] 1.2 Add the recorded answers as fixtures in `test/tools/` and to `test/support/fake_hermes_server.dart` routes.
- [ ] 1.3 Write failing tests for the parsers: every fixture, rows without a name skipped and counted, non-boolean flags default false, unknown provider status, `available` ignored, random and truncated input never throws. Then implement them (`lib/src/tools/tools_models.dart`).
- [ ] 1.4 Write failing `HermesToolsRepository` tests against `FakeHermesServer` through the real generated client: explicit `profile` on every call, sealed `ToolsResult` for ok, 404/405 unsupported, 400 refused with Hermes' text, other failures, a lost answer as `unknownOutcome`. Then implement it with `forProfile`.
- [ ] 1.5a Write a failing test for `ToolsAvailability`: 404 hides, network failure keeps the previous answer, read on connect and resume, rows handed to the screen. Then implement it and provide it from `AppShell`.
- [ ] 1.5 Add the contract test group in `test/real_backend_contract_test.dart` (skips without `HERMES_DEV_URL`): list shape, config shape, backends, computer-use status, a switch and its read-back on a throwaway profile.
- [ ] 1.6 Write failing tests that `tools.list`, `tools.parse_lenient` carry only counts and outcomes. Then add them.
- [ ] 1.7 Run `/simplify`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all passing.

## 2. PR 2 — `feat(tools): switch toolsets`

- [ ] 2.1 Write failing tests and implement `toolset_risk.dart` (the table, sentences, levels, the test against the recorded catalog).
- [ ] 2.2 Write failing `ToolsController` tests: grouping, optimistic switch with rollback, one write per toolset, read-back after every write, lost answer re-read and never resent, late answers dropped on profile switch and dispose, `post_setup_started` handed on, `404` on write. Then implement it.
- [ ] 2.3 Write failing tests and implement the profile-gone outcome (`404` naming a profile is not "unsupported"), the offline state and `401/403`, and the CI check that every name in the server catalog is in the risk table or an explicit "no risk" list.
- [ ] 2.4 Write failing tests that `tools.toggle`, `tools.toggled` and the breadcrumbs carry only fixed attributes. Then add them.
- [ ] 2.5 Run `/simplify`, format, analyze and the tests.

## 3. PR 3 — `feat(tools): set toolsets up`

- [ ] 3.1 Write failing `ToolsetSetupController` tests: matrix load, provider pick (including web capability and `needs_nous_auth`), key save sends only typed fields and clears them on success, failure and lost answer, clears on background, App Lock, profile switch and dispose, model pick, read-back. Then implement it.
- [ ] 3.2 Write failing tests and implement `ToolsetInstalls` (provided from `AppShell`; `running:false` with a null exit code is unknown) (one per connection, polls `tools-post-setup`, last six lines, exit code result, 22-minute unknown, survives the screen, drops on sign-out) and the Computer use grant follow.
- [ ] 3.3 Write failing `TerminalBackendsController` and `ComputerUseController` tests (read, pick, Local confirmation hook, readiness rows per platform, grant, 404 hides). Then implement them.
- [ ] 3.4 Write failing tests that `tools.setup`, `tools.terminal_backend`, `tools.computer_use`, `tools.toggled`, `tools.setup_outcome` and the breadcrumbs carry only fixed attributes, no key, provider or profile name. Then add them.
- [ ] 3.5 Run `/simplify`, format, analyze and the tests.


## 4. PR 4 — `feat(tools): add the tools widgets`

- [ ] 4.0 Claude Design pass from `docs/design-briefs/toolsets.md`; record the result in `design/web` if it holds the other settings pages.
- [ ] 4.1 Add Widgetbook use cases as plain-model widgets in `lib/src/tools/widgets/`, each in both themes at phone, iPad and desktop width, every state: list (loading, empty, error, grouped, large text), row (off, on, needs setup, risky, unknown toolset), detail (every section, "What's inside" open), provider list (every status chip, Nous note, advanced web), key fields (empty, already set, typed, saving, saved, failed), install progress (running, done, failed, unknown), model list, terminal backends (every status, Local confirmation), computer-use readiness (macOS missing a permission, Linux, unknown, with and without the bot screen link), the four confirmations, the "What's the difference?" sheet and popover.
- [ ] 4.2 Write failing widget tests for the copy (rows, sentences, chips, notes, confirmations, errors) and accessibility (labels, 44 pt targets, large text). Then make them pass.
- [ ] 4.3 Run `/simplify`, format, analyze and the tests (`test/widgetbook_test.dart` builds every use case in both themes).

## 5. PR 5 — `feat(tools): add the Tools screen`

- [ ] 5.1 Write failing screen tests: list and detail (pane at 900 pt, page below), switch with confirmation for the three risky toolsets, setup section, terminal and computer-use sections, hiding on an old server, the footer link and the "What's the difference?" sheet, App Lock and sign-out. Then build `ToolsScreen` on `SettingsScaffold` and `GroupedListView`.
- [ ] 5.2 Wire the entry: sidebar action and drawer More item after MCP servers (`chat_screen_layout.dart`, `thread_sidebar.dart`, `chat_screen_navigation.dart`), the Mac Profiles page section with a lazily read count, ⌘[ Back from the scaffold, hidden without `ToolsAvailability`.
- [ ] 5.3 Wire "Open the bot's screen" through `ChatScreen._openViewer('tools')` and a `BotScreenController` offered check; test that it is absent where there is no controller.
- [ ] 5.4 Add a workflow test in `test/workflows/` (phone and desktop, light and dark): open Tools, switch Web on, set it up with a key, switch Terminal on with the confirmation; look at the screenshots (`workflow-screenshots`).
- [ ] 5.5 Run `/simplify`, format, analyze and the tests.

## 6. PR 6 — `feat(tools): explain the difference and update the guides`

- [ ] 6.1 Add the "What's the difference?" footer link to the Skills, Plugins, MCP servers and Helper models screens, with tests that each shows the same four sentences.
- [ ] 6.2 Update `CLAUDE.md` (a Tools paragraph beside Plugins and MCP servers: repository, controllers, the risk table, secrets, installs, "next chat"), the `verify-in-app` skill (switching a toolset and a key on the dev backend, reading `config.yaml` back) and `design/web` if it has the sibling pages.
- [ ] 6.3 Run `/simplify`, format, analyze and the tests.

## Not verified on a device

- 7.1 `verify-in-app` on macOS against the dev backend: the list for a profile, switch Web and Terminal (confirmation), set up a provider with a throwaway key, read `config.yaml` and `.env` back, a model pick, a terminal backend pick, an install step, the readiness of Computer use on a Linux backend with `verify-bot-screen`, the link to the bot's screen.
- 7.2 iPhone and iPad simulators: layout at the largest text size, VoiceOver order, keys cleared after backgrounding, the pane at iPad width.
- 7.3 Android: the same checks, back gesture, key fields without autofill.
- 7.4 A macOS Hermes server with Computer use: the permission grant opens on the server's Mac, the app follows it to the end.
- 7.5 An old Hermes server without the routes: no Tools anywhere and no error.
