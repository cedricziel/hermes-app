# Proposal

## Why

When Hermes stops a turn to ask for an approval or a question, the notification only says that Hermes is waiting. The user has to unlock the phone, open the app, find the chat and answer. Most of these requests are a single tap ("Allow once", "Yes"). A turn sent from the watch is worse off: the watch cannot answer at all, so the send ends with "Ask again on your iPhone" and the turn sits there.

## What Changes

- Approval notifications on iOS and macOS get four actions: Allow once, Allow for session, Always allow and Deny, limited to the choices Hermes offered. Always allow and Deny are marked destructive. Always allow has no extra confirmation step.
- Question notifications get one button per choice when there are at most four, or the first three and "Other…", which opens the app, when there are more. A "Reply" text-input action is always there. A multi-select question gets only Reply and Open. A request with several questions keeps the generic notification without actions.
- Every action needs the device to be unlocked (`authenticationRequired`) and, except Open and Other…, runs in the background without opening the app.
- Request notification bodies now show the command (approval) or the question. Each request category has a hidden-preview placeholder ("Waiting for your approval", "Has a question for you"), so the system's Show Previews "When Unlocked" setting keeps the text off a locked screen. This replaces the rule that request notifications stay generic.
- An answer from a notification goes to Hermes with `request.answer` on a fresh gateway connection. When the main app is alive the answer is sent from its isolate; otherwise the iOS background isolate signs in from the stored session and sends it. When that fails, or the request is gone, a follow-up notification says "Couldn't send your answer. Open Hermes to answer." and opens the chat.
- Secret, sudo, vault and unsupported requests are unchanged: generic text, no actions.
- While App Lock is on, approvals and questions also keep the generic text and get no actions; tapping opens the app, which asks to unlock first.
- A turn sent from the watch no longer ends at an approval or a question. The phone posts the actionable notification (which watchOS mirrors), the watch shows "Waiting for your approval" or "Hermes has a question", and the send keeps waiting until the turn continues. Secret, sudo, vault and unsupported requests still end the turn as today.

Non-goals:

- Android. Its notifications keep their current behaviour (generic bodies are kept there too, since Android has no per-category hidden-preview placeholder).
- Answering secret, sudo or vault prompts from a notification.
- Answering a question batch with several questions from a notification.
- Push delivery. Hermes has no push channel; notifications are still posted only by a running app.
- Live Activity buttons. The Live Activity stays informational.
- Withdrawing a request notification when the request is answered elsewhere or expires.

## Capabilities

### Modified Capabilities

- `notifications`: request notification bodies, the actions they carry, how an answer is sent, the follow-up on failure, and the watch-turn notification rules.
- `watch`: a watch send waits through an approval or a question instead of ending.

## Security and privacy impact

- Command and question text now reaches the notification centre. On a locked device it is hidden only when the user's Show Previews setting is "When Unlocked" or "Never" (the iOS default is "When Unlocked"). With "Always" it shows on the lock screen. This is the trade-off the user chose. The Notifications dialog says so.
- Every answer action requires the device to be unlocked. Always allow is a one-tap permanent grant, protected only by that.
- The notification payload carries the request id, the question id and the choice titles shown as buttons, so the answer can be built without the app's state. It holds no token or server address.
- The background isolate reads the stored session from the keychain, the same entry the main app uses (readable after first unlock). It answers through the main isolate when one runs, and its own answers go one at a time on one sign-in. When a refresh is rejected, `AuthController` takes over a newer pair another isolate stored instead of signing the user out.
- App Lock keeps request text and buttons out of notifications.
- The Runner keeps the last 20 question categories (their button titles are the offered choices) in `UserDefaults`; signing out drops them.

## Observability

- Log event `notification.answer` through the connection's `AppEventLogger` in the main isolate, with `kind` (`approval`, `question`), `outcome` (`ok`, `expired`, `failed`, `signed_out`) and `route` (`main`, `background`). It answers whether answering from a notification works and how often the request is already gone. No ids, text or choices.
- Log event `auth.session.adopted` when a rejected refresh takes over a pair another isolate stored, with no attributes: it shows how often the isolates race.
- Breadcrumb `notification.answered` with `kind` and `outcome`, so a later crash shows the step.
- The background isolate has no telemetry (no SDK runs there). Its outcome reaches the main isolate's log only when it routes through the main isolate.

## Impact

- `lib/src/notifications/` (categories, payload, answer routing, attention policy), `lib/src/chat/chat_transport.dart` and the gateway transport (`answerOpenRequest`), `lib/src/watch/watch_request_handler.dart`, `lib/main.dart` wiring.
- iOS Runner `AppDelegate.swift` (plugin registrant for the background engine, the categories channel, a background task channel) and macOS `MainFlutterWindow.swift` (the categories channel). No new files in the Xcode projects, no entitlement change.
- `ios/HermesWatch`: the relay client reads the waiting state and the conversation shows it.
