# Design

## Context

See proposal.md for motivation and specs/notifications/spec.md for behavior. The visual record is `docs/design-briefs/notification-inline-reply.md`.

What this design relies on, checked against the code on main and the contract pinned at `openrpc/HERMES_REF` (`d923a5eb`):

- `flutter_local_notifications` offers `DarwinNotificationAction.text(id, title, buttonTitle:, placeholder:, options:)` with `authenticationRequired`. `RequestAction.toDarwin()` already builds one for the question "Reply" (`textInput: true`), and `RequestCategory.toChannel()` carries `buttonTitle` and `placeholder` to the Runners' `hermes_app/notification_categories`, which re-register the categories natively.
- "Reply ready" and "Reply failed" already have categories without actions, `replyReadyCategory` (`hermes.reply.ready`) and `replyFailedCategory`, whose placeholders (`kReplyReadyBody`, `kReplyFailedBody`) replace the body while iOS hides previews. `attentionFor` already sets them. The earlier draft of this change said "Reply ready notifications have no category today"; that is stale.
- `attentionFor(appLock: true)` already makes a reply's body the generic "Reply ready" and gives requests no buttons. `RequestAnswers` withdraws answerable notifications when App Lock turns on (`withdrawAnswerable`, found by payload on iOS and macOS, by the `hermes.request` tag on Android) and listens to the sign-out stream.
- The answer path for buttons: iOS `NotificationActions` (AppDelegate.swift) handles every `hermes.action.*` id except `hermes.action.open`, with the app in front or not. It calls the completion handler at once, holds a `UIBackgroundTask` that Dart ends through `hermes_app/background_task`, starts the plugin's headless engine, and passes the text as `input`. So on iOS `LocalNotificationService._onResponse` never sees a reply button; only macOS uses it. `answerRequestInBackground` runs `routeAnswer`: it offers the response to the running app over `IsolateNameServer` (offer, then confirm), or `LoneAnswerer` answers alone, one at a time, within `kAnswerBudget` (25 s from the button). After `_go`, a missing report by the due time plus `reportGrace` calls `unanswered`. `answerFromResponse` returns null for a payload with no request, so a reply response is today ignored.
- `prompt.submit` takes `queued` (OpenRPC `PromptSubmitParams.queued`), and its result `status` is `streaming | queued | steered | redirected`. `request.answer` takes `{id, result, profile}` and answers `{status: ok | expired}`.
- `HermesGatewayTransport.send(queued: true)` and `QueueSubmissionTransport.sendQueued` both send with `queued: true`; `sendQueued` refuses a null or blank profile, `send` accepts one. The transport's steps before `prompt.submit` are `connect`, `open`, `attach` and, on the `sendQueued` path only, `commit`; `ChatTransport.promptAccepted` is true once `prompt.submit` answered. It throws `QueueSubmissionNotStarted` only for an unresolved profile, a failed `beforeSubmit` or a refused dispatch. Connect and resume errors (step `connect` or `open`, including a `GatewayRpcException` that is not about the profile) and errors after `prompt.submit` was written (step `submit`) surface as raw `GatewayConnectionClosed`, `GatewayRpcException` or `TimeoutException` for a send without `onSubmitting`, so the exception alone does not say whether Hermes may have the prompt; a send with `onSubmitting` wraps them in `SendFailure(step)` (a rejection of `prompt.submit` counts as `submit`). `WatchRequestHandler` does not expose `queued`, so it is not used. The headless runtime maps its own timeout, a throwing body and an `auth_failed` that overrides an unsettled body to `HeadlessUnreachable` or `HeadlessSignedOut`, which can happen after `prompt.submit` was written.
- `withHeadlessHermes` returns `HeadlessDone`, `HeadlessSignedOut`, `HeadlessLocked` or `HeadlessUnreachable`, never signs the user out and never clears the stored session. It sets the span's own `outcome` when the run ends, so a body's outcome goes in an annotation (`hermes.annotate`), as Ask Hermes does, and a refusal before any run gets a run-less span.
- `RunningReplies` (`hermes.background.running.v1`) records a chat whose reply still runs, with `fromAsk` for a turn that outlived its sender's answer. `RunningRepliesStep` announces it on positive evidence only and builds its notification by hand (`background_alerts.dart`) with `replyReadyCategory` and no payload marker. The background check runs on iOS and Android only (`BackgroundScheduler._supported`).
- `appLockOnNow` (waits up to 5 s for the setting, then reads the stored one) and `AppLockController.savedEnabled` read App Lock in either isolate; `RequestAnswerSender` refuses to answer past it and posts `kOpenToAnswerBody`. `appLockHidesRequests` counts App Lock as on until its saved setting has loaded; this design uses the same rule.
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

