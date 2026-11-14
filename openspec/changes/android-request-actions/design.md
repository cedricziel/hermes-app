# Design

## Context

iOS and macOS already answer requests from notification buttons (`request_notifications.dart`: categories, action ids, payload, `answerFor`; `request_answers.dart`: `request.answer` with the older `approval.respond` / `clarify.respond` fallbacks; the background isolate hands the answer to the running app through `IsolateNameServer` or answers alone with `LoneAnswerer` on `withHeadlessHermes`). Android used the generic bodies and no actions.

`flutter_local_notifications` 22.3.3 supports Android actions (`AndroidNotificationAction`, with `showsUserInterface`, `cancelNotification` and `AndroidNotificationActionInput` for a text reply) delivered to a top-level background callback in the plugin's own isolate.

## Decisions

**Same eligibility as iOS, plus a visible body.** An approval with at least one known choice and a single question are answerable, and on Android only when the body shows what is asked: a request posted by the background refresh, which never reads the command and posts the generic body, gets no buttons on Android, so nobody approves a command they never saw; several questions, an approval with no known choice, and secret, sudo, vault and unsupported requests are not. Not answerable, App Lock on, or App Lock not yet loaded: generic body, no actions, default visibility, unchanged.

**Lock screen: secret visibility.** The plugin cannot set a public version (`setPublicVersion`) nor `setAuthenticationRequired` on an action. With `private` visibility a lock screen set to show all content would show the command and working buttons, while iOS requires authentication for its actions. `secret` hides the notification, text and actions until the device is unlocked, which is the closest equivalent. The cost: no "Waiting for your approval" hint on the lock screen; the user sees the notification after unlocking. Accepted.

**Three actions at most.** Android shows three. Approvals keep the order Allow once, Allow for session, Always allow, Deny among the offered choices; when all four are offered Always allow is dropped (it can still be given in the chat). A question with choices: 1 or 2 choices plus "Reply" (a `RemoteInput`, label "Your answer"); exactly 3 choices and no "Reply"; more than 3 choices, the first two plus "Other…", which opens the chat. An open-ended or multi-select question: "Reply" and "Open". Action ids are the iOS ones (`hermes.action.*`), so one `answerFor` serves both.

**Same answer path as iOS.** The action's background callback runs `answerRequestInBackground`, which calls `prepareBackgroundIsolate()` first, then offers the answer to the running app's isolate over the `IsolateNameServer` port (the app registers it on Android too), else answers alone with `LoneAnswerer` on `withHeadlessHermes`. The whole thing has 25 s from the tap. Android has no background-launch grace like iOS, so the limit is our own. A failure, `expired` or nobody signed in posts "Couldn't send your answer. Open Hermes to answer." under the same notification id, replacing the request notification.

**Removal.** An answering action sets `cancelNotification` so the notification goes when tapped; "Other…" and "Open" show the user interface and open the chat. After a failure the follow-up is posted again, so nothing is lost.

**App Lock.** Turning it on cancels the answerable request notifications on Android as on iOS and macOS. The plugin returns no payload for active notifications on Android, so answerable ones are posted with the tag `hermes.request` and withdrawn by that tag. Android keys a notification by tag and id, so a post for a chat first cancels the other variant (tagged or not) of the chat's id, keeping one notification per chat. An action used while App Lock is on sends nothing and posts "Open Hermes to answer.".

**Manifest.** The plugin's `ActionBroadcastReceiver` is declared with `android:exported="false"`.

**Platforms.** Android (code and manifest). iOS, macOS, Windows, Linux and watchOS unchanged. No entitlement.

**Invariants touched.** Auth: a button answer never signs the user out (headless runtime). Telemetry: unchanged; nothing about the request enters a span, log or breadcrumb.

**Observability.** None new; the existing answer outcome signals cover Android because the path is shared.

## Risks / Trade-offs

- [Not verified on a device] No Android device in CI; CI builds the release APK only. Manual check on an emulator is left to the author.
- [Secret visibility] Users whose lock screen hides notifications already see nothing; users who allow content lose the hint. Accepted for the privacy.
- [Process kept alive] The plugin's `ActionBroadcastReceiver` cancels the notification, starts its engine and returns without `goAsync()`, a foreground service or a WorkManager job. When the app is in the background, Android (14+ freezes cached processes) or an aggressive OEM may freeze or kill the process before the answer is sent; the notification is already gone and no follow-up is posted. The request stays answerable in the app. Not measured on a device. Follow-up if it shows: hand the answer to an expedited one-off WorkManager task (`workmanager` is already a dependency). A process started only for the broadcast skips the 3 s wait for the app's port, which exists only on iOS.
- [Wear OS] `secret` visibility affects the phone's lock screen only; a paired Wear OS watch may show the bridged body and actions, as an Apple Watch mirrors the iOS notification. The plugin cannot set `setLocalOnly`. Accepted, like the watch mirroring on iOS.
