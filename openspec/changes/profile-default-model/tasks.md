# Tasks

One PR, `feat(profiles)`, about 400 changed lines. No telemetry to add (see proposal). No API route change, so no OpenAPI regeneration.

## 1. Repository

- [x] 1.1 Write a failing `FakeHermesServer` test that `setModel` sends `PUT /api/profiles/{name}/model` with `{provider, model}` and an encoded name, then add it to `HermesProfilesRepository` until it passes
- [x] 1.2 Add the update's answer to `test/real_backend_contract_test.dart` (writing the current model back) and verify it skips without `HERMES_DEV_URL`

## 2. Picker and row

- [ ] 2.1 Write a failing widget test that the picker without effort shows no effort levels, its title and note, and reports a pick without effort; then add `withEffort`, `title` and `note` to `ModelPicker`/`showModelPicker` until it passes, and verify `test/composer_model_pill_test.dart` still passes
- [ ] 2.2 Add Widgetbook use cases for the picker without effort and for the profile row (active, inactive, no model, long text), pulling the row into `lib/src/profiles/widgets/profile_tile.dart`, and verify `test/widgetbook_test.dart` passes

## 3. Profiles screen

- [ ] 3.1 Write failing `test/profiles_screen_test.dart` cases: picking a model sends the PUT and reloads, picking the current one sends nothing, a refused save and failed options say so, the active profile is unchanged; then wire the button into `ProfilesScreen` until they pass

## 4. Docs and verification

- [ ] 4.1 Update `CLAUDE.md` if it describes the profiles screen, and any stale `.claude/skills` entry (none expected)
- [ ] 4.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, check the workflow screenshots of the Profiles screen, and run `verify-in-app` when `hermes` is on PATH