`sendInlineReply` in `lib/src/notifications/inline_reply.dart`, one function for every path, with the sender and the clock passed in. Both isolates build it the same way, on the headless runtime.

- **Background isolate (iOS, iPadOS).** `routeAnswer` is generalised from "an answer" to "a response the app handles": it offers the response to the running app (offer, then confirm) or falls back to `LoneAnswerer`, which queues replies with answers in one chain so two never refresh the token pair at once. The budget is `kAnswerBudget` from the handover's `_at`, which the iOS Runner adds.
- **Running app, after `_go`.** The sender is `RequestAnswers._onMessage`. Today it calls `answerFromAction`, gets null for a reply, reports `failed` and posts nothing, and its sender is built on `AuthController` (`RequestAnswers.forAuth`). The reply branch goes there: when the message carries `kReplyChatAction` and the `'y'` marker it calls `sendInlineReply` through `withHeadlessHermes` (which coordinates with `AuthController`, Contract 3) and reports the outcome name back on the reply port, as it does for answers.
- **macOS.** `LocalNotificationService._onResponse` and, at a cold launch, `launchTarget` (behind the `_launchAnswered` once-only guard) call it in the app's isolate, so a reply that started the app is handled once and does not open the chat. There is no handover `_at` on macOS: the budget starts when Dart receives the response.
- iOS never reaches `_onResponse` (the Runner handles every `hermes.action.*` id but Open, in front or not).

The branch is on `actionId == kReplyChatAction` and the `'y'` marker, before `answerFromResponse`.

**Timing.** Let `due` be the budget end (`kAnswerBudget` from the response). The background isolate waits until `due + reportGrace` (2 s) for the report. The app side must have posted and reported before that, so its schedule works backwards from `due`:

| Moment          | What happens                                                                                                                                                                                                                                                  |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `due - 6 s`     | app route: the run's `timeout` ends (`timeout: due - 6 s - now`) and the body's cutoff is that same moment, since `_Run.execute` opens the connection before the body and a cutoff inside the body cannot stop that; it stops waiting, mutes `announce`, ends |
| up to 3 s later | `withHeadlessHermes` closes within `closeGrace` (3 s)                                                                                                                                                                                                         |
| up to 2 s later | the ending is posted: App Lock is re-read with `AppLockController.savedEnabled` directly (no 5 s wait; unreadable counts as on), the permission is checked, the notification is posted                                                                        |
| `due`           | the app side has reported; it posts no ending after `due` and past it reports `<outcome>:none`                                                                                                                                                                |
| `due + 2 s`     | the isolate's fallback fires if no report came                                                                                                                                                                                                                |
| lone isolate    | its `timeout` ends at `due`; with `closeGrace` and the post it ends about 28 to 29 s after the response, just inside the roughly 30 s iOS allows. To be measured on a device (task 4.3)                                                                       |

Rules that follow:

