# Design

## Context

See proposal.md for motivation and specs/notifications/spec.md for behavior.

- `flutter_local_notifications` 22.3.1 offers `DarwinNotificationAction.text(id, title, buttonTitle:, placeholder:, options:)` with `DarwinNotificationActionOption.authenticationRequired`, categories registered at initialization, `onDidReceiveNotificationResponse` for responses while the app runs, and `onDidReceiveBackgroundNotificationResponse` (an `@pragma('vm:entry-point')` top-level function) for responses when the app is not running; the response carries `actionId`, `input` and the notification's `payload`.
- PR #587 (actionable notifications, not merged) adds a reusable category builder, categories for requests and the background response handler for its buttons. This change adds one action to the "Reply ready" category through that builder and one branch to its handlers. Names are roles here until the PR merges.
- The payload of a "Reply ready" notification already holds its target (`{t: <thread id>, p: <profile>}`).
- `headless-runtime` provides `withHeadlessHermes`, which returns a sealed `HeadlessOutcome<T>` (`HeadlessDone`, `HeadlessSignedOut`, `HeadlessLocked`, `HeadlessUnreachable`), and its background-engine plugin registration;
- `deep-links` provides `deepLinkUri` and `hermes://chat?profile=&id=&prompt=`, which opens a chat with its composer prefilled and never sends; `ask-hermes-intent` reuses `WatchRequestHandler.handle({'op': 'send', ...})` to send a turn and wait for it, with a gated `announce`.

## Goals / Non-Goals

**Goals:**

- One send path whether the response arrives in the running app or in the background.
- The prompt is sent exactly once per response.

**Non-Goals:**

- Holding the process open until a long reply finishes.

## Decisions

### The action

The builder's "Reply ready" category (iOS and macOS) gains `DarwinNotificationAction.text('reply', 'Reply', buttonTitle: 'Send', placeholder: 'Reply to Hermes', options: {authenticationRequired})`. No `foreground` option, so iOS does not open the app. Only notifications whose body is a completed reply preview or "Reply ready" use the category; "Reply failed", request and task notifications do not get the action.

### One handler for both paths

`sendInlineReply(NotificationResponse response)` in `lib/src/notifications/inline_reply.dart` is called from the peer's background handler and from the foreground response handler when `actionId == 'reply'`. It:

1. Decodes the target from the payload; an empty `input` (whitespace only) or a job target does nothing.
2. Runs `withHeadlessHermes(body, task: 'notification.reply', timeout: 25 s)` and handles every outcome: `HeadlessDone` as below; `HeadlessSignedOut`, `HeadlessLocked` (secure storage not yet readable) and `HeadlessUnreachable` each post "Reply not sent" (`unavailable`).
3. In the body, uses `WatchRequestHandler(repository: ..., transport: hermes.transport, activeProfile: () async => profile)` and `handle({'op': 'send', 'threadId': '<encoded profile>/<thread id>', 'text': input})`, the same way `ask-hermes-intent` does, with `announce` posting every notification it produces (the reply was not shown anywhere else). An answer within the window is announced at once (`answered`).
4. If the window ends first, the body stops waiting; the prompt stays sent (`sent`). From that moment `announce` is muted: closing the transport makes `WatchRequestHandler` announce a failed end, which must not reach the user as "Reply failed". The turn keeps running on the server (sessions are not closed on disconnect), and its end is announced by `background-refresh`'s finished-reply check; `inline_reply.dart` records the chat where that check reads it, as `ask-hermes-intent` does.
5. A failure before Hermes took the prompt (the `send` stream errored before its first event, a `ProfileUnavailableException`, or `ok: false` without `reached`) posts "Reply not sent" (`failed`).

When the running app's engine handles the response, the same function runs in the main isolate, where `withHeadlessHermes` coordinates with `AuthController` (Contract 3). The open chat on screen also sees the turn through its normal follow-up stream, so the user watching it sees the reply arrive.

`queued`: the prompt goes out with `queued: true`, as the chat's own queue does, so a turn Hermes runs on its own in that chat at that moment is not redirected. `WatchRequestHandler` does not expose `queued`; if verification shows a redirect happens, the handler is called with a transport wrapper that forces `queued: true` on `send` (a few lines, no change under `lib/src/watch/`).

### Exactly once

iOS delivers each response once, to one of the two handlers. The function has no retry; a failed send is reported, not repeated, so a slow network cannot send the prompt twice. The response's notification is removed by iOS after the action.

### "Reply not sent"

An `AttentionNotification` for the same chat (same id, so it replaces "Reply ready"), title the chat's title from the original notification, body "Reply not sent. Open Hermes to try again." The typed text is not repeated in it (it would show on the Lock Screen). Its tap target is `deepLinkUri(OpenChat(profile, threadId, prompt: input))`, so tapping it opens the chat with the unsent text in the composer, not sent. The text lives only in that notification's payload, which iOS removes with the notification.

### Platforms and native changes

- iOS: no native code or entitlement; the background handler's plugin registration is the peer's and `headless-runtime`'s.
- macOS: the same action. macOS launches or activates the app to deliver a notification response, so it is handled in the main isolate by the foreground path.
- Android, Windows, Linux, watchOS: none.

### Invariants touched

- Auth: the headless runtime's rules (never signs out, gives up quietly on a refresh conflict).
- Notification bodies: the new body is fixed text; no reply or prompt text.
- Telemetry, recorded in `inline_reply.dart`: span `background.task` (`task: notification.reply`, `outcome`, `engine`), log event `notification.reply` (`outcome`), breadcrumb `notification.reply` (`outcome`) in the foreground engine only. No text, title, profile or id.
- API layering: gateway only, through the existing transport.

### Dependencies

PR #587 (category builder, response handlers), `headless-runtime` (`withHeadlessHermes`), `deep-links` (prefilled chat link), `ask-hermes-intent` (shared turn runner), and `background-refresh` for late answers.

## Risks / Trade-offs

- [iOS gives a background notification response little time] → about 30 seconds; the 25-second window fits a short reply, and `background-refresh` covers the rest. `flutter_local_notifications` decides when it tells iOS the response is handled; verify that the background engine is not cut off before `prompt.submit` returns.
- [Typed text in the failure notification's payload] → not shown in the banner or on the Lock Screen; gone when the notification is tapped or cleared.
- [Two engines refreshing tokens] → only when a response arrives while the app is starting; the runtime gives up on conflict.
- [Coupling to `WatchRequestHandler`] → shared with `ask-hermes-intent`; a later move of its send loop out of `lib/src/watch/` removes it.

## Migration Plan

Nothing to migrate. Notifications posted before the update have no reply action; new ones do.
