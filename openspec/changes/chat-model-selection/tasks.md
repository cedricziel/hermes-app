# Tasks

One PR, `feat(chat)`, about 500 changed lines. No telemetry to add (see proposal). No API route change, so no OpenAPI regeneration.

## 1. Model options

- [ ] 1.1 Write a failing test for parsing the `/api/model/options` answer (junk rows, unauthenticated provider, missing `reasoning`), then extend `lib/src/models/model_provider_option.dart` until it passes
- [ ] 1.2 Add a profile-scoped model options repository over the generated client, tested against `FakeHermesServer`
- [ ] 1.3 Add the options shape to `test/real_backend_contract_test.dart` and verify it skips without `HERMES_DEV_URL`

## 2. Sending the choice

- [ ] 2.1 Write failing gateway transport tests: overrides on `session.create`, `config.set` on resume only when the choice changed, nothing sent without a choice; then add the choice to `ChatTransport.send` and `HermesGatewayTransport` until they pass
- [ ] 2.2 Update `test/support/fake_chat_transport.dart` and every other `ChatTransport` implementer, verified by `flutter analyze`

## 3. Pill and picker

- [ ] 3.1 Add Widgetbook use cases for the pill (default, with effort, long id, no effort) and the picker (grouped providers, effort shown and hidden) in both themes, and verify `test/widgetbook_test.dart` passes
- [ ] 3.2 Remove the unused #281 preview widgets, their use cases and tests, verified by `flutter analyze`
- [ ] 3.3 Write a failing widget test that picking a model updates the pill and the next send carries it, then wire the pill into the composer and chat screen (load per profile, hide on failure, reset on profile switch) until it passes

## 4. Docs and verification

- [ ] 4.1 Update the Chat paragraph in `CLAUDE.md` and any stale `.claude/skills` entry (none expected)
- [ ] 4.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and check the pill and picker in the running app with the `verify-in-app` skill against a dev backend
