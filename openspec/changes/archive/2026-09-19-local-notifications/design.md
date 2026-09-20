## Context

A reply can take a while, and the agent can stop mid-turn to ask for an approval or an answer. If the user has switched to another app or another thread, they only find out when they come back.

This was the second of two features. The first, answering agent requests from inline cards (`openspec/changes/archive/2026-09-19-agent-input-requests/`, PR #55), supplies the `ApprovalRequested` and `ClarifyRequested` events this feature reacts to.

Local notifications need the app to be running and connected to the gateway, because the events arrive over the `/api/ws` socket. Desktop keeps the socket while the window is in the background. iOS and Android suspend the app soon after it leaves the foreground, so a reply that finishes later never reaches the app. The settings dialog says so: "Alerts arrive while Hermes is running, including for a short time after you leave it."

## Goals / Non-Goals

**Goals:**

- A notification when a reply finishes, an approval is requested, or a clarify question is asked, while the app is not focused or the event belongs to a thread that is not on screen.
- macOS, iOS and Android.
- Ask for permission once, after the first send.
- An on/off switch in the app.
- Tapping a notification opens its thread.

**Non-Goals:**

- Push notifications (APNs/FCM) and anything that needs the backend to reach a closed app.
- Windows and Linux. The service does nothing there, so the app keeps working.
- A background isolate for notification actions (approve or deny from the notification).
- Notification content for `secret.request` and `sudo.request`, which the app does not handle yet.

## Decisions

Follow the pattern of the dark-mode setting: a `ChangeNotifier` backed by `SharedPreferencesAsync`, a small dialog, and an entry in the sidebar menu next to Appearance.

**Pieces.**

- `NotificationService` (interface): request permission, `show(threadId, title, body)`, and a stream of taps carrying a thread id. `LocalNotificationService` implements it with `flutter_local_notifications` on macOS, iOS and Android and does nothing elsewhere. Tests use a fake.
- `NotificationSettings` (`ChangeNotifier`): an `enabled` switch, default on, and a `permissionAsked` flag, both persisted.
- `AttentionPolicy` (pure Dart, a single function `attentionFor`): given an event, whether the app is focused, the thread on screen and the switch, returns the notification to show or nothing.
- Focus: a `WidgetsBindingObserver` on the chat screen. Only `AppLifecycleState.resumed` counts as focused.
- Hook: `_onReplyEvent` in `chat_screen.dart` asks the policy about `ReplyCompleted`, `ApprovalRequested` and `ClarifyRequested`, and passes the result to the service.
- Tap: the tap stream selects that thread, the same way clicking it in the sidebar does.
- Permission: requested once, right after the first send, only when the switch is on and `permissionAsked` is false.

**Policy.** Notify when the app is not focused, or when the event's thread is not the selected one. A focused app showing that thread never notifies. With the switch off, nothing is notified and permission is never requested.

**Content.**

- Title: the thread's title.
- Finished reply: a preview of the reply. Whitespace is collapsed and the text is cut at about 120 characters with an ellipsis. A failed reply says "Reply failed".
- Approval: "Waiting for your approval". Clarify: "Has a question for you". These stay generic on purpose: an approval command must not appear on a lock screen.
- Payload: the thread id, nothing else.
- A new notification for a thread replaces the earlier one for that thread.

**Platform setup.**

- iOS and macOS: initialize with `DarwinInitializationSettings` with the alert, badge and sound permission requests turned off, so the prompt only appears when the app asks. Request through `requestPermissions`.
- Android: add `POST_NOTIFICATIONS` to the manifest, create one channel ("Agent activity"), and request permission with `requestNotificationsPermission()` on Android 13 and up.
- Tap while running: the plugin's response callback pushes the payload into the tap stream.
- Tap that starts the app: read `getNotificationAppLaunchDetails()` at startup and select that thread.

**Errors.**

- Showing a notification never fails the turn. Exceptions are caught inside the service.
- When the OS denies permission, the switch stays on and nothing is posted. The dialog then says to turn notifications on for Hermes in system settings.

**Testing.**

- Unit: `AttentionPolicy` for every combination of focused or not, same or different thread, and switch on or off; preview trimming; failed reply text.
- Unit: `NotificationSettings` persistence, in the style of `theme_controller_test.dart`.
- Widget: with the fake service, a finished reply while unfocused, a request in another thread, no notification while focused on the same thread, permission asked once after the first send, and a tap selecting the thread.
- Plugin wrapper: only its pure helpers are unit tested (payload to thread id, notification id per thread). A method-channel mock of the plugin itself would pass on a macOS host and fail on the Linux CI host, where the plugin does not use a channel, so the plugin calls are covered by the manual pass and the platform builds.
- Manual: one pass on macOS, since real notifications cannot be shown from tests. `PRIVACY.md` is checked for wording that a notification preview might affect.

## Platforms and invariants

- Platforms: macOS, iOS and Android post notifications. Windows and Linux do nothing. watchOS is not affected. Native changes: Android `POST_NOTIFICATIONS` in the manifest (and whatever the plugin's README requires for the build), and the iOS and macOS notification-center delegate where the plugin needs it.
- Invariants touched: none of the auth or API-layering invariants. The design adds no REST call. It keeps the rule that nothing sensitive shows on a lock screen, with generic bodies for approvals and questions. Notification failures are swallowed inside the service, in line with the rule that optional features never break the app.

## Risks / Trade-offs

- Local notifications only work while the app runs and holds the socket. On iOS and Android that is a short window after leaving the app.
- A denied OS permission leaves the switch on with nothing posted; the dialog explains where to turn it on.
- The plugin calls have no unit tests on purpose (see Testing), so they rest on the manual pass and the platform builds.
