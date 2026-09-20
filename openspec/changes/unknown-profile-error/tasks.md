## 1. Transport

- [ ] 1.1 Failing tests in `test/hermes_gateway_transport_test.dart`: 4064 on `session.create` and on `session.resume` fails the stream with `ProfileUnavailableException`, other errors stay `GatewayRpcException`, and the connection is still usable afterwards
- [ ] 1.2 Add `ProfileUnavailableException` to `chat_transport.dart` and map code 4064 for create and resume in `HermesGatewayTransport`

## 2. Reply and chat screen

- [ ] 2.1 Failing tests in `test/chat_reply_test.dart` and `test/chat_streaming_test.dart`: the failed reply shows the profile message, is marked as an error, is not retried, and the user can send again
- [ ] 2.2 Add `kProfileUnavailableMessage` and a `message` for `failReply` in `chat_reply.dart`; pass the stream error from `chat_screen.dart`

## 3. Docs, skills and telemetry

- [ ] 3.1 Check `.claude/skills` and `PRIVACY.md` for anything stale: nothing names the failure text
- [ ] 3.2 Telemetry: none

## 4. Verify

- [ ] 4.1 Run `dart format`, `flutter analyze` and `flutter test`
- [ ] 4.2 Verify in the running app: needs a Hermes newer than the pinned ref; the unit and widget tests through the fake gateway are the evidence
- [ ] 4.3 Sync the delta specs into `openspec/specs/`, run `openspec validate --strict` and `--specs`, and archive the change
