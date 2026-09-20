## 1. Block sending while a reply is pending

- [ ] 1.1 Write failing tests in `test/chat_one_turn_test.dart`: blocked while streaming, blocked while a request is pending, allowed after completion, allowed after a broken stream, other thread unaffected, composer text kept
- [ ] 1.2 Refuse the send in `_send` in `lib/src/chat/chat_screen.dart` and show the message, keeping the composer
- [ ] 1.3 Complete the first reply in existing tests that sent twice on one thread while it was pending

## 2. Spec, telemetry and skills

- [ ] 2.1 Sync the delta into `openspec/specs/chat/spec.md` and archive the change
- [ ] 2.2 Telemetry: none, nothing to add
- [ ] 2.3 No `.claude/skills` entry is made stale by this change

## 3. Verify

- [ ] 3.1 Run `dart format`, `flutter analyze` and `flutter test`
- [ ] 3.2 Verify in the running app: with a dev backend, send twice quickly on one thread and see the snackbar. Otherwise the widget tests are the evidence
