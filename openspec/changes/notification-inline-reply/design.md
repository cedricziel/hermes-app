# Design

## Context

See proposal.md for motivation and specs/notifications/spec.md for behavior. The visual record is `docs/design-briefs/notification-inline-reply.md`.

What this design relies on, checked against the code on main and the contract pinned at `openrpc/HERMES_REF` (`d923a5eb`):

- `flutter_local_notifications` offers `DarwinNotificationAction.text(id, title, buttonTitle:, placeholder:, options:)` with `authenticationRequired`. `RequestAction.toDarwin()` already builds one for the question "Reply" (`textInput: true`), and `RequestCategory.toChannel()` carries `buttonTitle` and `placeholder` to the Runners' `hermes_app/notification_categories`, which re-register the categories natively.
- "Reply ready" and "Reply failed" already have categories without actions, `replyReadyCategory` (`hermes.reply.ready`) and `replyFailedCategory`, whose placeholders (`kReplyReadyBody`, `kReplyFailedBody`) replace the body while iOS hides previews. `attentionFor` already sets them. The earlier draft of this change said "Reply ready notifications have no category today"; that is stale.
- `attentionFor(appLock: true)` already makes a reply's body the generic "Reply ready" and gives requests no buttons. `RequestAnswers` withdraws answerable notifications when App Lock turns on (`withdrawAnswerable`, found by payload on iOS and macOS, by the `hermes.request` tag on Android).
- The answer path for buttons: iOS `NotificationActions` (AppDelegate.swift) handles every `hermes.action.*` id except `hermes.action.open`, starts the plugin's headless engine, and passes the text as `input`. `answerRequestInBackground` runs `routeAnswer`: it offers the response to the running app over `IsolateNameServer` (offer, then confirm), or `LoneAnswerer` answers alone, one at a time, within `kAnswerBudget` (25 s from the button). On macOS the app's isolate gets the response (`RequestAnswers`). `answerFromResponse` returns null for a payload with no request, so a reply response is today ignored.
- `prompt.submit` takes `queued` (OpenRPC `PromptSubmitParams.queued`), and its result `status` is `streaming | queued | steered | redirected`. `request.answer` takes `{id, result, profile}` and answers `{status: ok | expired}`.
- `QueueSubmissionTransport.sendQueued` (the chat's own queue) sends with `queued: true` and throws `QueueSubmissionNotStarted` when the failure happened before the prompt RPC started; `HermesGatewayTransport.send(queued:)` exists too. Neither needs `WatchRequestHandler`, which does not expose `queued`.
- `withHeadlessHermes` returns `HeadlessDone`, `HeadlessSignedOut`, `HeadlessLocked` or `HeadlessUnreachable`, never signs the user out and never clears the stored session.
- `RunningReplies` (`hermes.background.running.v1`) records a chat whose reply still runs, with `fromAsk` for a turn that outlived an "Ask Hermes" answer; `RunningRepliesStep` of the background refresh announces it on positive evidence only.
- `appLockOnNow` and `AppLockController.savedEnabled` read App Lock in either isolate; `RequestAnswerSender` refuses to answer past it and posts `kOpenToAnswerBody`.
- `deepLinkUri(OpenChat(profile, threadId, prompt))` builds `hermes://chat?...&prompt=`; `deepLinkPromptLimit` is 4,000 characters; a link's prompt goes under the composer's draft and is never sent.

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

A new `RequestCategory` `replyReadyActionCategory`, id `hermes.reply.ready.reply`, placeholder `kReplyReadyBody`, holds one text action: id `hermes.action.reply-chat` (`kReplyChatAction`), title "Reply", button "Send", placeholder "Reply to Hermes", `authenticationRequired`, no `foreground`. The existing `replyReadyCategory` stays as it is. The id keeps the `hermes.action.` prefix, so `NotificationActions` routes it through the same background engine path; no native change. `RequestAction` gets a `buttonTitle` and `placeholder` so the question's "Your answer" is not reused ("Reply to Hermes" is the right prompt for a chat).

`attentionFor` picks the category: `ReplyCompleted` that is neither failed nor stopped, a chat target (not a job, not a message), notifications enabled and `appLock` false gets `replyReadyActionCategory`; every other case keeps today's category. Its payload gets a marker `'y': 1` and the chat title `'n'` (as an answerable request's does), so a response can name the chat and `withdrawAnswerable` can find it. `staticRequestCategories()` includes the new category. Categories posted before the update have no action; new ones do.

