# Tasks

One PR, `feat(notifications): reply to a finished reply from the notification`. **Starts after PR #587 (actionable notifications) merges**; needs `headless-runtime`, `deep-links` and `ask-hermes-intent` merged (shared use of the turn runner). No API routes change, so no OpenAPI regeneration.

## 1. Send path (TDD)

- [ ] 1.1 Read merged PR #587 and record in design.md the builder, the "Reply ready" category id and the background handler's name; adjust the seams named in design.md, nothing else.
- [ ] 1.2 Write failing tests in `test/notifications/inline_reply_test.dart` with `FakeChatTransport` behind a fake `HeadlessHermes`: text sent once to the payload's chat and profile with `queued: true`; empty input and job targets ignored; answer within the window announced; window over without answer (`sent`) and no "Reply failed" announced when the transport closes; `HeadlessSignedOut`, `HeadlessLocked` and `HeadlessUnreachable` each (`unavailable`), profile gone and send error before acceptance (`failed`) each post "Reply not sent" without the text in its body and with `hermes://chat?profile=&id=&prompt=<text>` (built by `deepLinkUri`) as its tap target; no retry; implement `lib/src/notifications/inline_reply.dart`; verify.
- [ ] 1.3 Write failing tests that the "Reply ready" category built by the peer's builder has the `reply` text action with `authenticationRequired` and no `foreground` option, that only completed-reply notifications use it, and that both the background and the foreground response handlers call `sendInlineReply` for `actionId == 'reply'`; implement; verify.

## 2. Telemetry

- [ ] 2.1 Write failing tests with a recording tracer, event logger and breadcrumb trail for each outcome, checking the attributes in the spec and that no text, title, profile or id is recorded; implement; verify.

## 3. Docs and skills

- [ ] 3.1 Update CLAUDE.md (Notifications: the inline reply, its unlock requirement and the shared turn runner) and the `verify-in-app` skill with how to reply to a notification in the simulator with the app killed.

## 4. Verify

- [ ] 4.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`; all pass.
- [ ] 4.2 In the iOS simulator against `scripts/dev-backend.sh` with `HERMES_DEV_MODEL_CALLS=1`: let a reply finish with the app in the background, reply from the notification, and see the answer arrive as a new notification and in the chat; repeat with the app killed; stop the backend and reply to see "Reply not sent". On macOS, reply with the app running. Restore the `ios/`/`macos/` Xcode files the build rewrites, staging files by name.