- The cutoff itself causes an ending (a prompt written and not acknowledged at the cutoff ends as "Couldn't confirm"), and that ending is posted after the cutoff. What is muted after the cutoff is only the announcement of an answer.
- The report says whether an ending was posted, e.g. `unconfirmed:posted` or `unconfirmed:none`. When an ending was due and none was posted (notifications off or not permitted excepted), the isolate posts "Couldn't confirm" itself. When no report arrives by `due + reportGrace`, the isolate posts "Couldn't confirm". When an ending was posted, the isolate posts nothing, so a late report cannot replace it and a late "Reply ready" cannot overwrite it.
- Before `_go` a failed hand-off falls back to `alone`, which has sent nothing.
- The isolate's own "Couldn't confirm" (`unanswered` in `answerRequestInBackground`) goes through the same `postEnding` as every other ending: App Lock re-read, notification permission checked, title "Hermes" under App Lock.

Steps of `sendInlineReply`:

1. Decode the target from the payload. A job target, a missing `'y'` marker or an empty or whitespace-only `input` does nothing and posts nothing.
2. Read App Lock from its saved setting, waiting for it to load if needed (`appLockOnNow` in the app, `AppLockController.savedEnabled` in the lone isolate). On, or unreadable, refuses: nothing sent or kept, `kOpenToReplyBody` ("Open Hermes to reply.") under "Hermes", a run-less span (`app_locked`). The post-time rule, unloaded counts as on, is `appLockHidesRequests`; arrival reads the real setting instead of guessing.
3. A small `SubmitMark` is created before `withHeadlessHermes` and passed to the body, so the mapping below can read it after the run ended. It is fed by the transport: a new optional `onSubmitting` callback on `send`, called just before `prompt.submit` is written (where `step.name = 'submit'` is set), sets "written"; the transport's `promptAccepted` getter (set when the step becomes `reply`, which is exactly when `prompt.submit` answered, whether or not `user_row_id` is an int) is "acknowledged". `send` has no `beforeSubmit` and yields no event before submit, which is why the callback is needed.
4. Run `withHeadlessHermes(body, task: 'notification.reply', timeout: ...)`: on the app route `due - 6 s - now`, in the lone isolate `due - now`. `HeadlessDone` is the body's own result. `HeadlessSignedOut`, `HeadlessLocked` and `HeadlessUnreachable` (which is also what its own timeout, a throwing body and an `auth_failed` that overrides an unsettled body map to) are mapped by the mark: not written, "Reply not sent" (signed out keeps no text); written and not acknowledged, `unconfirmed`; acknowledged, `sent`, and on iOS the chat is recorded in `RunningReplies` after the run, from the mark, since the body may never have got to do it.
5. In the body, compare the payload's `'a'` with the hash of `HeadlessHermes.accountKey`. A mismatch posts "Reply not sent", no text, and sends nothing.
6. Send with `transport.send(queued: true, onSubmitting: ...)`, not `sendQueued`: `sendQueued` refuses a null or blank profile, which is what a server without profiles gives, so every reply would fail there. The profile is sent when the payload has one. Classify by the transport's step, not the exception type, with the typed `SendFailure(step)`:
   - Before submit: `connect`, `open`, `attach` (`commit` is only on the `sendQueued` path), a `GatewayRpcException` from `session.resume` or `session.create` (not only the profile-unavailable one), or a `ProfileUnavailableException`. "Reply not sent" (`failed`).
   - Submit written without an answer (step `submit`): "Couldn't confirm" (`unconfirmed`). Nothing is resent.
   - Step `reply` starts when `prompt.submit` was answered, so a failure there is acknowledged: `sent`, not `unconfirmed`.
   - A stream that ends cleanly with no error is classified by step as well: a `SessionReclaimed` before attach or before submit is certainly not sent ("Reply not sent"); one after `onSubmitting` fired and before an acknowledgement is `unconfirmed`. A `prompt.submit` result with no `status` (the typed stop phrase, `voice_stopped`) counts as `sent` and is not recorded as running.
