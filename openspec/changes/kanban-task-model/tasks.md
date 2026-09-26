# Tasks

One PR, `feat(kanban)`, under 500 changed lines. No telemetry to add (see proposal). No API route change, so no OpenAPI regeneration.

## 1. Options and create request

- [ ] 1.1 Write a failing test that `ModelOptions.fromJson` reads the plugin's `label` and offers `minimal` to `ultra` without capabilities, then extend the parser
- [ ] 1.2 Write failing `FakeHermesServer` tests for `KanbanRepository.loadModelOptions` (shape, failure as empty) and for `createTask` sending the pair, the effort and a bare model name, then add them
- [ ] 1.3 Add the model-options shape to `test/real_backend_contract_test.dart` and verify it skips without `HERMES_DEV_URL`

## 2. Picker and form

- [ ] 2.1 Add the optional "Profile default" entry to the picker and pill, with Widgetbook use cases (pill on the default, picker with the entry) in both themes, and verify `test/widgetbook_test.dart` and the chat pill tests pass
- [ ] 2.2 Write a failing widget test that picking a model and effort in the create form sends them, "Profile default" sends none, and an empty list shows the text field; then wire the row into `KanbanCreateScreen`

## 3. Docs and verification

- [ ] 3.1 Update the Kanban notes in `CLAUDE.md` if stale, and any `.claude/skills` entry the change makes stale (none expected)
- [ ] 3.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, look at the Kanban workflow screenshots, and run `verify-in-app` when `hermes` is on PATH
