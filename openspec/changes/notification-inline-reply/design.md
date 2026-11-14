# Design

## Context

See proposal.md for motivation and specs/notifications/spec.md for behavior. The visual record is `docs/design-briefs/notification-inline-reply.md`.

What this design relies on, checked against the code on main and the contract pinned at `openrpc/HERMES_REF` (`d923a5eb`):

- `flutter_local_notifications` offers `DarwinNotificationAction.text(id, title, buttonTitle:, placeholder:, options:)` with `authenticationRequired`. `RequestAction.toDarwin()` already builds one for the question "Reply" (`textInput: true`), and `RequestCategory.toChannel()` carries `buttonTitle` and `placeholder` to the Runners' `hermes_app/notification_categories`, which re-register the categories natively.
- "Reply ready" and "Reply failed" already have categories without actions, `replyReadyCategory` (`hermes.reply.ready`) and `replyFailedCategory`, whose placeholders (`kReplyReadyBody`, `kReplyFailedBody`) replace the body while iOS hides previews. `attentionFor` already sets them. The earlier draft of this change said "Reply ready notifications have no category today"; that is stale.
- `attentionFor(appLock: true)` already makes a reply's body the generic "Reply ready" and gives requests no buttons. `RequestAnswers` withdraws answerable notifications when App Lock turns on (`withdrawAnswerable`, found by payload on iOS and macOS, by the `hermes.request` tag on Android) and listens to the sign-out stream.
- The answer path for buttons: iOS `NotificationActions` (AppDelegate.swift) handles every `hermes.action.*` id except `hermes.action.open`, with the app in front or not. It calls the completion handler at once, holds a `UIBackgroundTask` that Dart ends through `hermes_app/background_task`, starts the plugin's headless engine, and passes the text as `input`. So on iOS `LocalNotificationService._onResponse` never sees a reply button; only macOS uses it. `answerRequestInBackground` runs `routeAnswer`: it offers the response to the running app over `IsolateNameServer` (offer, then confirm), or `LoneAnswerer` answers alone, one at a time, within `kAnswerBudget` (25 s from the button). After `_go`, a missing report by the due time plus `reportGrace` calls `unanswered`. `answerFromResponse` returns null for a payload with no request, so a reply response is today ignored.
- `prompt.submit` takes `queued` (OpenRPC `PromptSubmitParams.queued`), and its result `status` is `streaming | queued | steered | redirected`. `request.answer` takes `{id, result, profile}` and answers `{status: ok | expired}`.
- `QueueSubmissionTransport.sendQueued` (the chat's own queue) sends with `queued: true`. It throws `QueueSubmissionNotStarted` only for an unresolved profile, a failed `beforeSubmit` or a refused dispatch. Connect and resume errors (step `connect` or `open`) and errors after `prompt.submit` was written (step `submit`) surface as raw `GatewayConnectionClosed` or `TimeoutException`, so the exception alone does not say whether Hermes may have the prompt. `WatchRequestHandler` does not expose `queued`, so it is not used.
- `withHeadlessHermes` returns `HeadlessDone`, `HeadlessSignedOut`, `HeadlessLocked` or `HeadlessUnreachable`, never signs the user out and never clears the stored session. It sets the span's own `outcome` when the run ends, so a body's outcome goes in an annotation (`hermes.annotate`), as Ask Hermes does, and a refusal before any run gets a run-less span.
- `RunningReplies` (`hermes.background.running.v1`) records a chat whose reply still runs, with `fromAsk` for a turn that outlived its sender's answer. `RunningRepliesStep` announces it on positive evidence only and builds its notification by hand (`background_alerts.dart`) with `replyReadyCategory` and no payload marker. The background check runs on iOS and Android only (`BackgroundScheduler._supported`).
- `appLockOnNow` and `AppLockController.savedEnabled` read App Lock in either isolate; `RequestAnswerSender` refuses to answer past it and posts `kOpenToAnswerBody`. `appLockHidesRequests` counts App Lock as on until its saved setting has loaded; this design uses the same rule.
- Ask Hermes keeps an unsent question of up to 4,000 characters in its not-sent notification's `'q'` payload and does not withdraw it when App Lock turns on; it only leaves the text out when App Lock is on at that moment. This design is stricter, see "What is kept".
- `deepLinkUri(OpenChat(profile, threadId, prompt))` builds `hermes://chat?...&prompt=`; `deepLinkPromptLimit` is 4,000 characters; a link's prompt goes under the composer's draft and is never sent. The shell opens it with `ChatOpenRequests.request(target, prompt:, fromLink: true)`.

## Goals / Non-Goals

**Goals:**

- One send path whether the response arrives in the running app or in the background.
- The text is sent at most once per response, and only by the user's Send in the notification.
- Every ending tells the user: answered, not sent, could not confirm, or App Lock.
- Nothing is kept beyond what a notification body already shows, and under App Lock nothing.

**Non-Goals:**

- Holding the process open until a long reply finishes.
- Android, Windows, Linux (see proposal).

## Decisions

### The action and its category

A new `RequestCategory` `replyReadyActionCategory`, id `hermes.reply.ready.reply`, placeholder `kReplyReadyBody`, holds one text action: id `hermes.action.reply-chat` (`kReplyChatAction`), title "Reply", button "Send", placeholder "Reply to Hermes", `authenticationRequired`, no `foreground`. The existing `replyReadyCategory` stays as it is. The id keeps the `hermes.action.` prefix, so `NotificationActions` routes it through the same background engine path; no native change. `RequestAction` gets a `buttonTitle` and `placeholder` so the question's "Your answer" is not reused.

One function, `replyReadyNotification(...)`, chooses the category and the payload for a completed reply, and both posters call it: `attentionFor` (the running app) and `RunningRepliesStep` (the background check, which builds its notification by hand today). The action is chosen for a completed reply (not failed, not stopped) with a chat target, while App Lock is off and loaded and someone is signed in; every other case keeps today's category. The payload gets `'y': 1`, the chat title `'n'`, and `'a'`, the `fnv1a` hash of the account key (`HeadlessHermes.accountKey`), so a response can name the chat, `withdrawAnswerable` can find it, and a reply from a notification posted for another account or server is refused. Notifications posted before the update have no action; new ones do.

The category ships together with its handler (PR 2), never alone, so no Reply button exists without a handler.

### One handler for both paths

`sendInlineReply` in `lib/src/notifications/inline_reply.dart`. `routeAnswer` is generalised from "an answer" to "a response the app handles": it still offers the response to the running app and falls back to the lone isolate, so the offer-then-confirm protocol that stops two isolates sending the same answer also stops two sending the same reply. `LoneAnswerer` queues replies with answers in one chain, so two never refresh the token pair at once. `LocalNotificationService._onResponse` calls it on macOS only (iOS never reaches it, even with the app in front). The branch is on `actionId == kReplyChatAction` and the `'y'` marker, before `answerFromResponse`. On macOS, `launchTarget` gets the same branch behind the `_launchAnswered` once-only guard, so a reply that started the app is handled once and does not open the chat.

Steps, within `kAnswerBudget` from the response (the handover's `_at`):

1. Decode the target from the payload. A job target, a missing `'y'` marker or an empty or whitespace-only `input` does nothing and posts nothing.
2. Read App Lock (`appLockOnNow` in the app, `AppLockController.savedEnabled` in the lone isolate) before any request; on, or not yet loaded, counts as on. Send nothing, keep nothing, post `kOpenToReplyBody` ("Open Hermes to reply.") under the title "Hermes", and end a run-less span (`reply.outcome: locked`).
3. Run `withHeadlessHermes(body, task: 'notification.reply')` with the time left. `HeadlessSignedOut`, `HeadlessLocked` and `HeadlessUnreachable` each post "Reply not sent". Signed out keeps no text.
4. In the body, compare the payload's `'a'` with the hash of `HeadlessHermes.accountKey`. A mismatch posts "Reply not sent" with no text and sends nothing.
5. Send with `transport.sendQueued(...)` (`queued: true`, `beforeSubmit` does nothing) and classify by the transport's step, not by the exception type:
   - Not sent: an error while the step is `connect` or `open`, a `ProfileUnavailableException`, or `QueueSubmissionNotStarted`. "Reply not sent" (`failed`).
   - May have been sent: any error or timeout once `prompt.submit` was written (step `submit` or later) before its result. "Couldn't confirm" (`unconfirmed`). Nothing is resent.

   The transport has no typed signal for this today. The first task of PR 2 makes `sendQueued` fail with a typed `SendFailure` that carries the step (a small change under `lib/src/chat/gateway/`, with tests); `QueueSubmissionNotStarted` stays what it is.

6. The prompt was accepted when `prompt.submit` answers (`PromptAcknowledged`, or a `status` in the contract's four). If the reply ends inside the window, `announce` posts it ("Reply ready", "Reply failed" or a request notification) (`answered`). If the window ends first, the body stops waiting and mutes `announce` (closing the transport would otherwise announce a failed end). On iOS it records the chat in `RunningReplies` so the background check announces it (`sent`). On macOS nothing is recorded because no background check runs; the answer is seen when the chat is opened. The turn keeps running on the server. `fromAsk` is reused as it is: its documented meaning is a turn that outlived its sender, not a chat the screen was showing, which is exactly this; a rename to `fromBackground` is optional in PR 2.
7. A prompt Hermes folds into a running turn (`PromptFolded`, status `steered` or `redirected`) produces no `ReplyCompleted`. It counts as `sent`, is recorded as above, and the turn that follows is never announced as the answer.
8. The hand-off: after the background isolate sends `_go` to the running app, `routeAnswer` waits until the due time plus `reportGrace` for a report and then calls `unanswered`. For a reply, `unanswered` posts "Couldn't confirm" (the app may have sent it), never "Reply not sent". Before `_go`, a failed hand-off falls back to `alone`, which has sent nothing.

No step retries. `prompt.submit` is never resent (gateway rule). In the running app `withHeadlessHermes` coordinates with `AuthController` (Contract 3); the open chat sees the turn through its normal follow-up stream.

`queued: true`: the prompt must not steer or redirect a turn that runs in the chat at that moment, so the reply goes out as the chat's own queue sends. If a server runs the prompt as `redirected` anyway, that is the server's behaviour; the live-backend check (first task of PR 2) shows what it does.

### Exactly once

iOS delivers a response once, and the hand-off's offer-then-confirm makes one isolate the sender. There is no retry. The notification is removed by the system after the action. The text is a `String` in the handler's frame; nothing writes it except in the one case below.

### What is kept

Decision: the typed text lives in memory while it is sent and is otherwise kept only to let the user get it back after "Reply not sent", and only as much as a notification body could already show.

- Kept in the "Reply not sent" notification's payload under a new key `'u'` (the existing `'q'` key means a new chat, so it cannot be reused) only if it is at most `kPreviewLength` (120) user-perceived characters, App Lock is off and loaded, the outcome is not signed out, and the failure is `failed` or `unavailable`. `targetFromPayload` reads `'u'` into a chat target that carries a draft and a profile. The shell opens it as a link does (`ChatOpenRequests.request(target, prompt:, fromLink: true)`), which switches to the chat's profile, so a tap from another profile works.
- The payload lives with the notification. iOS and macOS keep delivered notifications in the system's store until they are tapped or cleared. That is on disk, which is why the cap is the preview length, the length a "Reply ready" body already puts there, and why the text is never in preferences, files or logs.
- Withdrawn: turning App Lock on withdraws notifications with `'y'` or `'u'` (`withdrawAnswerable` extended); signing out withdraws them too (`RequestAnswers` already listens to the sign-out stream).
- Longer text, `unconfirmed`, `locked`, signed out and `sent` keep nothing.
- The body, the title, the telemetry and the breadcrumb never hold the text. The tap opens the chat as `deepLinkUri(OpenChat(profile, threadId, prompt: text))` does: composer prefilled, never sent. No URL is stored.
- If notifications are off or the permission was revoked, the ending notification is not posted and no text is kept.

Why stricter than Ask Hermes: its not-sent notification keeps up to 4,000 characters and is not withdrawn when App Lock turns on or the user signs out. Text typed into a notification of a chat the user may want protected deserves the tighter rule; Ask Hermes should follow it later (roadmap finding).

### Ending notifications

Each is an `AttentionNotification` for the same chat (same id, so it replaces "Reply ready"), title the chat's title from the original payload, except under App Lock ("Hermes"). Bodies are fixed text:

| Ending                  | Body                                                        | Payload              |
| ----------------------- | ----------------------------------------------------------- | -------------------- |
| not sent, text kept     | Reply not sent. Open Hermes to try again.                   | chat, `'u'`          |
| not sent, text not kept | Reply not sent. Open Hermes to write it again.              | chat                 |
| could not confirm       | Couldn't confirm your reply was sent. Open Hermes to check. | chat                 |
| App Lock                | Open Hermes to reply.                                       | none (opens the app) |

"Try again" is said only when a text is in the payload; any not-sent without a kept text says "write it again". They are plain default-level notifications with no category, like `kAnswerFailedBody`. Posting goes through a `LocalNotificationService(background: true)` in the lone isolate, and is skipped when notifications are off.

### Platforms and native changes

- iOS and iPadOS: no native code or entitlement. The background engine and plugin registration are `NotificationActions.registerPlugins` and `headless-runtime`'s. The response is handled in the plugin's isolate, or handed to the app's when it runs; never through `_onResponse`.
- macOS: the same category. The response reaches the app's isolate (the app is launched or activated for a text action); `_onResponse` and `launchTarget` handle it. `authenticationRequired` on macOS requires an unlocked Mac. No background check runs there.
- Android: not offered (proposal). Windows, Linux: no notification actions. watchOS: not designed.

### Invariants touched

- Auth: the headless runtime's rules (never signs out, gives up quietly on a refresh conflict).
- Notification bodies: all new bodies are fixed text; the existing App Lock rule is kept (generic "Reply ready", no action), and App Lock not yet loaded counts as on.
- Requests: `kReplyChatAction` is not `kReplyAction`; `answerFromResponse` never sees a reply, and a request notification's buttons answer only the id in its payload (`inline_reply.dart` never calls `request.answer`, `approval.respond` or `clarify.respond`).
- Telemetry, in `inline_reply.dart`: span `background.task` (`task: notification.reply`, `engine`) annotated `reply.outcome` (`answered`, `sent`, `failed`, `unavailable`, `unconfirmed`); a run-less span for `locked`. Log event `notification.reply` (`outcome`, `route`), breadcrumb `notification.reply` (`outcome`) in the foreground engine only. No text, title, profile or id.
- API layering: gateway only, through the existing transport.

### Settings

No new switch: the action follows the notification setting and App Lock. The Notifications dialog gets one footnote, "On iPhone, iPad and Mac you can reply to a finished reply from its notification. Not while App Lock is on." It is a changed use case in the catalog, with strings in `app_en.arb` and `app_de.arb` under the notifications area anchor and `flutter gen-l10n` run. It ships in PR 2 with the action.

### Dependencies

#587/#589, #914, `headless-runtime`, `deep-links`, `ask-hermes` (`RunningReplies.fromAsk`), `background-refresh`. All are on main.

## Risks / Trade-offs

- [iOS gives a background notification response about 30 seconds] → the 25-second budget starts at the response. The Runner calls the completion handler at once and holds a `UIBackgroundTask` that Dart ends through `hermes_app/background_task` when the answer is done; verify on a device that the task is not cut off before `prompt.submit` returns.
- [The answer may not arrive as a notification for a long while] → on iOS the background check runs at the system's discretion, every 15 minutes at the earliest and sometimes never; on macOS no check runs. The chat is correct when opened.
- [Text on disk in the notification payload after a failure] → capped at the preview length, never with App Lock or signed out, withdrawn on App Lock and sign-out, cleared with the notification. The alternative, dropping prefill entirely, makes the user retype a lost answer; recorded as an open question.
- [App Lock turned on between post and reply] → re-read on arrival; withdrawn when it turns on.
- [Two isolates, one reply] → the hand-off's offer-then-confirm; a lost report after `_go` ends in "Couldn't confirm". Not verifiable without a device.
- [`prompt.submit` result lost] → "Couldn't confirm", no resend; the user may need to look at the chat.
- [Stale notification, another account] → refused by the account hash; withdrawn on sign-out.

## Not verified without a device

Everything about the system's notification UI: that the text action shows on the Lock Screen only after unlock, the text field and "Send" button on iOS and macOS, that the Runner's engine finishes `prompt.submit` inside the background window, the hand-off with the running app, delivered-notification persistence of the payload, macOS launching the app for the response (cold launch). The contract (`queued`, the status values) is checked against the pinned OpenRPC; a live backend check is the first task of PR 2. The canvas draws the system UI as a neutral frame and shows only the app's own text.

## Migration Plan

Nothing to migrate. Notifications posted before the update have no reply action; new ones do.
