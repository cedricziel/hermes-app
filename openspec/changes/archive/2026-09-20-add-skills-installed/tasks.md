## 1. Repository

- [x] 1.1 Failing tests against `FakeHermesServer` for `HermesSkillsRepository`: list parsing (skipped rows, missing category, unknown provenance treated as bundled), toggle, read content, save and create including a 400 with `detail`, and 404 on the list
- [x] 1.2 Implement `lib/src/skills/hermes_skills_repository.dart` over `authController.api!.raw` with lenient parsing and typed errors carrying the server's `detail`

## 2. Controller

- [x] 2.1 Failing tests for `SkillsController`: grouping and ordering (Other last), search, source and Enabled filters, profile switching reloads without touching the chat's profile, optimistic toggle with rollback, serialised toggles per skill
- [x] 2.2 Implement `SkillsController` (selected profile, list state, filters, toggle)

## 3. Installed page and entry point

- [x] 3.1 Failing widget tests: loading, list, empty, no match with "clear filters", error with Retry, "not supported" on 404, profile chip picker and its fallback when profiles fail
- [x] 3.2 Implement the Skills page (Installed content, search, chips, rows, profile chip) with no tab bar until the hub change adds Discover
- [x] 3.3 Failing test then implementation: Skills entry in the chat sidebar next to Profiles and Bots, shown only with a dashboard connection

## 4. Detail and editing

- [x] 4.1 Failing widget tests: detail load, error with Retry, actions by provenance
- [x] 4.2 Implement the detail page rendering `SKILL.md` with `gpt_markdown`
- [x] 4.3 Failing widget tests: editor dirty tracking and discard prompt, Save disabled when unchanged, failed save keeps text and shows the reason, create flow with template and disabled Save without a name
- [x] 4.4 Implement the editor (Edit / Preview toggle, insert buttons) for edit and create, wired to save and create

## 5. Ask the agent to delete

- [x] 5.1 Failing test: confirming returns a drafted message to the chat, which appends it to the composer above an existing draft and sends nothing
- [x] 5.2 Implement the confirm dialog, the result passed back through the routes, and the chat handling

## 6. Contract, telemetry, docs

- [x] 6.1 Add list, content and toggle shape checks to `test/real_backend_contract_test.dart`
- [x] 6.2 Add the `skills.write` app event named in the proposal (requests are already traced by the Dio interceptor), with no skill names or content; test that a telemetry failure does not break a toggle
- [x] 6.3 Note skills in the `CLAUDE.md` list of repositories over untyped routes; verify-in-app needs no change

## 7. Verify

- [x] 7.1 `dart format .`, `flutter analyze`, `flutter test`
- [x] 7.2 Check the real response shapes against the dev backend (`scripts/dev-backend.sh`) and render the list, detail and editor pages to an image; the running app cannot be clicked through to the sidebar, so the pages are checked with the widget-test fallback
