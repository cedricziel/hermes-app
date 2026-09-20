## 1. Block sending while a reply is pending

- [x] 1.1 Write failing tests in `test/chat_one_turn_test.dart`: blocked while streaming, blocked while a request is pending, allowed after completion, allowed after a broken stream, other thread unaffected, composer text kept
- [x] 1.2 Refuse the send in `_send` in `lib/src/chat/chat_screen.dart` and show the message, keeping the composer text and attachments (the composer builder leaves clearing to the screen)
- [x] 1.3 Complete the first reply in existing tests that sent twice on one thread while it was pending

## 2. Spec, telemetry and skills

- [x] 2.1 Sync the delta into `openspec/specs/chat/spec.md` and archive the change
- [x] 2.2 Telemetry: none, nothing to add
- [x] 2.3 No `.claude/skills` entry is made stale by this change

## 3. Verify

- [x] 3.1 Run `dart format`, `flutter analyze` and `flutter test`
- [x] 3.2 Verify in the running app: not run, no dev backend is available to this change. The widget tests are the evidence
