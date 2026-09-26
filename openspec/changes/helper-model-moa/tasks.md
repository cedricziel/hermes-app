# Tasks

One PR, `feat(settings)`, stacked on `helper-model-settings`, under 500 changed lines. No telemetry to add (see proposal). No API route change, so no OpenAPI regeneration.

## 1. MoA config

- [x] 1.1 Write a failing test for parsing the `/api/model/moa` answer (default preset, a preset named otherwise, disabled advisor, incomplete slots, no presets) and for replacing one slot while keeping the rest, then add the MoA model to `lib/src/models/` until it passes
- [x] 1.2 Write failing `FakeHermesServer` tests for loading the MoA config of a profile and saving it (the PUT body keeps other presets and settings), then add them to `HermesModelsRepository` until they pass
- [x] 1.3 Add the MoA shape to `test/real_backend_contract_test.dart` and verify it skips without `HERMES_DEV_URL`

## 2. List

- [ ] 2.1 Add the MoA section to the helper model list with Widgetbook use cases (default preset, named preset with a disabled advisor, saving), and verify `test/widgetbook_test.dart` passes in both themes

## 3. Screen

- [ ] 3.1 Write failing widget tests (section shown, a pick sends the whole config with one slot changed, rows disabled while saving, 422 keeps the old model, section left out when MoA fails, no `moa` provider in the picker), then wire the section into the helper models screen until they pass
- [ ] 3.2 Extend the helper models step of `test/workflows/management_workflow_test.dart` with the MoA section and look at the screenshots

## 4. Docs and verify

- [ ] 4.1 Update CLAUDE.md's helper models paragraph; no skill is made stale
- [ ] 4.2 Run `dart format .`, `flutter analyze` and `flutter test`; run verify-in-app when `hermes` is on PATH, otherwise note it
