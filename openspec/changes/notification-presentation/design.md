# Design

## Context

See proposal.md for motivation and specs/notifications/spec.md for behavior.

As of this writing (before the peer's PR):

- `attentionFor` (`lib/src/notifications/attention_policy.dart`) turns a `ChatEvent` into an `AttentionNotification {threadId, jobId?, profile?, title, body}` with fixed bodies for requests.
- `LocalNotificationService.show` builds `NotificationDetails` itself (Android channel "Agent activity", plain `DarwinNotificationDetails()`), uses one id per chat (`notificationIdFor(threadId, profile:)`, FNV-1a), and encodes the tap target as JSON `{t|j, p}` into the payload. `flutter_local_notifications` 22.3.1 stores that payload in the iOS/macOS notification's `userInfo["payload"]`, and its `DarwinNotificationDetails` already has `threadIdentifier`, `interruptionLevel`, `categoryIdentifier` and `badgeNumber`; `AndroidNotificationDetails` has `groupKey`.
- `ApprovalRequest` carries `command`, `description`, `toolName`; `ClarifyRequest` carries `questions` (one or a batch).

PR #587 (actionable notifications) moves category and action setup into a reusable category builder, add approval and question categories with buttons, answer in the background and mirror to the watch. Until it merges this design names the seams by role: "the peer's builder" (what turns an `AttentionNotification` into platform details), "the approval category" and "the question category" (their identifiers).

`surface-snapshot` keeps the pending list (`pending` rows, titles and kinds only) and lets listeners subscribe to its writes.

## Goals / Non-Goals

**Goals:**

- The detail is readable by a person holding the unlocked phone without opening Hermes, and by nobody looking at a locked one.
- Every addition sits in the peer's builder output, not in a second notification path.

**Non-Goals:**

- Changing which events notify, their bodies, their ids or their taps.

## Decisions

### Where the detail travels: in the payload, not the text

Options considered:

1. **In the notification's payload** (`userInfo`), with the visible body generic. The extension reads it from `notification.request.content.userInfo`.
2. **In a file in the App Group**, keyed by the notification id, protected with `FileProtectionType.complete` so it is unreadable while the device is locked, and deleted when the request resolves.
3. **Fetched live by the extension** from the server.

Chosen: 1, with a lock gate. Option 3 would put tokens and networking into an extension, which the rollout rules out. Option 2 hides the detail at rest better, but adds a file lifecycle (write, clean up on answer, on cancel, on sign-out, after the app was killed) for a detail that the notification store already holds in the same at-rest class as other notifications, and leaves stale files whenever cleanup misses. With option 1 the detail lives exactly as long as the notification.

What this means for storage and privacy, stated in the proposal: iOS keeps the notification's content, payload included, in its notification store while the notification is delivered (under data protection, but readable after first unlock like the app's own preferences), and forwards it to a paired Apple Watch, which shows only title and body. The detail is limited to the approval's command and description (the server sends the command redacted) and the first clarify question's text (with "and N more questions" for a batch), cut at 1000 characters; secret, sudo and unsupported requests carry none. It leaves the store when the user clears or opens the notification, or when the chat's next notification replaces it (one id per chat, or the peer's per-request removal if it posts one per request).

The detail is added to the existing payload JSON as `d: {k: "approval"|"question", t: <text>, s?: <description>}`. Dart's tap decoding (`targetFromResponse`) ignores the new key. If the peer's PR moves its own data out of the payload into separate keys, `d` moves with it; the extension reads it from wherever the builder puts it, through one Swift function.

### The lock gate in the extension

The extension must not show the detail on a locked device, even if iOS lets a locked user expand the notification (behavior not verified; see Risks). An extension cannot ask `UIApplication` whether protected data is available, so the Runner writes an empty sentinel file `notification-detail.sentinel` into the App Group container with `FileProtectionType.complete` at every launch (cheap, idempotent). The extension tries to read it: readable means the device is unlocked, and the detail is shown; unreadable means locked, and the extension shows "Unlock your iPhone to see what Hermes asks." No detail is cached by the extension.

### The extension target

`HermesNotificationContent` (`UNNotificationContentExtension`, SwiftUI hosted in the view controller):

