# Design

## Context

See proposal.md for motivation and specs/live-activities/spec.md for behavior.

Every reply event already passes through `ChatController._onReplyEvent`, which hands the announceable ones to `AttentionNotifier.announce`. The send path (`ChatController.send` → `_streamReply`) is where the notification permission is first requested. `NotificationSettings` persists the notification switches in `SharedPreferencesAsync` with the edit-counter pattern that lets a change made during `load()` win. The iOS Runner already has the App Group `group.com.cedricziel.hermesApp` (`CUSTOM_GROUP_ID`), a deployment target of iOS 26, and two embedded extensions (ShareExtension, HermesWatch) whose Debug bundle IDs are prefixed with `com.cedricziel.hermesApp.dev`.

ActivityKit constraints that shape the design:

- Without push-to-start, `Activity.request` only succeeds while the app is in the foreground. The send is the one moment the app is guaranteed to be there.
- Without push updates, only the running process can update an activity. After iOS suspends the app (seconds after it leaves the foreground, since the websocket holds no background mode), the activity is frozen until the app resumes.
- `staleDate` lets the system flip an activity to a stale presentation on its own, which is the only way to tell the user that what they see may be old.
- An activity outlives the process; a relaunched app finds it in `Activity.activities` but has no reply state to continue it.

## Goals / Non-Goals

**Goals:**

- One Dart owner for activity lifecycle, testable without iOS through a fake platform interface.
- No change to the chat's event flow or to notification behavior.

**Non-Goals:**

- A generic activity framework for Kanban or schedules. The model is shaped for chat replies only.
- Rich Dynamic Island content (progress bars, tool names).

## Decisions

### Use the `live_activities` plugin (2.6.0) rather than a hand-written channel

It bridges `Activity.request/update/end`, authorization state, and URL-scheme taps (`urlSchemeStream`) through an App Group, which the app already has. It is maintained (latest release September 2026), iOS-only as needed, and widely used. A hand-written `MethodChannel` like `WebAuthSession.swift` would be about 150 lines of Swift plus its own data-sharing; the plugin removes that. The plugin requires the extension to declare `LiveActivitiesAppAttributes` and read values from the shared `UserDefaults` by prefixed key, which we accept.

Alternative: write ActivityKit code in the Runner. Rejected per the project's dependency rule; revisit only if the plugin blocks a needed behavior (for example `staleDate`, see Risks).

### `LiveActivityController` beside `AttentionNotifier`, fed by `ChatController`

New module `lib/src/live_activities/`:

- `live_activity_state.dart`: a pure function `activityStateFor(ChatEvent, current)` returning the next `ReplyActivityState` (`working`, `approval`, `question`, `needsYou`, `ready`, `failed`) or an end instruction (`stopped`). It reuses the label constants from `attention_policy.dart` (`kApprovalBody`, `kQuestionBody`, `kNeedsYouBody`, `kReplyReadyBody`, `kReplyFailedBody`) so the two surfaces never word things differently.
- `live_activity_service.dart`: an interface (`start`, `update`, `end`, `endAll`, `allowed`, `taps`) with the plugin implementation and a no-op for other platforms. Tests use a fake.
- `live_activity_controller.dart`: keyed by the same `profile/threadId` key as notifications, holds one activity id per chat, tracks app focus (`WidgetsBindingObserver`) to set the stale date one minute ahead on updates while not focused (the plugin takes whole minutes) and push it eight hours out when focused (the plugin keeps the previous stale date when none is given, so it cannot be cleared), and coalesces updates so only a state change, a title change or a focus change reaches iOS (ActivityKit throttles frequent updates).

`ChatController` gets the controller next to `_attention` and calls `begin` in `_streamReply` (the activity must be requested while the app is in front, which only the send guarantees) and `onEvent` from `_onReplyEvent` for every event and from `_announce`, using the same synthesized `ReplyCompleted` the notifier sees for a settled turn, so "broke" and "stopped" are judged once. Activities are keyed by chat, so a prompt folded into a running turn keeps the activity the running turn already has. A finished activity ignores events until the next `begin`, which ends it at once and starts a new one, because an ended ActivityKit activity cannot be updated.

