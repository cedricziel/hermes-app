## 1. Stopped mark

- [x] 1.1 Write failing tests: a stopped reply with text is flagged and shows "Stopped"; a completed one is not; a stopped reply with no text still reads "Stopped." without a second mark
- [x] 1.2 Flag the reply, map it to metadata and show the mark in `MessageActions` (`fix(chat)`)
- [x] 1.3 Widgetbook use cases for the mark

## 2. Queued message in view

- [x] 2.1 Test that a queued message sent after a long reply is in view and its reply is followed

## 3. Spec, telemetry and skills

- [x] 3.1 Sync the delta into `openspec/specs/chat/spec.md` and archive the change
- [x] 3.2 Telemetry: none
- [x] 3.3 No `.claude/skills` entry is made stale

## 4. Verify

- [x] 4.1 Run `dart format`, `flutter analyze` and `flutter test`
