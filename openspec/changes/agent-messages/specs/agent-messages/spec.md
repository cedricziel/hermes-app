# Spec Delta

## Purpose

Lets a Hermes profile reach the user on its own: chats the Hermes App messenger plugin delivers to the `hermes_app:inbox` destination are found in every profile, announced once with a notification, and marked read when opened.

## ADDED Requirements

### Requirement: Finding messages from Hermes

The system SHALL treat a chat as a message from Hermes when the server lists it with source `hermes_app` and an id starting with `hermes-app-` (the messenger plugin's deliveries, never a chat the app started), reports it as unread, it holds at least one message, and it started after the record the app keeps for that profile. The record SHALL be kept per account and per profile name (the default profile under the name `default`) and SHALL never move backwards. After each successful look at a profile, the record SHALL be the newest start time among the listed sessions of that source, deliveries or not, except that it SHALL NOT pass a delivery that holds no message yet, so a delivery still being written is judged again at the next look. A delivery that started after one still being written SHALL wait for it, so that none is announced twice. A delivery that still holds no message more than an hour after it started, by the later of the device's clock and the newest listed chat, SHALL be given up on, and the record passes it. Archived deliveries SHALL NOT be announced.

The first look at a profile on a device, after the account or server changed, or after the "Messages from Hermes" setting or the general notification setting was turned on SHALL only record and SHALL announce nothing; a first look that finds no deliveries SHALL record the profile as having none, so its first delivery is announced. A first look SHALL ignore deliveries that hold no message yet. A look SHALL read up to three pages of 20 listed sessions, newest first, and stop at the page that is the last or whose oldest session is not newer than the record; other chats and pinned sessions among the listed sessions count toward the page.

When the profile names cannot be read, the look SHALL be skipped and no record SHALL change. A look that fails for one profile SHALL leave that profile's record unchanged and SHALL NOT stop the other profiles' looks. A profile SHALL be dropped from the record only when a successfully read profile list no longer names it.

#### Scenario: Delivery after the last look

- **WHEN** profile `work` delivers a message to the inbox after the app's last look at `work`
- **THEN** the next look finds that chat as a message from Hermes

#### Scenario: First look with existing deliveries

- **WHEN** the app looks at a profile for the first time on this device and unread deliveries already exist
- **THEN** no notification is posted and their start times are recorded

#### Scenario: First delivery to a profile

- **WHEN** the first look at profile `ops` finds no deliveries and `ops` then delivers its first message
- **THEN** the next look announces it

#### Scenario: Delivery read elsewhere

- **WHEN** a new delivery is listed but the server reports it as read
- **THEN** it is not announced and the record moves past it

#### Scenario: Delivery still being written

- **WHEN** a look lists a new delivery that holds no message yet
- **THEN** it is not announced and the record stays before it
- **AND** the next look announces it once it holds its message

#### Scenario: Delivery behind one still being written

- **WHEN** a look lists a new delivery that holds its message and, older than it, one that holds none yet
- **THEN** neither is announced and the record stays before both
- **AND** the next look announces both once the older holds its message

#### Scenario: First look among the app's own chats

- **WHEN** the first look at a profile lists only chats the app started, and an older unread delivery exists further down
- **THEN** the record passes the listed chats and the older delivery is never announced

#### Scenario: Delivery that is never finished

- **WHEN** a delivery still holds no message an hour after it started, and no other delivery follows it
- **THEN** it is given up on and the record passes it

#### Scenario: Chat started in the app

- **WHEN** the user starts a new chat in the app and another client marks it unread
- **THEN** it is not announced as a message from Hermes

#### Scenario: One profile fails

- **WHEN** listing profile `home` fails and profile `work` has a new delivery
- **THEN** the delivery in `work` is announced and `home` keeps its previous record

#### Scenario: Profile list unreadable

- **WHEN** the profile names cannot be read
- **THEN** nothing is listed, announced or recorded

#### Scenario: Newest delivery archived

- **WHEN** the newest delivery is archived after it was recorded and an older unread delivery is still listed
- **THEN** the record does not move back and nothing is announced again

### Requirement: Watching for messages from Hermes

On Android, iOS and macOS, while the app is in front (on macOS, also while it runs with no window), signed in, with session activity not paused, notifications on, their saved setting loaded and the "Messages from Hermes" setting on, the system SHALL look at every profile of the server when it comes to the foreground and then every minute. On iOS and Android it SHALL also look during each background run the system grants, under the same settings, and only while the app is not in front; the background look SHALL list its profiles in parallel. The foreground and background looks SHALL share the record, so a chat is announced at most once per device. The system SHALL NOT look on Windows or Linux, nor while the app is in the background outside a granted run. A background run that is signed out, locked or cannot reach the server SHALL leave the record as it was.

#### Scenario: Message while the app is open

- **WHEN** the app is open on any destination and a profile delivers a message to the inbox
- **THEN** a notification for it is posted within about a minute

#### Scenario: Background run

- **WHEN** a profile delivers a message while the app is in the background and the system then grants a background run
- **THEN** the run posts the notification

#### Scenario: Announced once

- **WHEN** a background run announced a message and the user then opens the app
- **THEN** the look in front does not announce it again

#### Scenario: Notifications off

- **WHEN** notifications are off and a profile delivers a message
- **THEN** no notification is posted and no look for messages is made

#### Scenario: Desktop without notifications

- **WHEN** the app runs on Linux or Windows
- **THEN** no look for messages is made

### Requirement: Announcing a message from Hermes

The system SHALL post one notification per message from Hermes. Its title SHALL be the chat's title, followed by the profile in brackets when it is not the profile the chat screen shows (in a background run: the server's active profile); a chat without a title SHALL use "Message from Hermes". Its body SHALL be the same preview of the chat's message as a finished reply's notification shows, read as plain text. When the message is empty or cannot be read within the look's time limit, the body SHALL be "New message". While App Lock is on, or before its setting has loaded, the title SHALL be "Message from Hermes" and the body "New message", because a delivery's title is made from its text. While the system hides previews, the notification SHALL show "New message" in place of the body. It SHALL be grouped and replaced per chat like a reply's notification and SHALL NOT be time-sensitive.

