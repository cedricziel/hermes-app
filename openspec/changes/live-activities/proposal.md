# Proposal

## Why

Agent turns often run for minutes. On iPhone the user sends a prompt, locks the phone or switches apps, and then has no way to see whether Hermes is still working, waiting for an approval, or done, until a notification arrives. A Live Activity on the Lock Screen and in the Dynamic Island shows that state at a glance, which is what iOS users expect from a long-running task.

## What Changes

- When the user sends a prompt from the iPhone app, the app starts a Live Activity for that chat (one per chat, at most one per chat at a time).
- The activity shows the chat's title and one of these states: working (with an elapsed-time counter), waiting for an approval, has a question, waiting for the user in Hermes, reply ready, reply failed. It follows the same privacy rule as notifications: no reply text, command, question or secret on the Lock Screen.
- The app updates the activity from the events it already receives on its chat connection. Hermes has no push channel, so the activity can only change while the app runs. When the app is suspended mid-reply, the activity goes stale after a short time and says to open Hermes; it catches up when the app returns.
- A finished activity stays on the Lock Screen for 15 minutes, then iOS removes it. A stopped reply, sign-out, or turning the feature off ends it at once. Activities left over from an earlier launch are ended when the app starts.
- Tapping the activity opens its chat, the same way a notification tap does.
- The Notifications dialog gets a "Live Activities" switch on iOS, on by default.
- A new iOS widget extension target (`HermesLiveActivity`) renders the Lock Screen and Dynamic Island views.

Non-goals:

- No push updates (ActivityKit push tokens, push-to-start). Hermes has no push service.
- No activity for turns the user did not send from this phone: watch turns, goal continuations, queued follow-ups, scheduled task runs, Kanban tasks.
- No answering an approval or question from the activity (no interactive buttons). The user opens the app to answer.
- No Live Activities on Android, macOS or the watch's Smart Stack (the watch mirrors iPhone activities by itself; no watch-specific layout).
- No reply preview, tool names or token counts in the activity.

Security and privacy impact: the activity is visible on a locked device, so it carries only the chat title and a fixed status label, never reply text, commands, questions or secret names (the same rule as notification bodies). No token, server address or profile name is written to the shared App Group; the activity's data holds the chat title, the status, the start time, and the thread id and profile needed to open the chat on tap. Nothing goes to telemetry beyond the crumbs listed below.

Telemetry: breadcrumbs only (not exported unless a crash is reported): `live_activity.started`, `live_activity.ended` with `outcome` (`completed`, `failed`, `stopped`, `signed_out`, `disabled`, `orphaned`), and `live_activity.unavailable` when iOS refuses to start one. No text, titles or ids.

## Capabilities

### New Capabilities

- `live-activities`: the iOS Live Activity for a running reply: when it starts, which states it shows, how it goes stale and ends, the tap target, the setting, and what it may show on a locked screen.

### Modified Capabilities

None. Notifications keep their current behavior; the Live Activity is shown in addition to them.

## Impact

- Dart: a new `lib/src/live_activities/` module fed from `ChatController` (send and reply events), the setting in `NotificationSettings` and `NotificationsDialog`, `AuthController` sign-out, and the tap handling next to the notification tap path.
- Dependency: the `live_activities` plugin from pub.dev (ActivityKit bridge through the existing App Group `group.com.cedricziel.hermesApp`).
- iOS: a new widget extension target, `NSSupportsLiveActivities` in the Runner's Info.plist, a URL scheme for taps, and an App Group entitlement on the extension. Debug bundle ID prefixed with `com.cedricziel.hermesApp.dev`; fastlane signing for the new target.
- Backend: no new routes or RPC methods. Uses the gateway events the chat already maps.
