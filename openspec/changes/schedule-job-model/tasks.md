# Tasks

One PR, `feat(schedules)`, under about 500 changed lines. No telemetry to add (see proposal). No API route change, so no OpenAPI regeneration.

## 1. Picker options

- [x] 1.1 Make `ModelPicker` and `showModelPicker` able to hide effort (`withEffort`) and offer a checked "Use the profile's default" entry (`onUseDefault`), with widget tests; the chat pill tests stay green (landed on the base branch as `e08c7c9`)
- [x] 1.2 Add Widgetbook use cases for the picker without effort and with the default entry, both themes, and verify `test/widgetbook_test.dart` passes (landed with 1.1)

## 2. Job model field

- [x] 2.1 Add `JobModelField` with Widgetbook use cases (profile default, listed model, model not in the list, model without a provider, list unavailable), both themes, phone and desktop width
- [x] 2.2 Write failing tests against `FakeHermesServer` that the form loads the options for the job's profile, sends the picked model and provider on create, sends empty strings when going back to the default on edit, and keeps an unlisted saved model out of the update; then load the options in `JobFormController` and replace the two text fields in `JobFormScreen` until they pass

## 3. Docs and verification

- [x] 3.1 Update the Schedules mention in `CLAUDE.md` if it names the fields, and any stale `.claude/skills` entry (none expected)
- [ ] 3.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, look at the schedules workflow screenshots, and check the form with `verify-in-app` against a dev backend when `hermes` is available. Format, analyze, tests and screenshots done; verify-in-app still open (`hermes` was not on PATH)
