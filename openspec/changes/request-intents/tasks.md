# Tasks

One PR, `feat(ios): list pending requests and answer approvals from Siri and Shortcuts`. Needs PR #587, `headless-runtime`, `background-refresh`, `surface-snapshot`, `app-intents` and `ask-hermes-intent` merged. No API routes change, so no OpenAPI regeneration.

## 1. Gateway calls (TDD)

- [ ] 1.1 Confirm PR #587's `answerOpenRequest`, `OpenRequestAnswer` and `RequestAnswerSender` are on main; answering uses them only.
- [ ] 1.2 Write failing transport tests with scripted RPC answers: `pendingApprovals` finds the live session by `session_key` through `session.active_list` and returns `approval.pending`'s rows (none when the session is not live, malformed rows skipped); implement on `HermesGatewayTransport` and `FakeChatTransport`; verify.
- [ ] 1.3 Add a case to `test/real_backend_contract_test.dart` (behind `HERMES_DEV_MODEL_CALLS=1`) that raises an approval, finds it by `session_key` with `approval.pending`, and answers it with `answerOpenRequest`; run it against `scripts/dev-backend.sh`.

## 2. Intents in Dart (TDD)

- [ ] 2.1 Write failing tests in `test/intents/request_intents_test.dart`: `pending` returns the fresh snapshot's rows (profile filter, oldest first, no `url`), each `HeadlessOutcome` (signed out, locked, unreachable: stored-list fallback or the matching sentence), count only with App lock on; `approvalDetail` returns command, description and choices or `gone`; `answerApproval` answers through `RequestAnswerSender`/`answerOpenRequest` and refreshes the snapshot, `gone` when nothing was waiting, and each non-`HeadlessDone` outcome sends nothing; implement `lib/src/intents/request_intents.dart` and the two channel methods; verify.

## 3. Swift intents

- [ ] 3.1 Write failing `swift test` cases for `PendingRequestEntity` (approvals only, oldest first, profile filter, id round trip), the spoken list (five entries, "and N more", none, "As of" fallback, count only) and the choice handling (offered, not offered, missing); implement the entity, `ApprovalChoice`, `PendingRequestsIntent` and `AnswerApprovalIntent` (`requiresAuthentication`, `requestDisambiguation`, `requestConfirmation` with the command), and the phrases; verify `swift test` and `flutter build ios --simulator -d <udid>`.

## 4. Telemetry

- [ ] 4.1 Write failing tests with a recording tracer, event logger and breadcrumb trail for each outcome of both intents, checking the attributes listed in the spec and that no command, title, profile or id is recorded; implement; verify.

## 5. Docs and skills

- [ ] 5.1 Extend the CLAUDE.md "App Intents" paragraph and the `verify-in-app` skill's intents section with the two intents and how to raise an approval on the dev backend to try them.

## 6. Verify

- [ ] 6.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test` and `swift test` in `ios/HermesSurfaceKit`; all pass.
- [ ] 6.2 In the iOS simulator against `scripts/dev-backend.sh` with `HERMES_DEV_MODEL_CALLS=1`: raise an approval, run "Pending Requests" from Shortcuts with the app killed, then "Answer Approval" with and without a Choice, with a choice not offered, and after answering in the app; check the chat continues and the request leaves the list. Restore the `ios/`/`macos/` Xcode files the build rewrites, staging files by name.
