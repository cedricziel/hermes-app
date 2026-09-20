## 1. Repository

- [ ] 1.1 Failing tests against `FakeHermesServer` for `HermesSkillsRepository`: list parsing (skipped rows, missing category, unknown provenance treated as bundled), toggle, read content, save and create including a 400 with `detail`, and 404 on the list
- [ ] 1.2 Implement `lib/src/skills/hermes_skills_repository.dart` over `authController.api!.raw` with lenient parsing and typed errors carrying the server's `detail`

## 2. Controller

- [ ] 2.1 Failing tests for `SkillsController`: grouping and ordering (Other last), search, source and Enabled filters, profile switching reloads without touching the chat's profile, optimistic toggle with rollback, serialised toggles per skill
- [ ] 2.2 Implement `SkillsController` (selected profile, list state, filters, toggle)

## 3. Installed page and entry point

- [ ] 3.1 Failing widget tests: loading, list, empty, no match with "clear filters", error with Retry, "not supported" on 404, profile chip picker and its fallback when profiles fail
- [ ] 3.2 Implement the Skills page (Installed content, search, chips, rows, profile chip) with no tab bar until the hub change adds Discover
- [ ] 3.3 Failing test then implementation: Skills entry in the chat sidebar next to Profiles and Bots, shown only with a dashboard connection

## 4. Detail and editing

- [ ] 4.1 Failing widget tests: detail load, error with Retry, actions by provenance
- [ ] 4.2 Implement the detail page rendering `SKILL.md` with `gpt_markdown`
- [ ] 4.3 Failing widget tests: editor dirty tracking and discard prompt, Save disabled when unchanged, failed save keeps text and shows the reason, create flow with template and disabled Save without a name
- [ ] 4.4 Implement the editor (Edit / Preview toggle, insert buttons) for edit and create, wired to save and create

## 5. Ask the agent to delete

- [ ] 5.1 Failing test: confirming returns a drafted message to the chat, which appends it to the composer above an existing draft and sends nothing
- [ ] 5.2 Implement the confirm dialog, the result passed back through the routes, and the chat handling

## 6. Contract, telemetry, docs

- [ ] 6.1 Add list, content and toggle shape checks to `test/real_backend_contract_test.dart`
- [ ] 6.2 Add the spans and log events named in the proposal, using `safely`, with no skill names or content; test that a telemetry failure does not break a toggle
- [ ] 6.3 Update `.claude/skills/verify-in-app` if the loop needs a step for the Skills page, and note the new page in `CLAUDE.md` architecture if it names the sidebar pages

## 7. Verify

- [ ] 7.1 `dart format .`, `flutter analyze`, `flutter test`
- [ ] 7.2 verify-in-app against the dev backend (`scripts/dev-backend.sh`): list, toggle, edit, create, ask-agent-to-delete on a wide and a narrow window