Alternative: hook into `AttentionNotifier`. Rejected: it only sees announceable events and is gated on the notification switch and the attention policy, neither of which applies here.

### Ending rules live in Dart, dismissal timing in ActivityKit

A final state is sent with `end(dismissalPolicy: .after(now + 15 min))`, so iOS removes it even if the app never runs again. Stop, delete, sign-out and setting-off use `.immediate`. On startup the controller calls `endAll` before the first send, which covers activities orphaned by termination. Sign-out is wired through `AuthController`'s existing sign-out path (the same place conversation windows are closed).

### Taps through the existing notification target

The extension sets `widgetURL` to `hermes-activity://open?thread=<id>&profile=<name>`. The controller turns `urlSchemeStream` events into `NotificationTarget`s and hands them to the same `onOpen` the notifier uses; a cold-start URL is offered through the same "launch target" path. This gives taps the notification spec's behavior for free. The scheme is added to `CFBundleURLSchemes` in the Runner's Info.plist.

### Setting stored with the notification settings

`NotificationSettings` gains `liveActivities` (key `hermes.live_activities`, default true) with its own edit counter. `NotificationsDialog` shows the switch only when `defaultTargetPlatform == TargetPlatform.iOS`, plus the system-settings hint when the service reports `allowed == false`.

### Widget extension

A new `HermesLiveActivity` widget extension target (SwiftUI, `ActivityConfiguration(for: LiveActivitiesAppAttributes.self)`):

- Lock Screen: Hermes icon, chat title (one line), state label, `Text(timerInterval:)` for working, a stale note when `context.isStale`.
- Dynamic Island: compact leading icon, compact trailing timer or state glyph; minimal icon; expanded shows title and label.

Platforms affected: iOS only. Native changes: new extension target in `ios/Runner.xcodeproj` (embedded in Runner, App Group entitlement `$(CUSTOM_GROUP_ID)`, bundle ID `com.cedricziel.hermesApp.LiveActivity` in every configuration, like the other extensions), `NSSupportsLiveActivities = YES` and the `hermes-activity` URL scheme in `ios/Runner/Info.plist`, fastlane match/signing for the new bundle ID in `fastlane/Fastfile`. No Android manifest, macOS or watchOS change.

### Invariants touched

- Tokens: none are written to the App Group or the activity; the payload is title, state, start time, thread id and profile. The profile name is in the App Group container (on-device, app-group-private) and in the tap URL; it never reaches the Lock Screen text.
- Telemetry: crumbs only, through `Breadcrumbs`; failures in the plugin are caught so a missing ActivityKit never breaks a send.
- API layering and generated client: untouched.
- Tests: the controller is tested with a fake `LiveActivityService` and `FakeChatTransport`; `ChatController` integration tests keep using `FakeHermesServer` for REST.

## Risks / Trade-offs

- [The activity is frozen while the app is suspended] → `staleDate` plus "Open Hermes for the latest"; this is stated in the setting's description so it is not mistaken for push.
- [The plugin takes the stale delay in whole minutes and cannot clear it] → checked in 2.6.0: `staleIn` is rounded to minutes (anything under one is dropped) and an update without it keeps the old stale date. The spec uses one minute, and a resume pushes the stale date eight hours out.
- [The plugin does not deliver a URL that cold-starts the app] → `SceneDelegate` keeps the launch URL from `connectionOptions` and a small `hermes_app/live_activity` channel hands it to Dart once.
- [ActivityKit throttles updates and caps concurrent activities] → coalesce updates to state/title/focus changes; a refused start is dropped silently.
- [Xcode project churn from adding a target] → add the target with Xcode once, commit only `project.pbxproj`, the extension folder and entitlements; the reviewable Dart and Swift diff stays near 500 lines.
- [Tap URL scheme could be invoked by another app] → the URL only selects a chat by id among the already loaded threads; an unknown id shows "Could not open that chat."

## Migration Plan

Ships behind the default-on setting; nothing to migrate. Rollback is removing the extension from the Runner's embed phase; leftover activities are ended by iOS after their dismissal time or the next launch of a build that still has the controller.
