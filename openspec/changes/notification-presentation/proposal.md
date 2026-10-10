# Proposal

## Why

Hermes' notifications are deliberately generic: "Waiting for your approval" says nothing about what Hermes wants to run, so the user has to open the app to judge it, even when the notification already carries buttons to answer (the peer session's actionable-notifications change). Notifications of several chats pile up in one stack, a request for approval is held back by Focus like any other message, and nothing on the app icon says how many things are waiting.

## What Changes

- **Expanded view for requests (iOS).** Long-pressing an approval or question notification shows, below the generic banner, the command Hermes wants to run (with its description) or the question it asks. A new Notification Content Extension target draws it. The banner and Lock Screen text stay generic, and the extension shows the detail only while the device is unlocked.
- **Grouping per chat.** Notifications of one chat (and of one scheduled task) are grouped together on iOS and macOS (thread identifier) and Android (group key).
- **Time-sensitive requests.** Approval, question and other input notifications use the time-sensitive interruption level on iOS and macOS, so they break through Focus and stay on the Lock Screen for an hour; reply and task notifications stay at the default level. Needs the time-sensitive entitlement.
- **Badge = open requests.** The app icon badge (iOS, Android launchers that support it) and the macOS Dock badge show the number of requests waiting for the user across all profiles, from the pending list of the surface snapshot (`surface-snapshot`), and clear when there are none, on sign-out, and when Hermes notifications are off.

This builds on PR #587 (actionable notifications), which is not merged yet: it defines the notification categories for approvals and questions, their action buttons and a reusable category builder. This change only adds to what that builder produces (thread identifier, interruption level, the detail the extension reads) and registers the extension for its approval and question categories. **It starts after that PR merges.**

Non-goals:

- No action buttons, clarify choices, background answering or watch mirroring (the peer's).
- No inline reply on "Reply ready" (the `notification-inline-reply` change).
- No expanded view on Android or macOS. Android's lock-screen privacy depends on per-device settings the app cannot check, and macOS is a later target.
- No command or question in the banner, the Lock Screen text, the watch, the badge or the App Group.
- No critical alerts (they need an Apple-granted entitlement and suit emergencies, not approvals).

Security and privacy impact:

- The command or question now travels inside the notification itself (in its payload, not its visible text), so it is stored by the system's notification store while the notification exists, and iOS forwards the notification, payload included, to a paired Apple Watch, which shows only the generic text. This is the cost of showing the detail without opening the app. Bounds: only approval commands (already redacted by the server) and descriptions, and question texts, never a secret's name or value or a sudo request; cut at 1000 characters; gone when the notification is cleared, opened, or replaced by the chat's next notification.
- The extension reads only the notification it is shown for and the App Group's lock sentinel. It has no network access, no tokens and no Flutter.
- Badge counts and thread identifiers carry no content (the identifier is the profile and the thread id, which the payload already holds).
- Nothing new goes to telemetry beyond the breadcrumb below.

Observability: one breadcrumb, `notification.badge` with `count` bucket (`0`, `1`, `2-5`, `6+`), recorded when the badge changes, so a crash report shows whether requests were waiting. The extension runs outside Flutter and records nothing; when it cannot read the detail it shows the generic text, which is visible to the user. No span (nothing here crosses the network) and no log event (no outcome worth counting that the peer's notification events do not already cover).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `notifications`: adds the expanded request detail, per-chat grouping, time-sensitive requests and the open-request badge.

## Impact

- iOS: new `HermesNotificationContent` extension target (SwiftUI in a `UNNotificationContentExtension`), embedded in the Runner, App Group entitlement, bundle id `com.cedricziel.hermesApp.NotificationContent` (Debug prefixed as CLAUDE.md requires), fastlane signing; time-sensitive entitlement on the Runner. A lock sentinel file written by the Runner at launch.
- macOS: time-sensitive entitlement in `DebugProfile.entitlements` and `Release.entitlements`; Dock badge.
- Dart: `AttentionNotification` gains the request detail and the grouping key; the peer's builder output gains thread identifier, interruption level and the detail in the payload; a `BadgeController` listening to the snapshot store.
- Dependency: `app_badge_plus` (1.3.5) from pub.dev.
- Backend: none beyond the request events the chat already maps.
- Dependencies: PR #587 (category builder and category ids) and `surface-snapshot` (pending list for the badge).
