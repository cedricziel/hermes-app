# Proposal

Owner decides: whether the old `agent_activity` channel is deleted in the release that ships the split (carrying a user's mute over to the new channels), or kept unused for one release before it goes.

## Why

On Android the app creates one notification channel, `agent_activity` ("Agent activity", importance high, description "Replies and requests from Hermes"), and every notification goes through it: a finished or failed reply, an approval or question, a scheduled task's run, a message from Hermes, and the endings ("Couldn't send your answer", "Ask not sent"). Android lets a user control only a channel at a time, so someone who finds scheduled-task results noisy can only silence replies and approvals with them, and someone who wants approvals to stay loud cannot quiet messages.

Android keeps a user's choices (importance, sound, vibration, lock-screen visibility, blocked) on the channel id for good, and an app cannot raise or lower a channel's importance once it exists. So the ids chosen here stay. The split is cheap now and cannot be redone without another migration.

There is no sensible split today: nothing else creates a channel (no `createNotificationChannel` call, no Kotlin channel code; `flutter_local_notifications` creates `agent_activity` on the first post).

## What Changes

- Android posts through four channels instead of one. Ids are permanent:

  | Id                | Name                    | Importance | Used by                                                                                              |
  | ----------------- | ----------------------- | ---------- | ---------------------------------------------------------------------------------------------------- |
  | `chat_replies`    | Replies                 | high       | finished and failed reply, and the endings "Ask not sent"                                            |
  | `chat_requests`   | Approvals and questions | high       | approval, question and "needs you" requests, the answerable variant, and "Couldn't send your answer" |
  | `agent_messages`  | Messages from Hermes    | high       | `hermes send --to hermes_app:inbox` messages and their summary                                       |
  | `scheduled_tasks` | Scheduled tasks         | default    | a scheduled task's run                                                                               |

  Each has a description in the ARB files (design.md). Importance `high` is today's value, so a user who never opened the system settings sees no change except for scheduled tasks, which become `default` (no heads-up pop-up). The owner can keep them at `high`.

- Categories the app does not send are not created. There is no server-alert notification (the Server screen's status is read in the app and sends nothing) and no ongoing or foreground-service notification on Android (the background refresh is WorkManager with no visible notification; Live Activities are iOS only). A low-importance "background" channel would be empty, and an empty channel only clutters the system settings. When one of them exists, it gets its own change and its own id.
- The old `agent_activity` channel stops being used. The migration (design.md) carries a mute over to the new channels, then deletes the old one once.
- Channel names and descriptions come from the ARB files, set when the channels are created and again on a locale change (Android lets name and description be updated).
- iOS, macOS, Windows and Linux are untouched: they have no channels.

Non-goals:

- No change to what a notification says, its buttons, its lock-screen visibility (`secret` for the answerable variant), its tag (`hermes.request`) or its grouping per chat.
- No in-app per-channel switches. The Notifications dialog (Notify me, scheduled tasks, Messages from Hermes) stays; the system's channel settings are the new control, and the dialog's "Open settings" button already opens the app's notification screen.
- No channel group, no per-profile channels, no sound or vibration choice made by the app.
- No new kind of notification.

Security and privacy impact:

- None. Which channel a notification goes through carries no content, and nothing new is stored. The privacy rules in CLAUDE.md stay as they are: breadcrumbs, logs and spans carry fixed names, counts, flags and outcomes; App Lock still blanks titles and text; the surface snapshot and notification bodies are unchanged. A channel's name and description are fixed app text, never a title, profile name, server address or id.
- Side effect: the user's per-channel lock-screen setting becomes finer (they can hide only approvals on a locked screen). That is the user's choice and makes no notification more visible than today's settings do.

Observability:

- Log event `notification.channels` through `AppEventLogger` with `outcome` (`created`, `migrated`, `failed`) and `carried_mute` (bool). It fits because a failed migration silently leaves a user's mute undone, which someone should be able to count. No breadcrumb and no span (nothing crosses a network boundary; the native call is local). It never carries a channel's text or a notification's content.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `notifications`: adds the Android notification channels and the move from the single channel.

## Impact

- Dart: `lib/src/notifications/local_notification_service.dart` (the one `_channelId`/`_channelName` pair becomes a channel chosen from the `AttentionNotification`; creation and migration through `AndroidFlutterLocalNotificationsPlugin`), `attention_policy.dart` (a `channel` choice beside `timeSensitive`, derived from `isMessage`, `jobId`, `category?.isRequest`, `needsInput`, `request`), a small `android_channels.dart` for ids, importance and migration, and the entry points that build the service in the background isolate (`lib/src/background/entry_points.dart`).
- ARB: `lib/l10n/arb/app_en.arb` and `app_de.arb`, under `@@x-area-notifications`.
- No native Kotlin or manifest change. No API route changes, so no OpenAPI regeneration.
- Docs: `docs/architecture/notifications-and-background.md` and the main `notifications` spec when archived.
