# Tasks

One PR, `feat(settings)`, about 500 changed lines. No telemetry to add (see proposal). No API route change, so no OpenAPI regeneration.

## 1. Auxiliary slots

- [x] 1.1 Write a failing test for parsing the `/api/model/auxiliary` answer (auto slot, pinned slot with effort, junk rows, missing `main`), then add the slot model to `lib/src/models/` until it passes
- [x] 1.2 Write failing `FakeHermesServer` tests for loading the slots of a profile and for assigning a slot (request body, reset to auto, `confirm_required` answer), then add them to `HermesModelsRepository` until they pass
- [x] 1.3 Add the auxiliary shape to `test/real_backend_contract_test.dart` and verify it skips without `HERMES_DEV_URL`

## 2. Picker and list

- [x] 2.1 Give the picker an optional title and "Same as main model" entry, with a failing widget test that picking it reports through its own callback; verify `test/composer_model_pill_test.dart` still passes
- [x] 2.2 Add Widgetbook use cases for the helper model list (auto and pinned rows, saving, unknown main model; the load error uses the catalogued `StateMessage`) and the picker with the "same as main" entry, and verify `test/widgetbook_test.dart` passes in both themes

## 3. Screen

- [x] 3.1 Write failing widget tests for the helper models screen (rows shown, a pick is posted once on close, "same as main" posts auto, nothing posted without a change, confirm dialog declined and accepted, load error with retry), then build the screen until they pass
- [x] 3.2 Add the "Helper models" entry to the sidebar's More section and open the screen on the chat's profile, with a failing test first
- [x] 3.3 Add a helper models step to `test/workflows/management_workflow_test.dart` (phone and desktop) and look at the screenshots

## 4. Docs and verify

- [x] 4.1 Describe the screen in CLAUDE.md's architecture section; no skill is made stale
- [x] 4.2 Run `dart format .`, `flutter analyze` and `flutter test`; run verify-in-app when `hermes` is on PATH, otherwise note it (skipped: `hermes` is not on PATH)
