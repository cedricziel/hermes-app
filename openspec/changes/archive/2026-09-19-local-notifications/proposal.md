## Why

A reply can take a while, and the agent can stop mid-turn to ask for an approval or an answer. If the user has switched to another app or another thread, they only find out when they come back. The app should tell them.

This change was imported from the former `docs/superpowers/` directory (design and plan dated 2026-09-19) and is implemented and shipped in #56 (`feat(notifications): notify when a reply finishes or the agent needs you`). Later work extended it and is not part of this design: #71 announces a turn that broke mid-stream and tidies up notification taps, and #127 adds a generic notification for secret and sudo requests the app cannot answer. It is archived here to keep the design history in OpenSpec; the current behaviour is described by `openspec/specs/notifications/`.

## What Changes

- Post a local notification when a reply finishes, an approval is requested, or a clarify question is asked, while the app is not focused or the event belongs to a thread that is not on screen. macOS, iOS and Android.
- Add an on/off switch (default on) in a Notifications dialog reached from the sidebar menu next to Appearance.
- Ask for the system permission once, right after the first send.
- Open the thread when its notification is tapped.
- Keep the text generic for approvals and questions, so a command never shows on a lock screen.

## Impact

- New `lib/src/notifications/`: `attention_policy.dart`, `notification_settings.dart`, `notification_service.dart`, `local_notification_service.dart`, `notifications_dialog.dart`.
- `lib/src/chat/chat_screen.dart` (focus tracking, policy hook, permission, taps), the thread sidebar menu, `lib/main.dart` (providers).
- New dependency `flutter_local_notifications`. Native setup: Android `POST_NOTIFICATIONS` and build requirements, the iOS notification-center delegate.
- `PRIVACY.md`: a notification can show the chat title and the start of the reply on a lock screen, and that text stays on the device.
- Tests: a fake `NotificationService` in `test/support/`, plus policy, settings, dialog and chat screen tests.
- No change to the generated API client (`packages/hermes_api`). The design names no telemetry.
- Security and privacy: no tokens are involved. The stored values are the on/off switch and the permission flags in preferences. The notification payload is the thread id only.

## Non-goals

- Push notifications (APNs, FCM) and anything that needs the backend to reach a closed app.
- Windows and Linux. The service does nothing there, so the app keeps working.
- A background isolate for notification actions (approve or deny from the notification).
- Notification content for `secret.request` and `sudo.request`, which the app did not handle when this was designed.
