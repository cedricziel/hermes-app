# Design

## Context

See proposal.md for motivation and specs/notifications/spec.md for behavior.

On main (#587, #589):

- `attentionFor` (`lib/src/notifications/attention_policy.dart`) turns a `ChatEvent` into an `AttentionNotification` with `threadId`, `profile`, title, body and, for a request, a `category` from `requestCategoryFor` (`request_notifications.dart`). The body carries the command or question, cut at 1000 characters; under App Lock the placeholder categories (`hermes.request.approval`, `hermes.request.questions`) and their placeholder bodies are used.
- Category ids: `hermes.request.approval.<choices joined by ->` (`kApprovalCategoryPrefix`), `hermes.request.approval` (`kApprovalPlaceholderCategory`), `hermes.request.questions` (`kQuestionPlaceholderCategory`), `hermes.request.question` (`kQuestionCategory`, open-ended) and `hermes.request.question.<fnv1a hex>` (dynamic, `RequestCategory.isDynamic`). Actions: `hermes.action.allow-once|allow-session|allow-always|deny`, `hermes.action.choice.0..3`, `hermes.action.reply` (`kReplyAction`), `hermes.action.open` (`kOpenAction`).
- `LocalNotificationService.show` builds `DarwinNotificationDetails(categoryIdentifier: category?.id)` and the Android details, one id per chat (`notificationIdFor`).
- On iOS the Runner sets `NotificationActions.shared` as the `UNUserNotificationCenter` delegate in `didFinishLaunching`; it handles `hermes.action.*` except Open and forwards everything else to the plugin's delegate.

`surface-snapshot` keeps the pending list (`pending` rows) and lets listeners subscribe to its writes.

## Goals / Non-Goals

**Goals:**

- Every addition sits in `LocalNotificationService.show`'s details, not in a second notification path.

**Non-Goals:**

- A Notification Content Extension: the body already carries the command or question since #587.
- Changing which events notify, their bodies, ids, categories, actions or taps, or the `NotificationActions` delegate chain.

## Decisions

### Grouping

`AttentionNotification` gains `groupKey`: `chat:<percent-encoded profile>/<thread id>` for a chat, `job:<percent-encoded profile>/<job id>` for a task. `show` sets it as `threadIdentifier` (iOS, macOS). Android gets no `groupKey`: one notification per chat leaves every group with a single entry and no summary, and an explicit key may stop the system's own auto-bundling.

### Interruption level

`show` sets `interruptionLevel: InterruptionLevel.timeSensitive` on iOS and macOS when the notification is a request (`notification.category != null`, which covers every `hermes.request.*` category, placeholders included) or a secret/sudo/unsupported-input notification, and leaves the default (`active`) for reply and task notifications. The Runner gets `com.apple.developer.usernotifications.time-sensitive` in `ios/Runner/Runner.entitlements` and, for the Mac, adds it to `macos/Runner/Release.entitlements` from the fastlane `build_target` lane (`set_info_plist_value`) before archiving. It is not checked in for macOS: the entitlement is restricted, and both Debug and a local ad-hoc `flutter build macos --release` would be killed at launch with it. The `bootstrap_app` lane reminds to enable the capability in the portal and regenerate the `fastlane match` profiles. Android keeps its single high-importance channel.

### Badge

`lib/src/notifications/badge_controller.dart` subscribes to the snapshot store's writes and sets the badge to `pending.length` through `app_badge_plus` (`AppBadgePlus.updateBadge(count)`; 0 removes it), only when the count changed. It sets 0 when Hermes notifications are off (`NotificationSettings.enabled`), when the snapshot says signed out, and on sign-out. It can run in whichever isolate writes the snapshot; the app starts it from `main.dart`, and `background-refresh` starts one in its isolate (and registers `app_badge_plus` in `BackgroundPlugins.swift`). The iOS permission request already asks for badges.

`app_badge_plus` 1.3.5 (iOS, Android, macOS) uses `setBadgeCount` on iOS and the Dock tile on macOS. `flutter_local_notifications`' per-notification `badgeNumber` was rejected: it only changes the badge when a notification is posted, so answering a request in the app would leave a stale count. `flutter_app_badger` is unmaintained since 2022.

macOS has no widgets or extensions, so it had no snapshot store. It now gets one on `MemorySurfaceStorage` (nothing is stored on disk or shared), and its `SurfaceSnapshots` runs `localOnly`: it builds from the chat screen's hints and the last snapshot, never reads Kanban, schedules or sessions from the server and records no `surface.*` span or event. Open requests are known only for the chat screen's profile and the last snapshot; `background-refresh` (#614) replaces cross-profile pending, so stale counts from other profiles are not handled here. A request answered in a conversation window (its own engine) does not reach the main window's snapshot until that window reloads the chat on becoming key, so the Dock badge can lag until then.

### Platforms and native changes

- iOS: time-sensitive entitlement on the Runner. `NotificationActions` is untouched.
- macOS: time-sensitive entitlement added by the fastlane lane; Dock badge through the plugin.
- Android: badge where the launcher supports it; no grouping.
- Windows, Linux, watchOS: none.

### Invariants touched

- Notification bodies unchanged.
- Telemetry: breadcrumb `notification.badge` (`count` bucket) only when the bucket changes. No text, title, profile or id.

## Risks / Trade-offs

- [Time-sensitive overused] → only requests that block a running turn; the user can switch it off in iOS Settings.
- [Badge drift when the snapshot is stale] → the badge is as fresh as the last snapshot write; `background-refresh` keeps it fresh while the app is closed.

## Migration Plan

Nothing to migrate. Rollback removes the entitlement and the details fields.
