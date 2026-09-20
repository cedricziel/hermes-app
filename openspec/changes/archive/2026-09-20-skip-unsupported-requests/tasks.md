## 1. Transport

- [x] 1.1 Test first: skipping a server-request secret or sudo request sends a response frame with an empty `value`, and skipping an event-form one calls `sudo.respond` (`password`) or `secret.respond` (`value`) with an empty answer
- [x] 1.2 Test first: a skip for an unknown or ended request sends nothing and reports not accepted, and `status: expired` reports not accepted
- [x] 1.3 Add `skipUnsupported` to `ChatTransport`, the gateway transport and the fake, and register unsupported requests as open in both forms

## 2. Card and screen

- [x] 2.1 Test first: the card shows a Skip button, disables it while in flight, shows "You skipped this request" once skipped, "This request timed out" when expired, and the failure message with the button usable again
- [x] 2.2 Test first: the chat screen sends the skip, records it on the card, and locks the card as expired when the request is no longer pending
- [x] 2.3 Add the Skip button to the card and wire it through the builders and the screen

## 3. Wrap up

- [x] 3.1 Telemetry: none, nothing to add
- [x] 3.2 No `.claude/skills` entry is made stale by this
- [x] 3.3 Sync the delta into `openspec/specs/chat/spec.md` and archive the change
- [x] 3.4 Verify: dart format, flutter analyze, flutter test, `openspec validate --strict`; the new form is not checked against a running gateway, and no verify-in-app run was made
