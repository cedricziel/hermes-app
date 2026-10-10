# Proposal

## Why

Notifications of several chats pile up in one stack, a request for approval is held back by Focus like any other message, and nothing on the app icon says how many things are waiting.

## What Changes

- **Grouping per chat.** Notifications of one chat (and of one scheduled task) are grouped together on iOS and macOS (thread identifier) and Android (group key).
- **Time-sensitive requests.** Notifications posted under a request category (`hermes.request.approval.<choices>`, `hermes.request.approval`, `hermes.request.question`, `hermes.request.question.<hash>`, `hermes.request.questions`) and other input notifications use the time-sensitive interruption level on iOS and macOS, so they break through Focus; reply and task notifications stay at the default level. Needs the time-sensitive entitlement.
- **Badge = open requests.** The app icon badge (iOS, Android launchers that support it) and the macOS Dock badge show the number of requests waiting for the user across all profiles, from the pending list of the surface snapshot (`surface-snapshot`), and clear when there are none, on sign-out, and when Hermes notifications are off.

This builds on the actionable notifications now on main (#587, #589): categories and actions from `lib/src/notifications/request_notifications.dart` (`staticRequestCategories`, `requestCategoryFor`), posted by `LocalNotificationService.show`, with the Runner's `NotificationActions` as the iOS notification-centre delegate. This change only adds fields to the `DarwinNotificationDetails` and `AndroidNotificationDetails` that `show` builds; it adds no category, action or delegate.

Non-goals:

- No Notification Content Extension and no expanded view. Since #587 the notification body already carries the approval's command or the question (cut at 1000 characters, placeholder under App Lock), so a custom view would add a target and a lock gate for nothing (user decision).
- No changes to bodies, categories, actions, background answering or watch mirroring (#587/#589).
- No inline reply on "Reply ready" (the `notification-inline-reply` change).
- No critical alerts (they need an Apple-granted entitlement and suit emergencies, not approvals).

Security and privacy impact:

- Badge counts and thread identifiers carry no content (the identifier is the profile and the thread id, which the payload already holds).
- Nothing new goes to telemetry beyond the breadcrumb below.

Observability: one breadcrumb, `notification.badge` with `count` bucket (`0`, `1`, `2-5`, `6+`), recorded when the bucket changes, so a crash report shows whether requests were waiting. No span (nothing here crosses the network) and no log event.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `notifications`: adds per-chat grouping, time-sensitive requests and the open-request badge.

## Impact

- iOS: time-sensitive entitlement on the Runner; fastlane profiles regenerated for the capability.
- macOS: time-sensitive entitlement in `DebugProfile.entitlements` and `Release.entitlements`; Dock badge.
- Dart: `AttentionNotification` gains a group key; `LocalNotificationService.show` sets thread identifier, interruption level and Android group key; a `BadgeController` listening to the snapshot store.
- Dependency: `app_badge_plus` (1.3.5) from pub.dev.
- Backend: none.
- Dependencies: #587/#589 (on main) and `surface-snapshot` (pending list for the badge).