7. The reply ends inside the window: it is announced (`answered`), skipped while the app is in front (`AppPresence` on iOS, the app's own focus on macOS), with `RunningReplies.markAnnounced` before posting so the chat's replay on return does not announce it again. When the app is in front, an open `ChatController` follows the chat and announces its own `ReplyCompleted` as it does for any reply, so the inline path stays silent then; when the app is not in front the controller announces nothing (its focus check), so the two never both alert. If the window ends first, the body stops waiting and mutes `announce` (closing the transport would otherwise announce a failed end). On iOS the chat is recorded in `RunningReplies` so the background check announces it (`sent`); on macOS nothing is recorded, and the answer is seen when the chat is opened. The turn keeps running on the server. `fromAsk` is reused as it is: its documented meaning is a turn that outlived its sender, not a chat the screen was showing; a rename is optional in PR 2.
8. A prompt Hermes folds into a running turn (`PromptFolded`, status `steered` or `redirected`) produces no `ReplyCompleted`. It counts as `sent`, but it is not recorded as running: `RunningRepliesStep` announces whatever the chat's last assistant message is once the chat is idle, so recording would announce the turn the prompt was folded into, not an answer to it. The answer is seen when the chat is opened.
9. Every ending goes through one `postEnding`, used by the body, the app side and the isolate's fallback alike. It re-reads App Lock right before posting (it can turn on mid-send) and drops the text and the chat's title (title "Hermes", same meaning of the body) if it is on, and posts nothing when notifications are off or not permitted.

No step retries. `prompt.submit` is never resent (gateway rule). The open chat sees the turn through its normal follow-up stream.

`queued: true`: the prompt must not steer or redirect a turn that runs in the chat at that moment. If a server runs it as `redirected` anyway, that is the server's behaviour; the live-backend check (first task of PR 2) shows what it does.

### Exactly once

iOS is expected to deliver a response once (unverified, see below), and the hand-off's offer-then-confirm makes one isolate the sender. There is no retry. The text is a `String` in the handler's frame; nothing writes it except in the one case below.

### What is kept

Decision: the typed text lives in memory while it is sent and is otherwise kept only to let the user get it back after "Reply not sent", and only as much as a notification body could already show.

- Kept in the "Reply not sent" notification's payload under a new key `'u'` (the existing `'q'` key means a new chat, so it cannot be reused) only if it is at most `kPreviewLength` (120) user-perceived characters, App Lock is off and loaded, the outcome is not signed out, and the failure is before submit. The payload carries the account hash `'a'` too. `targetFromPayload` reads `'u'` into a chat target that carries a draft and a profile. A tap in another account (hash mismatch) puts nothing in the composer and shows "Could not open that chat."; withdrawal on sign-out covers the usual path.
- The shell opens a `'u'` tap as a link does (`ChatOpenRequests.request(target, prompt:, fromLink: true)`), which switches to the chat's profile. This is an explicit exception to "Tapping a notification opens its chat", which for other notifications keeps the open chat and shows "Could not open that chat." for another profile. The exception is recorded in the spec and the main spec is amended on archive.
- The payload lives with the notification, on disk in the system's notification store. That is why the cap is the preview length, the length a "Reply ready" body already puts there, and why the text is never in preferences, files or logs.
- Lifetime: until the notification is tapped, cleared, withdrawn (App Lock, sign-out) or replaced. There is no expiry of its own; accepted, because a notification the user ignores sits in the system's store anyway. If that changes, a sweep on resume can withdraw `'u'` notifications older than a day.
- Longer text, `unconfirmed`, `app_locked`, signed out and `sent` keep nothing. The body, title, telemetry and breadcrumb never hold the text. No URL is stored.
- If notifications are off or the permission was revoked, the ending is not posted and no text is kept.

Why stricter than Ask Hermes: its not-sent notification keeps up to 4,000 characters and is not withdrawn when App Lock turns on or the user signs out. Text typed into a notification of a chat the user may want protected deserves the tighter rule; Ask Hermes should follow it later (roadmap finding).

### Ending notifications

Each is an `AttentionNotification` for the same chat (same id, so it replaces "Reply ready"), title the chat's title from the original payload, except under App Lock ("Hermes"). One rule for the two "not sent" bodies: "try again" when a text is kept in the payload, "write it again" in every other case (too long, signed out, account changed, App Lock). Bodies are fixed text:

| Ending                 | Body                                                        | Payload              |
| ---------------------- | ----------------------------------------------------------- | -------------------- |
| not sent, text kept    | Reply not sent. Open Hermes to try again.                   | chat, `'u'`, `'a'`   |
| not sent, no text kept | Reply not sent. Open Hermes to write it again.              | chat                 |
| could not confirm      | Couldn't confirm your reply was sent. Open Hermes to check. | chat                 |
| App Lock               | Open Hermes to reply.                                       | chat id only, so it replaces the Reply notification; no profile, no text |

They are plain default-level notifications with no category, like `kAnswerFailedBody`. Posting goes through a `LocalNotificationService(background: true)` in the lone isolate.

### Platforms and native changes

- iOS and iPadOS: no native code or entitlement. The background engine and plugin registration are `NotificationActions.registerPlugins` and `headless-runtime`'s. The response is handled in the plugin's isolate, or handed to the app's when it runs; never through `_onResponse`.
- macOS: the same category. The response reaches the app's isolate (the app is launched or activated for a text action); `_onResponse` and `launchTarget` handle it. `authenticationRequired` on macOS requires an unlocked Mac. No background check runs there.
- Android: not offered (proposal). Windows, Linux: no notification actions. watchOS: not designed.

### Invariants touched

- Auth: the headless runtime's rules (never signs out, gives up quietly on a refresh conflict).
- Notification bodies: all new bodies are fixed text; the existing App Lock rule is kept (generic "Reply ready", no action), and App Lock not yet loaded counts as on.
- Requests: `kReplyChatAction` is not `kReplyAction`; `answerFromResponse` never sees a reply, and a request notification's buttons answer only the id in its payload (`inline_reply.dart` never calls `request.answer`, `approval.respond` or `clarify.respond`).
- Telemetry, in `inline_reply.dart`: span `background.task` (`task: notification.reply`, `engine`), annotated `reply.outcome` (`answered`, `sent`, `failed`, `unconfirmed`) when the body ran; when the run ended first (signed out, locked store, unreachable, timeout) the span keeps the runtime's own `outcome`, because those are known only after the runtime ended the span (there is no `unavailable` outcome). A run-less span for an App Lock refusal. Log event `notification.reply` (`outcome`: the four, plus `signed_out`, `store_locked` (the headless runtime's locked keychain), `unreachable` and `app_locked` (App Lock); and `route`; the word `locked` is not used alone), breadcrumb in the foreground engine only. No text, title, profile or id.
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
- [App Lock or sign-out in the running app between the isolate's last App Lock read and its post of a kept-text notification] → `withdrawAnswerable` has already run, so that text survives until the notification is tapped or cleared. Decision: the app route re-reads App Lock in `postEnding`, and the isolate does too, so the window is the milliseconds between the read and the post; accepted.
- [App Lock turned on after the arrival check but before `prompt.submit`] → the text is still sent: the user's explicit send had already happened and a mid-flight cancel would leave the same ambiguity as a lost answer. Accepted; the ending that follows hides the title and text.
- [Stale notification, another account] → refused by the account hash; withdrawn on sign-out.

## Not verified without a device

That iOS delivers each response once and removes the notification after the action (on the `sent` path nothing replaces it until an answer arrives, so if it is not removed the user sees the old reply). Everything about the system's notification UI: that the text action shows on the Lock Screen only after unlock, the text field and "Send" button on iOS and macOS, that the Runner's engine finishes `prompt.submit` inside the background window, the hand-off with the running app, delivered-notification persistence of the payload, macOS launching the app for the response (cold launch). The contract (`queued`, the status values) is checked against the pinned OpenRPC; a live backend check is the first task of PR 2. The canvas draws the system UI as a neutral frame and shows only the app's own text.

## Migration Plan

Nothing to migrate. Notifications posted before the update have no reply action; new ones do.
