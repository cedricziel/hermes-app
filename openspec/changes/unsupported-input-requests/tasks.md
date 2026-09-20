## 1. Request model, event and reply folding

- [ ] 1.1 Failing tests in `test/chat_reply_test.dart`: an unsupported request is added pending, and expires with the turn
- [ ] 1.2 Add `UnsupportedKind` and `UnsupportedRequest` to `chat_models.dart`, the `UnsupportedRequested` event to `chat_transport.dart`, and fold it in `chat_reply.dart`

## 2. Gateway mapping

- [ ] 2.1 Failing tests in `test/hermes_gateway_transport_test.dart`: `secret.request`, `sudo.request`, and both expire events; the mapped request carries only the id and the kind
- [ ] 2.2 Map the four events in `HermesGatewayTransport`

## 3. Card, chat screen and notification

- [ ] 3.1 Failing tests: `test/unsupported_request_card_test.dart`, `test/chat_builders_test.dart`, `test/chat_input_request_test.dart` (card shown, no thinking indicator, locks on expiry), `test/attention_policy_test.dart` (body, and none while watching the thread)
- [ ] 3.2 Add `UnsupportedRequestCard`, route it in `chat_builders.dart`, handle the event in `chat_screen.dart`
- [ ] 3.3 Add `kNeedsYouBody` and the `UnsupportedRequested` case to `attention_policy.dart`

## 4. Docs, skills and telemetry

- [ ] 4.1 Update `PRIVACY.md`, which says what notifications show
- [ ] 4.2 Check `.claude/skills` for anything stale: nothing names the request kinds
- [ ] 4.3 Telemetry: none

## 5. Verify

- [ ] 5.1 Run `dart format`, `flutter analyze` and `flutter test`
- [ ] 5.2 Verify in the running app: not possible on demand, because a model asking for a secret or a sudo password is nondeterministic and costs a model call. The unit and widget tests are the evidence
- [ ] 5.3 Sync the delta specs into `openspec/specs/`, run `openspec validate --strict` and `--specs`, and archive the change