When one look finds more than five messages across all profiles, the system SHALL post one notification titled "Hermes" with the body "<n> new messages" in place of one each, or "<n> or more new messages" when the look stopped at its page limit.

Each signed-in device announces a delivery on its own; marking it read on one device does not withdraw another device's notification.

#### Scenario: Message with a preview

- **WHEN** profile `work` delivers "Daily report ready: 3 builds failed" in a chat titled "Message: Daily report ready"
- **THEN** the notification is titled "Message: Daily report ready" and its body is "Daily report ready: 3 builds failed"

#### Scenario: App Lock on

- **WHEN** App Lock is on and a profile delivers a message
- **THEN** the title is "Message from Hermes", the body is "New message", and neither includes the message text

#### Scenario: Message unreadable

- **WHEN** the chat's message cannot be read during the look
- **THEN** the body is "New message"

#### Scenario: Message from another profile

- **WHEN** the chat screen shows `home` and profile `work` delivers a message
- **THEN** the notification title ends with "(work)"

#### Scenario: Many at once

- **WHEN** one look finds seven new messages across two profiles
- **THEN** one notification titled "Hermes" says "7 new messages"

### Requirement: Tapping a message notification

A tap on a message notification SHALL open that chat in its own profile: the system SHALL switch the chat screen to that profile when another one is shown, and fetch the chat when it is not among the loaded chats. Only when the profile cannot be switched to or the chat no longer exists SHALL it show "Could not open that chat.", leaving the open chat as it was. A tap on the summary notification SHALL select the Chat destination and leave the shown profile and the open chat as they are, without a message. Both SHALL otherwise behave like a tap on a reply's notification (Chat selected, screens over the Kanban board dismissed, held while the list loads, applied after a cold start).

#### Scenario: Tap for another profile

