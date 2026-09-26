# Tasks

One PR, `feat(kanban)`, under 500 changed lines. No telemetry to add (see proposal). No API route change, so no OpenAPI regeneration.

## 1. Options and create request

- [x] 1.1 Write a failing test that `ModelOptions.fromJson` reads the plugin's `label` and offers `minimal` to `ultra` without capabilities, then extend the parser
- [x] 1.2 Write failing `FakeHermesServer` tests for `KanbanRepository.loadModelOptions` (shape, failure as empty) and for `createTask` sending the pair, the effort and a bare model name, then add them
- [x] 1.3 Add the model-options shape to `test/real_backend_contract_test.dart` and verify it skips without `HERMES_DEV_URL`

## 2. Picker and form

- [x] 2.1 Pass the picker's optional default entry through the pill, with Widgetbook use cases (pill on the default, picker with the entry) in both themes, and verify `test/widgetbook_test.dart` and the chat pill tests pass
- [x] 2.2 Write a failing widget test that picking a model and effort in the create form sends them, the default entry sends none, and an empty list shows the text field; then wire the row into `KanbanCreateScreen`

## 3. Docs and verification

- [x] 3.1 Update the Kanban notes in `CLAUDE.md` if stale, and any `.claude/skills` entry the change makes stale (none expected)
- [x] 3.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, look at the Kanban workflow screenshots, and run `verify-in-app` when `hermes` is on PATH
