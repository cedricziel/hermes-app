# Tasks

Three PRs in order; each starts behaviour work with a failing test. No API routes change, so no OpenAPI regeneration. Everything it builds on is on main (#587/#589, #914, `headless-runtime`, `deep-links`, `ask-hermes`, `background-refresh`). No Android, Windows or Linux work.

## 1. Design record (this PR)

- [x] 1.1 Proposal, design and spec checked against the code on main and `openrpc/HERMES_REF` (`queued` on `prompt.submit`, its four statuses, `request.answer` untouched); stale claims fixed (category already exists, Android reason, App Lock, prefill key, lost-answer ending).
- [x] 1.2 Claude Design pass (https://claude.ai/artifact/NdpCnxunitd6yWpb5V7peG, private): canvas and decisions in `docs/design-briefs/notification-inline-reply.md`, "Design (done)".

## 2. PR 1: the catalog and the plain models (`feat(notifications): model the reply action and its endings`)

- [ ] 2.1 Catalog first (`component-catalog` skill). Change `NotificationsDialog` only: add its footnote ("On iPhone and Mac you can reply to a finished reply from its notification. Not while App Lock is on.") as a use case state in `widgetbook/`, in both themes, phone and Mac width, at the largest text size. No new widget: the notification is system UI and the prefilled composer is the existing `ChatComposer`. Verify `flutter test test/widgetbook_test.dart` (one run at a time, `-j 1`).
- [ ] 2.2 Write failing tests, then implement in `request_notifications.dart`: `replyReadyActionCategory` (`hermes.reply.ready.reply`) with the text action `hermes.action.reply-chat` ("Reply", "Send", "Reply to Hermes", `authenticationRequired`, no `foreground`), `RequestAction.buttonTitle` and `placeholder`, the category in `staticRequestCategories()`, and in `attentionFor` the category choice (completed reply, chat target, notifications on, App Lock off only) plus the `'y'` marker and title in the payload. Check `registerCategoriesNatively` and both Runners take it without a change.
- [ ] 2.3 Write failing tests, then implement: `targetFromPayload` reads the `'u'` draft into a chat target with a draft; the shell tap opens it with the text in the composer, unsent (`OpenRequests.request(prompt:, fromLink: true)`); `withdrawAnswerable` also withdraws notifications with the `'y'` marker when App Lock turns on.
- [ ] 2.4 Update `docs/architecture/notifications-and-background.md` (the reply action, App Lock, what is kept) and the `verify-in-app` skill (how to reply to a notification in the simulator with the app killed). Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`.

## 3. PR 2: the send path (`feat(notifications): reply to a finished reply from the notification`)

- [ ] 3.1 Write failing tests in `test/notifications/inline_reply_test.dart` with `FakeChatTransport` behind a fake `HeadlessHermes` and a recording notification service, then implement `lib/src/notifications/inline_reply.dart`:
  - text sent once, exactly as typed, to the payload's chat and profile with `queued: true`; empty and whitespace input, a job target and a payload without `'y'` send and post nothing;
  - App Lock on at arrival: no request, no storage, "Open Hermes to reply." under "Hermes", `locked`;
  - answer inside the window announced (`answered`); window over: no "Reply failed" when the transport closes, the chat recorded in `RunningReplies` with `fromAsk` (`sent`);
  - `HeadlessSignedOut`, `HeadlessLocked`, `HeadlessUnreachable`, `ProfileUnavailableException` and `QueueSubmissionNotStarted` each post "Reply not sent" (`unavailable` or `failed`), without the text in title or body, replacing the chat's notification, with no retry;
  - text of 120 characters or fewer is kept in the payload `'u'` and restored unsent; longer text is not kept and the body says to write it again; nothing is kept for `unconfirmed`, `locked` or `sent`;
  - error or timeout after the prompt RPC began and before any status: "Couldn't confirm your reply was sent. Open Hermes to check." (`unconfirmed`), nothing resent;
  - a reply never reaches `answerRequestInBackground`'s request path, and `request.answer`, `approval.respond` and `clarify.respond` are never called;
  - the stored session is never cleared by any outcome.
- [ ] 3.3 Write failing tests, then wire it: a branch for `kReplyChatAction` in `routeAnswer` and `LoneAnswerer` (one chain with answers) and in `LocalNotificationService._onResponse`, before `answerFromResponse`; the hand-off still offers, then confirms.
- [ ] 3.4 Write failing tests with a recording tracer, event logger and breadcrumb trail for each outcome (`answered`, `sent`, `failed`, `unavailable`, `unconfirmed`, `locked`): span `background.task` (`task: notification.reply`, `outcome`, `engine`), log `notification.reply` (`outcome`, `route`), breadcrumb; no text, title, profile or id anywhere. Implement.
- [ ] 3.5 Extend `test/real_backend_contract_test.dart` (skips without `HERMES_DEV_URL`): `session.resume` then `prompt.submit` with `queued: true` on an idle chat and on a running one, and check the `status` values. Paid-provider turns need `HERMES_DEV_MODEL_CALLS=1`; the scripted loopback model needs none.
- [ ] 3.6 Update `docs/architecture/notifications-and-background.md` and CLAUDE.md's Notifications line. Run `dart format`, `flutter analyze`, `flutter test`.

## 4. Verify on a device (blocked on a device; record in the roadmap's Blocked table)

- [ ] 4.1 iOS simulator against `scripts/dev-backend.sh` (`HERMES_DEV_MODEL_CALLS=1`): let a reply finish with the app in the background, reply from the notification, see the answer arrive as a notification and in the chat; repeat with the app killed; stop the backend and reply to see "Reply not sent", tap it and see the text restored; turn App Lock on and see the action gone, and reply from a stale notification to see "Open Hermes to reply.". Restore the `ios/` and `macos/` Xcode files the build rewrites and stage files by name.
- [ ] 4.2 macOS with the app running, hidden and not running.
- [ ] 4.3 On an iPhone: unlock requirement on the Lock Screen, the background engine finishing `prompt.submit` inside the window, VoiceOver reading of the action, Dynamic Type at the largest size.
