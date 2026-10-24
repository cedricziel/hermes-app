# Proposal

## Why

A Hermes profile can now start a chat for the user on its own: the Hermes App messenger plugin (`plugins/hermes-app`, PR #804) registers a `hermes_app:inbox` destination for `hermes send`, `send_message` and scheduled-task delivery, and saves each delivery as a new unread chat in the sending profile. The app shows that chat only after the user happens to refresh the chat list, and never marks it read, so a message the agent meant to bring to the user's attention goes unnoticed.

## What Changes

- The app notices new unread deliveries in every profile and posts a notification for each: titled with the chat's title, with a one-line preview of the message, opening that chat in its own profile on a tap. Under App Lock both title and body are generic, since a delivery's title is made from its text.
- It looks while the app runs (once a minute, like scheduled-task runs) on Android, iOS and macOS, and in the iOS and Android background refresh, sharing one per-profile record so the same chat is never announced twice on a device. The first look for a profile only records.
- A new delivery in the profile on screen appears in the chat list without a manual refresh.
- A "Messages from Hermes" switch in the Notifications dialog, on by default.
- Opening a chat the server reports as unread marks it read on the server, wherever the chat was opened from.
- The background-refresh-alerts contract and telemetry gain messages from Hermes.

Non-goals:

- Instant delivery to a suspended or closed app. Hermes has no push channel; a notification arrives at the next look (about a minute while the app runs, whenever the system grants a background run otherwise). A push relay is a separate change.
- Coordinating devices: each signed-in device announces a delivery on its own, and reading it on one does not withdraw another's notification.
- An unread indicator in the chat list, a badge or Dock count for unread messages, rows in the Mac menu bar item, a watch chat-list refresh, or marking chats unread from the app.
- Announcing other kinds of agent-started sessions (cron sessions, Bot Chat deliveries, Kanban runs).
- Shipping or installing the server plugin; that is PR #804, which also makes deliveries unread from their first write and numbers repeated titles.

## Capabilities

### New Capabilities

- `agent-messages`: how the app finds chats a Hermes profile delivered to the Hermes App inbox, announces them, opens them from a notification, keeps them out of repeated announcements, and marks opened chats read.

### Modified Capabilities

- `notifications`: the notifiable events gain "a new message from Hermes", a tap on such a notification may switch profile and fetch the chat, and the Notifications dialog gains its switch.
- `background-refresh-alerts`: background runs also announce messages from Hermes; telemetry and the backend contract list them.

## Impact

- Code: `lib/src/notifications/` (settings, dialog, notification target and category), a new `lib/src/agent_messages/` (finding, record, watcher), a new step in `lib/src/background/`, `HermesChatRepository` (delivery listing, unread state, mark read), `ChatController` (mark read on open, tap path), `AppShell` and `ChatScreen` (watcher ownership and list reload).
- Native: iOS and macOS register one more notification category for the hidden-preview placeholder.
- Backend: no new route. Uses `GET /api/sessions`, `GET /api/sessions/{id}`, `GET /api/sessions/{id}/messages` and `PATCH /api/sessions/{id}`, all in the generated client. Needs Hermes session read state (2026-08-04 or later) and the messenger plugin for anything to be announced.
- Delivery: four PRs (see tasks.md) so each stays reviewable.
- Security and privacy: no token or secret handling changes. A notification shows the chat title and a 120-character preview of the message; both are generic while App Lock is on, and the body is replaced by "New message" while the system hides previews. Stored state is one timestamp per profile name under the account key in shared preferences; no title, text or session id is stored.
- Observability: a breadcrumb `agent_messages.found` (count) when a look finds new chats, since it explains a following tap or crash; a log event `agent_messages.announced` (`count`, `summary`, `background`) for how often the feature fires; a log event `agent_messages.look_failed` (`error` type, `background`) at most once per look so a look that keeps failing is visible; the background span gets `agent_messages.found`; a mark-read failure logs `chat.mark_read_failed` (`error` type). No title, text, profile name or id in any of them.
