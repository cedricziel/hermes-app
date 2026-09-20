## 1. Schedule codec

- [x] 1.1 Add `ScheduleSpec` with `toSchedule`, `fromJob` and `nextRuns`, and tests for each mode, the round trip and the fallback to Cron

## 2. Repository

- [x] 2.1 Add create, update, blueprints, instantiate and delivery targets to `HermesCronRepository`, with lenient blueprint parsing
- [x] 2.2 Add repository tests, including 400 and 422 handling
- [x] 2.3 Add blueprints and a create, edit and delete round trip to the real-backend contract test

## 3. Controller

- [x] 3.1 Add `ScheduleEditorController`: draft state, validation, diff for edit, save guard against double taps, server errors kept on the form
- [x] 3.2 Add controller tests: validation messages, edit sends changes only, clearing a field, refusal keeps values

## 4. Screens

- [x] 4.1 Add the gallery with search and category chips, and the "New" action on the list
- [x] 4.2 Add the blueprint form rendered from slots
- [x] 4.3 Add the job form, the schedule picker with preview, the delivery field and the Advanced section, and the "Edit" action on the detail
- [x] 4.4 Add the unsaved changes confirmation
- [x] 4.5 Add screen tests for the gallery, both forms and the leave confirmation

## 5. Finish

- [x] 5.1 Run `dart format`, `flutter analyze` and `flutter test`
- [x] 5.2 Try creating, editing and deleting a job against the dev backend: the contract test creates, edits by diff, clears a field and deletes jobs, and creates one from a blueprint, all against a live Hermes
- [x] 5.3 Validate the change with `openspec validate`