- `Info.plist`: `UNNotificationExtensionCategory` = the approval category and the question category from the peer's builder (filled when the peer's ids are known); `UNNotificationExtensionDefaultContentHidden` = false, so title and generic body stay above; `UNNotificationExtensionUserInteractionEnabled` = false, so the peer's action buttons stay the only controls; a small `UNNotificationExtensionInitialContentSizeRatio`.
- View: the command in a monospaced, selectable-looking block (up to 12 lines, then cut), the description below in secondary text; or the question as body text. Uses the Hermes accent color; dark mode follows the system.
- `AppGroupId` Info.plist key and the App Group entitlement, as `HermesLiveActivity` does, for the sentinel.
- The view logic (payload decoding, cut, lock gate decision) lives in plain Swift files with a `swift test` package beside the target (`ios/HermesNotificationContent/Core`, as the watch core), so it is tested in CI's macOS job.

### Grouping

`AttentionNotification` gains `groupKey`: `chat:<percent-encoded profile>/<thread id>` for a chat, `job:<percent-encoded profile>/<job id>` for a task. The peer's builder sets it as `threadIdentifier` (iOS, macOS) and `groupKey` (Android). iOS and macOS stack a chat's notifications together; Android bundles them when it shows more than one. With one notification per chat today the visible effect is that chats no longer collapse into one app stack; it matters more once the peer posts one notification per request.

### Interruption level

The builder sets `interruptionLevel: timeSensitive` on iOS and macOS for approval, question, secret/sudo and unsupported-input notifications, and leaves the default (`active`) for reply and task notifications. The Runner gets `com.apple.developer.usernotifications.time-sensitive` in `ios/Runner/Runner.entitlements` and in both macOS entitlements files; the App IDs need the capability, so `fastlane match` profiles are regenerated. Users can turn time-sensitive off per app in Settings; iOS shows that switch once the entitlement exists. Android keeps its single high-importance channel.

### Badge

`lib/src/notifications/badge_controller.dart` subscribes to the snapshot store's writes and sets the badge to `pending.length` through `app_badge_plus` (`AppBadgePlus.updateBadge(count)`; 0 removes it), only when the count changed. It sets 0 when Hermes notifications are off (`NotificationSettings.enabled`), when the snapshot says signed out, and on sign-out. It runs in whichever isolate writes the snapshot, so the background refresh's writes update the badge too. The iOS permission request already asks for badges.

`app_badge_plus` 1.3.5 (published 2026-09-07, 160 points, 170 likes, about 320 000 downloads in 30 days, iOS, Android and macOS) uses `setBadgeCount` on iOS and the Dock tile on macOS. `flutter_local_notifications`' per-notification `badgeNumber` was rejected: it only changes the badge when a notification is posted, so answering a request in the app would leave a stale count. `flutter_app_badger` is unmaintained since 2022.

Android launchers show a dot or count only where the launcher supports it; nothing is done when `AppBadgePlus.isSupported()` is false.

### Platforms and native changes

- iOS: new extension target in `ios/Runner.xcodeproj` (embedded in the Runner, App Group `$(CUSTOM_GROUP_ID)`, iOS 26, bundle id `com.cedricziel.hermesApp.NotificationContent`, Debug prefixed `com.cedricziel.hermesApp.dev.`), time-sensitive entitlement on the Runner, sentinel written in `AppDelegate`, fastlane signing for the new target and capability.
- macOS: time-sensitive entitlement; Dock badge through the plugin.
- Android: `groupKey`; badge where the launcher supports it.
- Windows, Linux, watchOS: none.

### Invariants touched

- Notification bodies stay generic (the notifications spec's body requirement is unchanged).
- Tokens: none in the payload, the extension or the App Group.
- Telemetry: breadcrumb `notification.badge` (`count` bucket) from `BadgeController`, only when the bucket changes. No text, title, profile or id. The extension records nothing.
- API layering: no network.

### Dependencies

- PR #587: its reusable category builder, approval and question category ids, and payload encoding. Request notifications are posted through that builder; this change only adds to its output.
- `surface-snapshot`: the pending list the badge counts.

## Risks / Trade-offs

- [The peer's PR changes shape before it merges] → this change starts after it merges and adapts to its builder; the seams named here are roles, not names.
- [iOS may let a locked device expand a notification's custom view] → the sentinel gate covers it either way; verify on a device with a passcode (simulators have none).
- [The detail sits in the notification store and reaches the watch] → bounded and stated; the alternative file store was weighed above.
- [Time-sensitive overused] → only requests that block a running turn; the user can switch it off in iOS Settings.
- [Badge drift when the snapshot is stale] → the badge is as fresh as the last snapshot write; `background-refresh` keeps it fresh while the app is closed.
- [Xcode churn of a new target] → add it with Xcode once, commit only `project.pbxproj`, the target folder and entitlements.

## Migration Plan

Nothing to migrate. Rollback removes the extension from the embed phase and the entitlement; notifications fall back to the generic view.
