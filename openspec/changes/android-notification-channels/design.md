# Design

## Context

Facts checked on main (`lib/src/notifications/local_notification_service.dart`, `attention_policy.dart`):

- The only channel: `agent_activity`, name "Agent activity", description "Replies and requests from Hermes", `Importance.high`, `Priority.high`, built inline in `showWhile` on every post. The plugin creates it on the first `show`. Nothing calls `createNotificationChannel` or `deleteNotificationChannel`, and `android/` has no channel code.
- Notifications posted on Android, all through `showWhile`: finished and failed replies (`replyReadyNotification`), approval, question and needs-you requests (`attentionFor`, `OpenRequestsStep`, `RequestAnswers`), scheduled-task runs (`AttentionNotification.job`, `schedule_alerts.dart`), messages from Hermes (`isMessage`, `message_alerts.dart`), "Couldn't send your answer" and "Open Hermes to answer." (`kOpenToAnswerBody`; both from `RequestAnswers._tell`) and "Ask not sent" (`AskHermes._tellNotSent`, no category).
- Not posted on Android: server alerts (none exist), ongoing or foreground-service work (none; the refresh is WorkManager), the inline reply and its endings (iOS and macOS only).
- Notification strings are fixed English constants below the widget layer (`kReplyReadyBody` and so on).
- Plugin facts, read in `flutter_local_notifications` 23.0.2: `deleteNotificationChannel({required String channelId})` takes a named parameter; `getNotificationChannels()` returns a nullable list; a post's `AndroidNotificationDetails.channelAction` defaults to `createIfNotExists`, so a post creates a missing channel and leaves an existing one alone.

## Decisions

### The channels and their ids

Four channels, as in the proposal's table. Ids are lowercase snake case like the old one, with no version suffix, no `hermes_` prefix (the app id already scopes them) and no word that describes a setting such as "high" or "silent" (the user can change importance and the id outlives it). A later importance change for everyone needs a new id, for example `scheduled_tasks_2`, which is why the ids name what a notification is about, not how loud it is.

Choosing the channel, one pure function `androidChannelFor(AttentionNotification)` in `android_channels.dart`:

1. `isMessage` goes to `agent_messages`.
2. `jobId != null` goes to `scheduled_tasks`.
3. `category?.isRequest == true`, `needsInput` or `request != null` goes to `chat_requests`. Two cases have none of these and set the channel explicitly through an optional `channel` field on `AttentionNotification`: the background check's needs-you post when no approval is open (`OpenRequestsStep._notification`: no category, no request, body `kNeedsYouBody`) and the two answer endings of `RequestAnswers._tell`.
4. Everything else goes to `chat_replies`.

Importance: `chat_replies`, `chat_requests` and `agent_messages` are `high`, as today. `scheduled_tasks` is `default`: a cron run is not something the user is waiting for. The answerable request's `secret` visibility and `hermes.request` tag stay per notification, not channel settings.

Why four: server alerts and background work have no notification to carry. Why requests are apart from replies: an approval blocks a running turn and the user may want it loud while replies are quiet. Why messages are apart: they arrive unprompted and are the ones people mute.

### Creating the channels

On Android 8+ the service creates all four through `AndroidFlutterLocalNotificationsPlugin.createNotificationChannel` in `_start()`, in both the app's isolate and the background isolate, once the migration step below has finished (flag set) or the flag was already set. A step that fails at its read (step 2) creates none of the new channels; a step that fails at a later create or delete leaves the flag unset. In both cases posts keep using `agent_activity` until a later start finishes the step. Creating an existing channel updates its name and description and leaves its importance alone. Below Android 8 channels do not exist and the calls are no-ops (the post's `priority` then applies and stays set).

`AndroidNotificationDetails` gets the chosen channel's id, name, description and importance on every post, as today. With `channelAction` at `createIfNotExists`, a post never fails for a missing channel.

### Migration from `agent_activity`

Options:

A. Delete it in the release that ships the split. Any setting the user made on `agent_activity` is lost, so a user who set it to "Silent" or blocked it would get four new loud channels. That undoes a choice.
B. Keep it unused for a release. Settings stay but nothing reads them, an empty channel sits in settings under the old name, and the same migration is still to be written later.
C. Carry over, then delete once (proposed).

Android lowers an existing channel's importance on a recreate only while the user has not changed it, and never raises it, so the carry-over has to be known before the new channels exist: no loud channel may exist for a post to use, or for the user to start editing, before the old mute has been read and applied. Order of the step, in `_start()` after `initialize` and before any `createNotificationChannel` for the new ids and before any post of this run:

1. If the flag `hermes.notifications.channels.v1` is set, skip the step.
2. Read the old channel with `getNotificationChannels()` (nullable; null counts as a failed read).
3. If `agent_activity` exists and its importance is below `high` (the user lowered or blocked it), create the four new channels with that importance. Otherwise create them at their own importance. Fresh install: no old channel, create them at their own importance.
4. `deleteNotificationChannel(channelId: 'agent_activity')`, then set the flag. Other settings (sound, vibration, lock-screen visibility, bubbles) are not carried; the release note says so.

