# Proposal

## Why

A "Reply ready" notification often calls for a short answer: "yes, book it", "try the other branch". Today that means opening Hermes, waiting for the chat to load and typing there. iOS and macOS let a notification take typed text in place. Hermes should send it into the chat in the background and announce the answer later as a normal notification.

This sends text to the agent from a notification. The user's typing the text and pressing Send in the notification is the explicit send for that one text; nothing else is ever sent from here.

## What Changes

- On iOS and macOS, a "Reply ready" notification for a chat gets a "Reply" action with a text field (button "Send", placeholder "Reply to Hermes"). The typed text is sent once as a new prompt into that chat (`prompt.submit` with `queued: true`) without opening the app.
- The action is offered only while App Lock is off and its saved setting has loaded (as for requests, unloaded counts as on). It requires the device to be unlocked (`authenticationRequired`). App Lock is checked again when the reply arrives, because it may have been turned on after the notification was posted; then nothing is sent and nothing is kept, and a notification says "Open Hermes to reply." Turning App Lock on withdraws notifications that carry the action.
- The answer arrives as the usual "Reply ready" (or request) notification: at once if it comes within the background window, otherwise through the background check for finished replies (`background-refresh`), which the system schedules, so it may wait until the user next opens the app. On macOS no background check runs, so a slow answer is seen when the chat is opened.
- When the text could not be sent, a "Reply not sent" notification says so; nothing is retried. When the prompt may have reached Hermes but the answer to `prompt.submit` was lost, a "Couldn't confirm" notification says so and nothing is resent.
- The unsent text is kept only when it is no longer than a reply preview (120 characters), in that notification's payload, so a tap can put it back in the composer (the open a `hermes://chat?...&prompt=` link makes, never sent). Longer text is not kept. See design.md, "What is kept".
- The action lives in the category `hermes.reply.ready.reply` with the action `hermes.action.reply-chat`, in `request_notifications.dart`. The existing placeholder-only category `hermes.reply.ready` stays for App Lock and for notifications that cannot be replied to. On iOS and iPadOS the response always goes through the Runner's `NotificationActions` (which handles every `hermes.action.*` id but Open, with the app in front or not) into `answerRequestInBackground`; on macOS it reaches the app's isolate through `LocalNotificationService._onResponse` and, at a cold launch, `launchTarget`. The background check's own "Reply ready" notifications carry the action too. The category ships with its handler, never before.

Non-goals:

- No inline reply on Android in this change. The reason is not the background engine (Android request actions already run `answerRequestInBackground` in the plugin's isolate, #914) but the lock screen: the plugin can set no authentication requirement on an Android action, and Android reply notifications are visible on a locked screen, so the action would let a locked phone steer a chat. A later change can post a replyable Android notification with secret visibility once #914 is verified on a device.
- No inline reply on Windows or Linux (no notification actions), or on watchOS.
- No reply to request notifications (approvals and questions have their own buttons and text answer) and none on "Reply failed", scheduled-task or message notifications.
- No attachments, model choice or slash commands from a notification.
- No answering of requests: the reply never goes through `request.answer`.

Security and privacy impact:

- Locked phone: `authenticationRequired`. App Lock: the action is not offered, is re-checked on arrival and is withdrawn when App Lock turns on. Ask Hermes by Siri is allowed while locked by the user's choice; a typed reply on the Lock Screen was not part of that choice.
- The typed text goes to Hermes like any prompt and is never logged, traced or shown in a notification's text. It is kept only as designed in "What is kept".
- Tokens are read by the headless runtime only (a background run never signs the user out).

Observability:

- Span `background.task` (from `headless-runtime`) with `task: notification.reply`, `engine`, annotated `reply.outcome` (`answered`, `sent`, `failed`, `unconfirmed`) when the body ran, and keeping the runtime's own `outcome` when the run ended first; a refusal for App Lock (`locked`) ends a run-less span, as Ask Hermes does. It crosses the gateway.
- Log event `notification.reply` with `outcome` and `route` (`main` or `background`); breadcrumb `notification.reply` with `outcome`.
- None carries the text, a title, a profile name or an id.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `notifications`: adds the inline reply on "Reply ready" notifications, its App Lock rules and the "Reply not sent" and "Couldn't confirm" notifications.

## Impact

- Dart: `lib/src/notifications/inline_reply.dart` (send through `withHeadlessHermes` and the transport's `send(queued: true)`, which, unlike `sendQueued`, accepts a chat with no profile), the category and action in `request_notifications.dart`, `attentionFor` (category choice by App Lock, a payload marker), a branch in `routeAnswer`/`LoneAnswerer`, in the running app's side of the hand-off (`RequestAnswers._onMessage`), in `LocalNotificationService._onResponse` and `launchTarget` (macOS), `targetFromPayload` and the shell's open path for the kept-text tap, `RunningRepliesStep` (it builds its own notification), a typed send failure and an `onSubmitting` callback in the gateway transport, `withdrawAnswerable` (also withdraws replyable notifications), and one footnote line in the Notifications dialog.
- iOS and macOS: no native code or entitlement; `flutter_local_notifications` supports text-input actions and background responses. The categories are re-registered through `registerCategoriesNatively`, which already takes the static list.
- Dependencies, all on main: #587/#589 (request actions), `headless-runtime`, `deep-links`, `ask-hermes` (running-reply record), `background-refresh`.
- Backend: no new routes; `session.resume`, `prompt.submit`.
