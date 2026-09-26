## 1. Queue in the controller

- [ ] 1.1 Write failing tests: a send during a reply is queued and the composer is cleared; the first queued prompt is sent when the reply completes, then the next; a follow-up turn is waited for; a stopped or failed reply pauses the queue; "Send now" resumes it; a send on a paused queue joins its end; removing a queued prompt; another thread is unaffected
- [ ] 1.2 Queue in `ChatController.submit` and send the next prompt when a reply ends normally (`feat(chat)`)

## 2. Queue UI

- [ ] 2.1 Add the `QueuedPrompts` widget with Widgetbook use cases (running, paused, with attachments) and a widget test
- [ ] 2.2 Show it in the composer and change the hint while replying

## 3. Spec, telemetry and skills

- [ ] 3.1 Sync the delta into `openspec/specs/chat/spec.md` and archive the change
- [ ] 3.2 Telemetry: none, nothing to add
- [ ] 3.3 No `.claude/skills` entry is made stale by this change

## 4. Verify

- [ ] 4.1 Run `dart format`, `flutter analyze` and `flutter test`
- [ ] 4.2 Verify in the running app, or state why it was not run
