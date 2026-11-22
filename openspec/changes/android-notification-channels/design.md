# Design

## Context

Facts checked on main (`lib/src/notifications/local_notification_service.dart`, `attention_policy.dart`):

- The only channel: `agent_activity`, name "Agent activity", description "Replies and requests from Hermes", `Importance.high`, `Priority.high`, built inline in `showWhile` on every post. The plugin creates it on the first `show`. Nothing calls `createNotificationChannel` or `deleteNotificationChannel`, and `android/` has no channel code.
- Notifications posted on Android, all through `showWhile`: finished and failed replies (`replyReadyNotification`), approval, question and needs-you requests (`attentionFor`, `OpenRequestsStep`, `RequestAnswers`), scheduled-task runs (`AttentionNotification.job`, `schedule_alerts.dart`), messages from Hermes (`isMessage`, `message_alerts.dart`), "Couldn't send your answer" (`RequestAnswers._tell`) and "Ask not sent" (`AskHermes._tellNotSent`, no category).
- Not posted on Android: server alerts (none exist), ongoing or foreground-service work (none; the refresh is WorkManager), the inline reply and its endings (iOS and macOS only).
- Strings are fixed English constants below the widget layer (`kReplyReadyBody` and so on); the channel name and description are two more.

## Decisions

### The channels and their ids

Four channels, as in the proposal's table. Ids are lowercase snake case like the old one, with no version suffix, no `hermes_` prefix (the app id already scopes them) and no word that describes a setting such as "high" or "silent" (the user can change importance and the id outlives it). A later importance change for everyone needs a new id, for example `scheduled_tasks_2`, which is why the ids name what a notification is about, not how loud it is.

Choosing the channel, one pure function `androidChannelFor(AttentionNotification)` in `android_channels.dart`:

1. `isMessage` goes to `agent_messages`.
2. `jobId != null` goes to `scheduled_tasks`.
3. `category?.isRequest == true`, `needsInput` or `request != null` goes to `chat_requests`. "Couldn't send your answer" has none of these, so `RequestAnswers._tell` sets the channel explicitly (an optional `channel` field on `AttentionNotification`, default derived as above).
4. Everything else goes to `chat_replies`.

Importance: `chat_replies`, `chat_requests` and `agent_messages` are `high`, as today. `scheduled_tasks` is `default`: a cron run is not something the user is waiting for. The answerable request's `secret` visibility and `hermes.request` tag stay per notification, not channel settings.

Why four and not the five in the brief: server alerts and background work have no notification to carry. Why requests are apart from replies: an approval blocks a running turn and the user may want it loud while replies are quiet. Why messages are apart: they arrive unprompted and are the ones people mute.

### Creating the channels

On Android 8+ the service creates all four in `_start()` through `AndroidFlutterLocalNotificationsPlugin.createNotificationChannel`, before any post, in both the app's isolate and the background isolate, so a background run's first post never meets a missing channel. Creating an existing channel leaves its importance alone and updates name and description. Below Android 8 channels do not exist and the calls are no-ops (the post's `priority` then applies and stays set).

`AndroidNotificationDetails` gets the chosen channel's id, name, description and importance on every post, as today, so a post never depends on the creation having run.

### Migration from `agent_activity`

Options:

A. Delete it in the release that ships the split. Any setting the user made on `agent_activity` is lost, so a user who set it to "Silent" or blocked it would get four new loud channels. That undoes a choice.
B. Keep it unused for a release. Settings stay but nothing reads them, an empty channel sits in settings under the old name, and the same migration is still to be written later.
C. Carry over, then delete once (proposed). On the first start after the update, if the flag `hermes.notifications.channels.v1` is not set: read the old channel (`getNotificationChannels`); if it exists and its importance is below `high` (the user lowered or blocked it), create the new channels with that importance, because a channel's importance can be chosen freely until it exists; then `deleteNotificationChannel('agent_activity')`; then set the flag. If the old channel does not exist (fresh install) only create the new ones. Other settings (sound, vibration, lock-screen visibility, bubbles) are not carried, and the release note says so.

Consequences of C: a user who never changed the old channel sees no change; a user who muted it keeps the mute on all four; a user who set a custom sound loses it once. Android shows "N categories deleted" in the app's notification settings after a delete; one delete once is acceptable, and the flag keeps it from repeating. A failure in any step leaves the flag unset and the old channel in place, so the next start tries again; posts meanwhile go to the new channels. Owner decides between A, B and C; C is proposed.

### Localization

Names and descriptions go in `app_en.arb` and `app_de.arb` under `@@x-area-notifications`: `notificationChannelRepliesName` and `...Description`, and the same for requests, messages and scheduled tasks (eight strings), each with a `@` description saying it is an Android system-settings label and stays short (a name of about 40 characters at most, a description of one sentence). Only `kReleasedLocales` (English) is offered today, so only English reaches users; the German strings still ship.

CLAUDE.md says no strings below the widget layer. A channel's text is a system-visible label, so it is the exception, resolved at the edge: `lookupAppLocalizations` on the app's resolved locale builds a plain `AndroidChannelStrings` value that is passed into the service. The service holds no `BuildContext` and no ARB lookup. The shell builds it at start; the background isolate (no widget tree) builds it from the saved locale setting, falling back to the platform locale and then English.

Channel text is set at creation and refreshed on a locale change: the shell watches the resolved locale and calls `updateChannelText(strings)`, which re-creates the four channels (a rename, never an importance change). A background run uses what the last app run saved. The user cannot rename a channel on Android, so there is nothing of theirs to protect.

### Privacy

Unchanged. The channel is chosen from the kind of notification, never from content. Names and descriptions are fixed. The log event `notification.channels` carries an outcome and a flag, nothing else. App Lock still makes every body and title generic, whichever channel carries it.

### Platforms and native changes

Android only, Dart only. No manifest change (`POST_NOTIFICATIONS` is already declared), no Kotlin change. iOS, macOS, Windows and Linux ignore the channel.

### Invariants touched

The privacy rules above; "no strings below the widget layer" (the exception above, with a test); a background run never signs the user out (the migration reads no session).

## Risks / Trade-offs

- A user's custom sound or vibration on `agent_activity` is lost once under C. Accepted; stated in the release note.
- Scheduled tasks losing the heads-up is visible for people who relied on it. They can raise the channel in system settings; the owner can keep `high`.
- More channels means more rows in Android settings. Four is the number of distinct things the app says.
- The plugin calls `getNotificationChannels` and `deleteNotificationChannel` must be checked against `flutter_local_notifications ^23` (names, parameter style, null behavior) before coding (task 1.1).
- The migration runs only in `_start()` after `initialize`.

## Not verified without a device

That the old channel's importance reads back as the user left it, that a rename reaches the system settings without a restart, and the "categories deleted" count. Android also remembers a blocked state for a deleted channel that is recreated with the same id; the new ids differ from `agent_activity`, so this does not apply.

## Migration Plan

One release ships the channels and the carry-over together. The flag `hermes.notifications.channels.v1` in preferences records that it ran. No server change. Rolling back the app leaves the four channels in place (harmless); the older build recreates `agent_activity` with defaults.
