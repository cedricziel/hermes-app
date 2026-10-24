# Design

## Context

The messenger plugin (PR #804) saves each delivery as a session with an id `hermes-app-<hex>`, source `hermes_app`, one assistant message, a title made from the message's first line ("Message: …", numbered "(2)", "(3)" on a repeat) and `last_read_at = 0`, which the session list reports as `unread: true`. The plugin marks the session unread right after creating it, before the message is written, so a look between those writes sees an unread delivery with `message_count = 0`.

Facts about Hermes this design relies on (pinned `71d34bad`):

- The list's `preview` is the first _user_ message (`hermes_state_common.py` `_sql_preview_raw`), so it is empty for a delivery; the text has to be read from the chat's messages.
- `unread` is computed only for list rows. `GET /api/sessions/{id}` returns `last_read_at` but no `unread`.
- `order=created` sorts by `started_at` descending; `source` filters by `s.source`; `PATCH unread=false` stamps the whole compression lineage.
- Pinned rows are appended to every page, so a page can hold more than `limit` rows and include older rows.
- Read state arrived with session schema 21 (2026-08-04, `d98287fe3c`).

The app's scheduled-task alerts are the model: `ScheduleWatcher` (foreground, once a minute, owned by `AppShell`, paused with session activity), `ScheduleAlertsStep` (background), and `ScheduleBaseline` (one stored slot tagged with `accountKeyFor(server, user)`; another account reads none; cleared on sign-out by `SignedOutCleanup`).

Platforms: Android, iOS and macOS for the foreground watcher (the platforms that post notifications); iOS and Android for the background step. iOS and macOS gain one notification category, registered next to the existing ones by `hermes_app/notification_categories`; no entitlement, manifest or Xcode project change.

## Goals / Non-Goals

**Goals:**

- One announcement per delivery per device, whichever look saw it first, without losing a delivery to a race, a failed read or a first look.
- Cost bounded by profiles: one 20-row list request per profile per look, plus one 1-message read per announced chat.

**Non-Goals:**

- A generic watcher shared with schedules. Two small watchers with the same lifecycle read better than one parameterised one; revisit if a third appears.

## Decisions

**Identify deliveries by source and id prefix.** `source=hermes_app` is sent to the server; the app also requires the `hermes-app-` id prefix. App-started chats share the source and can become unread (Desktop's "Mark as unread", or new activity after this change marks them read), so the source alone is not enough. The prefix is part of the contract with our own plugin.

**A per-profile record that never goes backwards and never passes an unfinished delivery.** For each profile: `record' = max(record, cutoff)`, where `cutoff` is the newest `started_at` among listed deliveries that are older than every listed delivery with `message_count == 0`. A delivery counts when it is newer than the old record, unread and has a message. Read deliveries move the record past them (the user saw them elsewhere). An absent profile is a first look: the record becomes `cutoff`, or a "none yet" marker (0) when nothing is listed, and nothing is announced. Alternative: a set of announced ids, which grows without bound, needs trimming and stores ids. The record is stored as `{account, profiles: {name: seconds}}` under `hermes.agent_messages.baseline.v1`, keyed by profile name with `default` for the default profile in both the watcher and the step.

**Profile list first, and no partial writes.** Both the watcher and the step read the profile names (`HermesProfilesRepository.load` in front, `HeadlessHermes.profiles()` in the background). When that fails, or the background gets its `[null]` fallback, the look is skipped and nothing is written. A profile whose list request fails keeps its old value; only profiles absent from a successfully read list are dropped.

**Paging.** Up to three pages of 20 (`offset` 0, 20, 40), stopping at the first page whose oldest non-pinned row is not newer than the record. More than 60 new deliveries in one look are reported as "60 or more"; they are all in the chat list anyway.

**The message text.** For each delivery to announce, `loadMessagePage(id, profile:, limit: 1)` within `kAlertLookupBudget`, in parallel, as `RunningRepliesStep` reads replies; the body is `replyPreview` of the assistant text, or "New message" when it is empty, unreadable or App Lock is on. Not read at all under App Lock or for a summary.

**Notification shape.** The default `AttentionNotification` constructor (thread id, profile, title, body) with `bodyIsPlainText: true` and a new `messageCategory` (`hermes.message.new`, placeholder "New message", no buttons) added to the categories the Runners register. Its payload gets a marker (`'m': 1`) that `targetFromPayload` turns into `NotificationTarget.message(threadId, profile)`; the summary uses `NotificationTarget.messages()` (no thread). Under App Lock the title is "Message from Hermes". The "(profile)" suffix uses the chat screen's shown profile in front (via `ChatProfiles.current`) and `profiles.loadActive()` in the background, as schedules do.

**Tap path.** `ChatScreen._applyNotification` sends `NotificationTarget.message` to `_chat.open(target, fetchMissing: true)`, which already switches profile through `loadThreads(profile)` and fetches the chat with `loadThread`; `NotificationTarget.messages()` only calls `onShowChat`. Everything else keeps `fetchMissing: false`, as the existing notifications spec requires.

**Unread state on `ChatThread`.** `unread` is parsed from list rows (`unread == true`) and from detail rows (`last_read_at != null && (last_active ?? started_at) > last_read_at`). `ChatController.select` sends `markRead` when the thread is remote and unread, then clears the flag locally; fire and forget, a failure logs `chat.mark_read_failed` and sets the flag again. Conversation windows run their own `ChatController`, so they get this too.

**Ownership and the list reload.** `AppShell` owns `AgentMessageWatcher` next to `ScheduleWatcher` (same pause, account and lifecycle handling; created only on Android, iOS and macOS). It exposes the profile names of each look's finds through a `ValueListenable`-style `AgentMessageFinds` provided below `AppShell`; `ChatScreen` listens and calls `ChatController.loadThreads(current)` when its shown profile is among them, as it already reacts to `ChatOpenRequests`.

**Write order.** Both the watcher and the step write the record before posting, so a record that cannot be saved announces nothing rather than the same chat at every look. (`ScheduleAlertsStep` posts first; this step deliberately does not.)

**Background step.** `AgentMessagesStep` in `_defaultSteps`; steps already run concurrently, so its position does not matter. Quiet while the app is in front or notifications are off (`_quiet`), skipped when the setting is off, profile lists in parallel with `kAlertLookupBudget` each, all within the 20 s step budget.

**Settings.** `NotificationSettings.agentMessages` (`notifications.agentMessages`, default true), handled like `scheduleAlerts`; the record is cleared when the effective switch (`enabled && agentMessages`) turns on, which also covers "Notify me" turning on. Cleared on sign-out with the schedule baseline.

**Invariants touched.** API layering: every call goes through the generated client (`getSessionsApiSessionsGet(source_:)`, `getSessionDetailApiSessionsSessionIdGet`, the messages call `loadMessagePage` already uses, `renameSessionEndpointApiSessionsSessionIdPatch` with `SessionRename(unread: false)`); no spec or client regeneration. Auth: the step runs inside `withHeadlessHermes` and never signs out. Tests use `FakeHermesServer` routes.

**Observability.**

- Breadcrumb `agent_messages.found` (`count`), from the watcher when a look finds at least one.
- Log `agent_messages.announced` (`count`, `summary`, `background`), from the watcher and the step after posting.
- Log `agent_messages.look_failed` (`error` type, `background`), at most once per look, when the profile list or any profile's listing fails.
- Span attribute `agent_messages.found` (count) on `background.task` through `HeadlessHermes.annotate`.
- Log `chat.mark_read_failed` (`error_type`), from `ChatController`.

None carries a title, text, profile name, session id or server address.

## Risks / Trade-offs

- [A profile is renamed] → it reads as a new profile; its first look only records, so deliveries during the rename are not announced. Rare; accepted.
- [Hermes auto-archive is on and the device stays off longer than `auto_archive_days`] → the delivery is archived before any look and never announced. The list GET also runs the throttled archive sweep, now for every profile, not just the shown one. Accepted; noted in the plugin README.
- [The server clock steps backwards] → new deliveries start before the record and are not announced until the clock passes it. Rare; accepted.
- [Switching accounts and back] → the single stored slot belongs to the last account, so the first look after switching back only records, like schedules.
- [Several devices] → each announces; non-goal.
- [N profiles × one request a minute] → the same order as the schedule look; each is a 20-row indexed query.

## Migration Plan

None. The setting defaults to on and the first look only records, so updating the app announces nothing old. Servers without the plugin see one extra list request per profile per minute while the app is in front.
