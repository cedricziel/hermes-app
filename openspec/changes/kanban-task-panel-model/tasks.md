# Tasks

One PR, `feat(kanban)`, under 500 changed lines. No telemetry to add (see proposal). No API route change, so no OpenAPI regeneration.

## 1. Data

- [ ] 1.1 Write a failing test that a task row reads `model_override`, `provider_override` and `reasoning_effort` (and keeps them on `withStatus`), then add the fields
- [ ] 1.2 Write failing `FakeHermesServer` tests that `updateTask` sends a model pair, an effort and the clear flags, and `bulkUpdate` sends `reasoning_effort` and `clear_reasoning_effort`; then add the parameters
- [ ] 1.3 Extend the contract test's task lifecycle: a task patched with an override reports it back, verified to skip without `HERMES_DEV_URL`

## 2. Task panel

- [ ] 2.1 Add the Model section to `KanbanTaskFields` with Widgetbook use cases (profile default, model with effort, effort only) in both themes, and verify `test/widgetbook_test.dart` passes
- [ ] 2.2 Write failing controller and panel tests: one patch when the picker closes with a new pick, the clear flags for "Profile default", nothing when unchanged, the text prompt when no models are listed; then add `KanbanTaskController.setModel` and wire the section

## 3. Bulk edit

- [ ] 3.1 Add the Effort action to `KanbanBulkBar`, with its Widgetbook use case at phone width, and verify no overflow
- [ ] 3.2 Write a failing screen test that bulk Effort sends the level for the selected ids, then wire it through `KanbanBoardController.bulkUpdate` and `KanbanScreen`

## 4. Docs and verification

- [ ] 4.1 Update the Kanban note in `CLAUDE.md` and any stale `.claude/skills` entry (none expected)
- [ ] 4.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, look at the Kanban workflow screenshots, and run `verify-in-app` when `hermes` is on PATH