### One handler for both paths

`sendInlineReply` in `lib/src/notifications/inline_reply.dart`. `routeAnswer` is generalised from "an answer" to "a response the app handles": it still offers the response to the running app and falls back to the lone isolate, so the hand-off protocol that stops two isolates sending the same answer also stops two sending the same reply. `LoneAnswerer` queues replies with answers in its one chain, so two never refresh the token pair at once. `LocalNotificationService._onResponse` calls it on macOS and while the app runs. The branch is on `actionId == kReplyChatAction` and the `'y'` marker, before `answerFromResponse`.

Steps, within `kAnswerBudget` from the response (the handover's `_at`):

1. Decode the target from the payload. A job target, a missing `'y'` marker or an empty or whitespace-only `input` does nothing and posts nothing.
2. Read App Lock (`appLockOnNow` in the app, `AppLockController.savedEnabled` in the lone isolate) before any request. On: send nothing, keep nothing, post `kOpenToReplyBody` ("Open Hermes to reply.") under the title "Hermes" (the chat title is hidden under App Lock), outcome `locked`.
3. Run `withHeadlessHermes(body, task: 'notification.reply')` with the time left. `HeadlessSignedOut`, `HeadlessLocked` and `HeadlessUnreachable` each post "Reply not sent" (`unavailable`).
4. In the body, send with `transport.sendQueued(...)` (`queued: true`; `beforeSubmit` does nothing) and read the stream. `QueueSubmissionNotStarted`, `ProfileUnavailableException` or an error before the first event: "Reply not sent" (`failed`). A first event, or a `status` in the contract's four: Hermes took the prompt.
5. After Hermes took it: if the reply ends inside the window, `announce` posts it ("Reply ready", "Reply failed" or a request notification) (`answered`). If the window ends first, the body stops waiting, mutes `announce` (closing the transport would otherwise announce a failed end), records the chat in `RunningReplies` with `fromAsk: true` so the background check announces it and the chat screen's returns leave it alone (`sent`). The turn keeps running on the server.
6. If the send errors or times out after the prompt RPC began and before any `status`, Hermes may or may not have it: post "Couldn't confirm your reply was sent. Open Hermes to check." (`unconfirmed`). The design-pass rule for a lost answer is followed: it ends within the window with "Couldn't confirm…", offers nothing automatic and resends nothing.

No step retries. `prompt.submit` is never resent (gateway rule), and a failed send is reported, not repeated. In the running app, `withHeadlessHermes` coordinates with `AuthController` (Contract 3); the open chat sees the turn through its normal follow-up stream.

`queued: true`: the prompt must not steer or redirect a turn that runs in the chat at that moment, so the reply goes out as the chat's own queue sends. If a server runs the prompt as `redirected` anyway, that is a server behaviour; the first task checks it against a live backend.

### Exactly once

iOS delivers a response once, and the hand-off's offer-then-confirm makes one isolate the sender. There is no retry. The notification is removed by the system after the action. The text is a `String` held in the handler's frame; nothing writes it until the failure case below.

### What is kept

Decision: the typed text lives in memory while it is sent and is otherwise kept only to let the user get it back after "Reply not sent", and only as much as a notification body could already show.

- Kept in the "Reply not sent" notification's payload under a new key `'u'` (the existing `'q'` key means a new chat, so it cannot be reused; `targetFromPayload` reads `'u'` into a chat target that carries a draft, and the shell passes it to `OpenRequests.request(target, prompt:, fromLink: true)`, the call a `hermes://chat` link makes) only if it is at most `kPreviewLength` (120) user-perceived characters, App Lock is off, and the failure is `failed` or `unavailable`. The payload lives with the notification: iOS and macOS keep delivered notifications in the system's notification store until the user swipes or taps them away. That is on disk, which is why the cap is the preview length, the length a "Reply ready" body already puts there, and why it is never in preferences, files or logs.
- Longer text, `unconfirmed`, `locked` and `sent` keep nothing. "Reply not sent. Open Hermes to write it again." replaces the body when a long text was dropped.
- The body, the title, the telemetry and the breadcrumb never hold the text. The tap opens the chat exactly as `deepLinkUri(OpenChat(profile, threadId, prompt: text))` does: composer prefilled, never sent. No URL is stored; the payload holds the key and the text.

The earlier draft kept the text in the payload at any length. The cap and the App Lock rule are the change.

### "Reply not sent", "Couldn't confirm" and App Lock notifications

Each is an `AttentionNotification` for the same chat (same id, so it replaces "Reply ready"), title the chat's title from the original payload, except under App Lock ("Hermes"). Bodies are fixed text:

| Ending                  | Body                                                        | Payload              |
| ----------------------- | ----------------------------------------------------------- | -------------------- |
| not sent, text kept     | Reply not sent. Open Hermes to try again.                   | chat, prompt         |
| not sent, text too long | Reply not sent. Open Hermes to write it again.              | chat                 |
| could not confirm       | Couldn't confirm your reply was sent. Open Hermes to check. | chat                 |
| App Lock                | Open Hermes to reply.                                       | none (opens the app) |

They are plain default-level notifications with no category (no buttons), like `kAnswerFailedBody`. Posting goes through a `LocalNotificationService(background: true)` in the lone isolate.

### Platforms and native changes

- iOS: no native code or entitlement. The background engine and plugin registration are `NotificationActions.registerPlugins` and `headless-runtime`'s. The response is handled in the plugin's isolate, or in the app's when it runs.
- macOS: the same category. The response reaches the app's isolate (the app is launched or activated for a text action), so the foreground path handles it. `authenticationRequired` on macOS requires an unlocked Mac.
- Android: not offered (proposal). Windows, Linux: no notification actions. watchOS: a mirrored notification shows the category's action only if watchOS mirrors it; not in scope and not verified.

### Invariants touched

- Auth: the headless runtime's rules (never signs out, gives up quietly on a refresh conflict).
- Notification bodies: all new bodies are fixed text, the existing App Lock rule is kept (generic "Reply ready", no action).
- Requests: `kReplyChatAction` is not `kReplyAction`; `answerFromResponse` never sees a reply, and a request notification's buttons answer only the id in its payload (`request.answer` / `approval.respond` / `clarify.respond` are not called by `inline_reply.dart`).
- Telemetry, recorded in `inline_reply.dart`: span `background.task` (`task: notification.reply`, `outcome`, `engine`), log event `notification.reply` (`outcome`, `route`), breadcrumb `notification.reply` (`outcome`) in the foreground engine only. No text, title, profile or id.
- API layering: gateway only, through the existing transport.

### Settings

No new switch: the action follows the notification setting and App Lock. The Notifications dialog gets one footnote, "On iPhone and Mac you can reply to a finished reply from its notification. Not while App Lock is on." (a changed use case in the catalog).

### Dependencies

#587/#589, #914, `headless-runtime`, `deep-links`, `ask-hermes` (`RunningReplies.fromAsk`), `background-refresh`. All are on main.

## Risks / Trade-offs

- [iOS gives a background notification response about 30 seconds] → the 25-second budget starts at the response; `flutter_local_notifications` decides when it tells iOS the response is handled; verify on a device that the background engine is not cut off before `prompt.submit` returns.
- [The answer may not arrive as a notification for a long while] → the background check runs at the system's discretion, every 15 minutes at the earliest and sometimes never; the chat is correct when opened. Said in the spec as "when the system runs that check".
- [Text on disk in the notification payload after a failure] → capped at the preview length, never with App Lock, cleared with the notification. The alternative, dropping prefill entirely, makes the user retype a lost answer; recorded as an open question.
- [App Lock turned on between post and reply] → re-read on arrival; withdrawn when it turns on.
- [Two isolates, one reply] → the hand-off's offer-then-confirm; not verifiable without a device.
- [`prompt.submit` result lost] → "Couldn't confirm", no resend; the user may need to look at the chat.

## Not verified without a device

Everything about the system's notification UI: that the text action shows on the Lock Screen only after unlock, the text field and "Send" button on iOS and macOS, that the Runner's engine finishes `prompt.submit` inside the background window, the hand-off with the running app, delivered-notification persistence of the payload, macOS launching the app for the response. The contract (`queued`, the status values) is checked against the pinned OpenRPC; a live backend check belongs to the build task. The canvas draws the system UI as a neutral frame and shows only the app's own text.

## Migration Plan

Nothing to migrate. Notifications posted before the update have no reply action; new ones do.