- **WHEN** the chat screen shows `home` and the user taps the notification of a message delivered by `work`
- **THEN** the chat screen switches to `work` and the chat opens

#### Scenario: Tap for a chat beyond the loaded page

- **WHEN** the delivered chat is not among the loaded chats of the shown profile
- **THEN** it is fetched and opened

#### Scenario: Delivery deleted before the tap

- **WHEN** the delivered chat was deleted on the server before the tap
- **THEN** the message "Could not open that chat." is shown

#### Scenario: Tap on the summary

- **WHEN** the user taps the summary notification while Kanban is shown
- **THEN** the Chat destination is selected and no error is shown

### Requirement: New messages appear in the chat list

When a look in front finds a message from Hermes in the profile the chat screen shows, the system SHALL reload that profile's chat list so the chat appears without a manual refresh, keeping the open chat selected. This happens only while the looks run (see "Watching for messages from Hermes").

#### Scenario: Shown profile

- **WHEN** the chat screen shows `work` and `work` delivers a message
- **THEN** the chat appears in the list at the next look and the open chat stays selected

### Requirement: Opening a chat marks it read

When the user opens a chat that the server reports as unread, whether the chat came from the chat list or was fetched on its own (a notification tap, a search result, a link, a conversation window), the system SHALL mark it read on the server once per opening. A failure SHALL NOT be shown to the user and SHALL NOT block opening the chat; the chat is marked read at a later opening instead. A chat the server reports as read SHALL NOT cause a request. Showing a chat counts as opening it when the user picked it or the app restored it in a conversation window, but not when the app moves the selection to the next chat after the open one was archived or deleted. For a chat fetched on its own the app SHALL judge read state from the session's stored `last_read_at` and `last_activity_at`; activity the server records only as messages may not count there until the chat appears in the list, so such a chat can stay unread until a later opening. The server's list wins over a single session's read state: a refresh of one chat SHALL NOT clear an unread the list reported.

#### Scenario: Open an unread chat from the list

- **WHEN** the user opens a delivery the server lists as unread
- **THEN** the app asks the server to mark it read, and the dashboard no longer shows it as unread

#### Scenario: Open from the notification

- **WHEN** the user taps a message notification and the chat is fetched on its own
- **THEN** the app marks it read

#### Scenario: Mark read fails

- **WHEN** the request to mark a chat read fails
- **THEN** the chat still opens and no error is shown

### Requirement: Backend contract for messages from Hermes

The system SHALL rely on:

- `GET /api/sessions?source=hermes_app&order=created&archived=exclude&limit=20&offset=<n>&profile=<name>`, reading each row's `id`, `title`, `started_at` (seconds since the epoch), `message_count` and `unread`, and skipping rows without `id` or `started_at`;
- `GET /api/sessions/{id}/messages?profile=<name>` for the delivered text;
- `GET /api/sessions/{id}?profile=<name>`, reading `last_read_at`, `last_activity_at` and `started_at` to tell whether a fetched chat is unread (unread when `last_read_at` is set and the latest activity is later);
- `PATCH /api/sessions/{id}` with `{"unread": false, "profile": <name>}`;
- the profile list the app already reads.

Read state (`unread`, `last_read_at`) exists from the Hermes session schema added on 2026-08-04 (`d98287fe3c`); the app pins `71d34bad`. A server without read state reports no chat as unread: nothing is announced and no mark-read request is sent. Deliveries also need the Hermes App messenger plugin enabled on the server; without it no chat matches, nothing is announced, and nothing else changes. No new route, RPC method or response field is required.

#### Scenario: Server without the plugin

- **WHEN** the server has no `hermes_app` deliveries
- **THEN** looks find nothing and post nothing

#### Scenario: Server without read state

- **WHEN** the server's session rows carry no `unread` field
- **THEN** nothing is announced and opening a chat sends no mark-read request

#### Scenario: Row without a start time

- **WHEN** a listed row has no `started_at`
- **THEN** it is skipped and the other rows are judged normally
