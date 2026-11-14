# Design

## Context

iOS and macOS already answer requests from notification buttons (`request_notifications.dart`: categories, action ids, payload, `answerFor`; `request_answers.dart`: `request.answer` with the older `approval.respond` / `clarify.respond` fallbacks; the background isolate hands the answer to the running app through `IsolateNameServer` or answers alone with `LoneAnswerer` on `withHeadlessHermes`). Android used the generic bodies and no actions.

`flutter_local_notifications` 22.3.3 supports Android actions (`AndroidNotificationAction`, with `showsUserInterface`, `cancelNotification` and `AndroidNotificationActionInput` for a text reply) delivered to a top-level background callback in the plugin's own isolate.

## Decisions

**Same eligibility as iOS.** An approval with at least one known choice and a single question are answerable; several questions, an approval with no known choice, and secret, sudo, vault and unsupported requests are not. Not answerable, App Lock on, or App Lock not yet loaded: generic body, no actions, default visibility, unchanged.

**Lock screen: secret visibility.** The plugin cannot set a public version (`setPublicVersion`) nor `setAuthenticationRequired` on an action. With `private` visibility a lock screen set to show all content would show the command and working buttons, while iOS requires authentication for its actions. `secret` hides the notification, text and actions until the device is unlocked, which is the closest equivalent. The cost: no "Waiting for your approval" hint on the lock screen; the user sees the notification after unlocking. Accepted.

**Three actions at most.** Android shows three. Approvals keep the order Allow once, Allow for session, Always allow, Deny among the offered choices; when all four are offered Always allow is dropped (it can still be given in the chat). A question with choices: 1 or 2 choices plus "Reply" (a `RemoteInput`, label "Your answer"); exactly 3 choices and no "Reply"; more than 3 choices, the first two plus "Other…", which opens the chat. An open-ended or multi-select question: "Reply" and "Open". Action ids are the iOS ones (`hermes.action.*`), so one `answerFor` serves both.

**Same answer path as iOS.** The action's background callback runs `answerRequestInBackground`, which calls `prepareBackgroundIsolate()` first, then offers the answer to the running app's isolate over the `IsolateNameServer` port (the app registers it on Android too), else answers alone with `LoneAnswerer` on `withHeadlessHermes`. The whole thing has 25 s from the tap. Android has no background-launch grace like iOS, so the limit is our own. A failure, `expired` or nobody signed in posts "Couldn't send your answer. Open Hermes to answer." under the same notification id, replacing the request notification.

**Removal.** An answering action sets `cancelNotification` so the notification goes when tapped; "Other…" and "Open" show the user interface and open the chat. After a failure the follow-up is posted again, so nothing is lost.

**App Lock.** Turning it on cancels the answerable request notifications on Android as on iOS and macOS. An action used while App Lock is on sends nothing and posts "Open Hermes to answer.".

**Manifest.** The plugin's `ActionBroadcastReceiver` is declared with `android:exported="false"`.

**Platforms.** Android (code and manifest). iOS, macOS, Windows, Linux and watchOS unchanged. No entitlement.

**Invariants touched.** Auth: a button answer never signs the user out (headless runtime). Telemetry: unchanged; nothing about the request enters a span, log or breadcrumb.

**Observability.** None new; the existing answer outcome signals cover Android because the path is shared.

## Risks / Trade-offs

- [Not verified on a device] No Android device in CI; CI builds the release APK only. Manual check on an emulator is left to the author.
- [Secret visibility] Users whose lock screen hides notifications already see nothing; users who allow content lose the hint. Accepted for the privacy.
- [OEM background limits] An aggressive OEM may kill the background isolate before 25 s; the user then sees no follow-up. The request stays answerable in the app.
