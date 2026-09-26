## 1. Queue in the controller

- [x] 1.1 Write failing tests: a send during a reply is queued and the composer is cleared; the first queued prompt is sent when the reply completes, then the next; a follow-up turn is waited for; a stopped or failed reply pauses the queue; "Send now" resumes it; a send on a paused queue joins its end; removing a queued prompt; another thread is unaffected
- [x] 1.2 Queue in `ChatController.submit` and send the next prompt when a reply ends normally (`feat(chat)`)

## 2. Queue UI

- [x] 2.1 Add the `QueuedPrompts` widget with Widgetbook use cases (running, paused, with attachments) and a widget test
- [x] 2.2 Show it in the composer and change the hint while replying

## 3. Spec, telemetry and skills

- [x] 3.1 Sync the delta into `openspec/specs/chat/spec.md` and archive the change
- [x] 3.2 Telemetry: none, nothing to add
- [x] 3.3 No `.claude/skills` entry is made stale by this change

## 4. Verify

- [x] 4.1 Run `dart format`, `flutter analyze` and `flutter test`
- [x] 4.2 Verify in the running app: not run, no Hermes dev backend is available in this environment. The chat workflow test captures the queue on phone and desktop, light and dark
