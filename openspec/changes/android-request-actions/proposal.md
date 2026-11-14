# Proposal

## Why

On iOS and macOS an approval or question notification shows what the agent asks and carries buttons that answer it without opening the app. On Android the same notification only says "Waiting for your approval" or "Has a question for you" and a tap opens the app, so the user on Android has to unlock, open the chat and answer there while the turn waits.

## What Changes

- On Android, an approval or single question the app can answer shows the command (or description) or the question as its body, cut like iOS and macOS, and carries answer actions.
- Android shows at most three actions, so the set is fitted to three: approvals show the offered choices among Allow once, Allow for session, Always allow and Deny, dropping Always allow when all four are offered; a question shows one or two choices plus "Reply", or exactly three choices, or the first two choices plus "Other…"; an open-ended or multi-select question shows "Reply" and "Open".
- Such notifications are posted with secret lock screen visibility, so neither the text nor the actions show on a locked device.
- An action answers through the path iOS already uses: the plugin's background isolate hands the answer to the running app's isolate, or answers alone with the headless runtime, within 25 seconds. A failure or expiry posts "Couldn't send your answer. Open Hermes to answer.".
- Turning App Lock on withdraws answerable notifications on Android too. Requests the app cannot answer, and every request while App Lock is on, keep the generic body and no actions.
- The manifest declares the notification plugin's action receiver.

Non-goals:

- No change to the inline "Reply ready" reply (see `notification-inline-reply`), to the notification channels, or to the Android 13 permission prompt.
- No Android time-sensitive level, grouping or badge change.
- No public version of a notification (see design).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `notifications`: "Notification body" no longer keeps the generic bodies on Android; "Answering a request from its notification" covers Android with its own action set and lock screen rule.

## Impact

- Code: `lib/src/notifications/` (request notification builder, action ids, the Android action set, the background action entry point, answer hand-off registration), `main.dart` (register the hand-off port on Android), the App Lock withdrawal path, `AndroidManifest.xml`.
- Native: one manifest receiver (`ActionBroadcastReceiver`, not exported). No new permission.
- Backend: no new route; `request.answer`, `approval.respond` and `clarify.respond` as on iOS.
- Security and privacy: the command or question now appears in an Android notification, as on iOS and macOS. It is hidden from the lock screen (secret visibility), omitted while App Lock is on, and never logged. A button answer is sent with the stored session as on iOS; no token handling changes.
- Observability: the existing request-answer signals apply unchanged on Android (the answer's span and failure log carry outcomes only). No new signal, because the path is shared; none holds a command, question, profile or id.
- Verification: not run on an Android device (none in CI); CI builds the release APK.