While the step is pending (the flag is not set: a failed read, create or delete, or the step has not run yet) a post goes to `agent_activity`, whatever its kind, so no notification lands in a channel created at the wrong importance and the user's mute still holds. Once the flag is set, posts use the new ids. A failure leaves the flag unset and the old channel in place; the next start tries again.

The flag is read per post (preferences read through `SharedPreferencesAsync`, which has no cache), not once per start, so an isolate whose own step failed sees the flag the other isolate set and moves to the new ids. A post already in flight to `agent_activity` can still recreate it: `createIfNotExists` brings back the deleted channel with the user's earlier settings, and the flag is already set, so step 4 would never delete it again. So once the flag is set, every start also deletes a leftover `agent_activity` (idempotent: deleting a missing channel is harmless), and the new ids never depend on it.

Two isolates start the service (the app and the WorkManager background run) and can both see the flag unset. The step is serialised with the existing cross-isolate lock pattern (the SQLite connection lock, as `announced-lock.sqlite` uses), taken around steps 1 to 4 and re-checking the flag inside the lock; the loser finds the flag set and skips. The steps are also idempotent (creating an existing channel changes nothing, deleting a missing one is harmless), so a lock failure degrades to a repeated harmless run, never to a lost mute: the creation in step 3 happens only when the old channel was still there to read.

Consequences of C: a user who never changed the old channel sees no change; a user who muted it keeps the mute on all four; a user who set a custom sound loses it once. Android shows "N categories deleted" in the app's notification settings after a delete; one delete once is acceptable. Owner decides between A, B and C; C is proposed.

### Localization

Names and descriptions go in `app_en.arb` and `app_de.arb` under `@@x-area-notifications`: `notificationChannelRepliesName` and `...Description`, and the same for requests, messages and scheduled tasks (eight strings), each with a `@` description saying it is an Android system-settings label and stays short (a name of about 40 characters at most, a description of one sentence). Only `kReleasedLocales` (English) is offered today, so only English reaches users; the German strings still ship.

This follows the documented pattern for text outside a widget tree (`docs/architecture/localization.md`, "Text outside a widget tree"): the channel text is read with `l10nForPlatformLocale()` from `lib/l10n/l10n.dart`, which resolves the platform locales against `kReleasedLocales` and is the same in the app and in a background isolate. It is read per run (each start of the service, each background task), not once per process, because the system language can change while the app is suspended. No `lookupAppLocalizations` call and no stored locale setting.

Channel text is set when the channels are created and refreshed when the language changes: once the flag is set, each start re-creates the four channels with the current text (a rename, never an importance change), and the shell does the same on a locale change while the app runs. Both are gated on the flag: before it is set nothing is re-created and nothing is renamed (the old channel keeps its text), so no loud channel appears before the old mute has been read. The user cannot rename a channel on Android, so there is nothing of theirs to protect. The service gets the text as a plain value (`AndroidChannelStrings`) from its caller and holds no ARB lookup itself.

### Privacy

Unchanged. The channel is chosen from the kind of notification, never from content. Names and descriptions are fixed. The log event `notification.channels` carries an outcome and a flag, nothing else. App Lock still makes every body and title generic, whichever channel carries it.

### Platforms and native changes

Android only, Dart only. No manifest change (`POST_NOTIFICATIONS` is already declared), no Kotlin change. iOS, macOS, Windows and Linux ignore the channel. No backend contract is involved.

### Invariants touched

The privacy rules above; a background run never signs the user out (the migration reads no session).

## Risks / Trade-offs

- A user's custom sound or vibration on `agent_activity` is lost once under C. Accepted; stated in the release note.
- Scheduled tasks losing the heads-up is visible for people who relied on it. They can raise the channel in system settings; the owner can keep `high`.
- More channels means more rows in Android settings. Four is the number of distinct things the app says.
- While the step is pending, notifications keep going to `agent_activity`, so a split that never completes (the delete keeps failing) leaves the app on one channel. The log event makes that countable.

## Not verified without a device

That the old channel's importance reads back as the user left it, that a rename reaches the system settings without a restart, the "categories deleted" count, and that a channel created at a lowered importance behaves as the plugin's `createNotificationChannel` documents.

## Migration Plan

One release ships the channels and the carry-over together. The flag `hermes.notifications.channels.v1` in preferences records that it ran. No server change.

Rolling back the app leaves the four channels in place (harmless). The older build then posts to `agent_activity` again and recreates it. Android restores a deleted channel that is recreated under the same id with the settings the user had before, so a user who muted it before the update has that mute back; the four new channels keep their own settings in the meantime.
