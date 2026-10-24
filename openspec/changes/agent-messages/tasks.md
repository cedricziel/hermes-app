# Tasks

Four PRs, each under about 500 changed lines with tests, merged in order. Each ends with its own verify task.

## 1. PR 1 — `feat(chat): mark opened chats read`

- [x] 1.1 Write failing repository tests against `FakeHermesServer`: a list row with `unread: true` gives `ChatThread.unread == true`, `false` or absent gives false; a detail row (`GET /api/sessions/{id}`) is unread when `last_read_at` is set and `last_activity_at` (else `started_at`) is later, read when `last_read_at` is null. Then add `unread` to `ChatThread` and parse it in `_thread`.
- [x] 1.2 Write a failing test that `HermesChatRepository.markRead(id, profile:)` sends `PATCH /api/sessions/{id}` with `{"unread": false, "profile": ...}`, then implement it on `_patch`.
- [x] 1.3 Write failing `ChatController` tests: selecting an unread remote thread sends one mark-read request and clears the flag; a read thread sends none; a chat fetched through `open(fetchMissing: true)` that is unread is marked read; a failing request keeps the chat open, shows nothing, sets the flag again and logs `chat.mark_read_failed` with only the error type. Then implement it in `select`.
- [x] 1.4 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all passing.

## 2. PR 2 — `feat(notifications): find and open messages from Hermes`

- [x] 2.1 Write failing repository tests for `loadDeliveries(profile:, offset:)`: sends `source=hermes_app`, `order=created`, `archived=exclude`, `limit=20`, `offset`, `profile`; returns a `DeliveryPage` of `AgentDelivery` (`id`, `title`, `started_at`, `message_count`, default 1 when absent, `unread`), skipping rows without `id` or `started_at` and rows whose id lacks the `hermes-app-` prefix, with `full` and `oldestStartedAt` judged from the raw rows. Then implement it with `getSessionsApiSessionsGet(source_: ...)`.
- [x] 2.2 Write failing pure tests in `lib/src/agent_messages/` for `findMessages(record:, listings:, profileNames:, now:)` and `listDeliveries(page, since:)`: first look records only (with the 0 marker when empty, ignoring unfinished deliveries); a later delivery counts when unread with a message; a read delivery advances the record; a delivery with no message holds the record before it and a newer one waits for it; one behind the record or started more than an hour before `now` does not hold it; the record follows every listed chat, not only deliveries; the record never moves back; a failed profile (null listing) keeps its value; profiles absent from the list are dropped; paging stops at the last page or at the record, keeps going when other chats fill a page, and reports a cap only when the third page is still newer. Then implement them.
- [x] 2.3 Write failing tests for `messageAlertsFor(found, texts, shownProfile:, appLock:)`: title and "(profile)" suffix, "Message from Hermes" fallback, `replyPreview` body as plain text, "New message" when empty, unreadable or under App Lock, App Lock title, summary above five with "<n> or more" at the cap, `messageCategory` and the `isMessage` marker. Then implement it.
- [x] 2.4 Write a failing test for `AgentMessageRecord` (`hermes.agent_messages.baseline.v1`, account-tagged slot, `default` key), then implement it in `lib/src/agent_messages/` and clear it in `main.dart`'s sign-out cleanup next to `ScheduleBaseline`.
- [x] 2.5 Write failing tests that a payload with the message marker becomes `NotificationTarget.message`, the summary payload becomes `NotificationTarget.messages()`, and `ChatScreen._applyNotification` opens a message with `fetchMissing: true` (switching profile and fetching) and a summary by selecting Chat with no error, while reply notifications keep `fetchMissing: false`. Implement the targets, the payload marker and the tap path.
- [x] 2.6 Register `hermes.message.new` (placeholder "New message") with the other categories on iOS and macOS, and extend the category test to cover it.
- [ ] 2.7 Run format, analyze and test, all passing.

## 3. PR 3 — `feat(notifications): announce messages from Hermes`

- [ ] 3.1 Write a failing test that `NotificationSettings.agentMessages` defaults to true, persists, and that a change made while loading wins; implement it like `scheduleAlerts`.
- [ ] 3.2 Add the "Messages from Hermes" row and footer to the Notifications dialog's Widgetbook use case (on, off, disabled while "Notify me" is off), check both themes at phone and desktop width, then add a failing dialog widget-test assertion and the row in `notifications_dialog.dart`.
- [ ] 3.3 Write failing `AgentMessageWatcher` tests with fake time: looks on foreground and every minute; no look while paused, in the background, signed out, with notifications or the setting off, before settings load, or on Linux and Windows; the record clears when the effective switch turns on; an unreadable profile list writes nothing; the record is written before posting; message texts are read in parallel within the budget; `agent_messages.found`, `agent_messages.announced` and `agent_messages.look_failed` carry only their counts, flags and error type. Then implement it on the `ScheduleWatcher` shape.
- [ ] 3.4 Write a failing test that a find in the shown profile reloads `ChatScreen`'s list through `AgentMessageFinds` and keeps the selection; then wire the watcher into `AppShell` (pause, account key, profiles, shown profile) and the listener into `ChatScreen`.
- [ ] 3.5 Run format, analyze and test, all passing, and use `verify-in-app` on macOS with the plugin from PR #804 enabled on a dev backend: `hermes send --to hermes_app:inbox` posts a notification, the chat appears in the list, a tap opens it (also from another profile), opening marks it read (`GET /api/sessions` shows `unread: false`), and the next look posts nothing.

## 4. PR 4 — `feat(background): announce messages from Hermes`

- [ ] 4.1 Write failing `AgentMessagesStep` tests: quiet while the app is in front or notifications are off, skipped with the setting off, nothing written or posted when the profile list is unreadable (including the `[null]` fallback), signed out, locked or unreachable; profiles listed in parallel; record written before posting; a chat announced here is not announced again by the watcher; span attribute `agent_messages.found` and the `background: true` log. Then implement it in `lib/src/background/` and add it to `_defaultSteps`.
- [ ] 4.2 Update `CLAUDE.md` (Notifications and background paragraphs: watcher, step, record, tap path, mark read) and the `verify-in-app` skill (how to send a delivery with the plugin on a dev backend).
- [ ] 4.3 Run format, analyze and test, all passing, and check the step on an Android emulator or iOS simulator by triggering the background task while suspended (or note in the PR why it could not be run).
