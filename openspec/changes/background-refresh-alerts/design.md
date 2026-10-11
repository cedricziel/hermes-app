# Design

## Context

See proposal.md for motivation and specs/ for behaviour. This change builds on `background-refresh` (and through it on `headless-runtime`, `surface-snapshot` and #587 (on main)): it uses its run, the `BackgroundStep` and `BackgroundContext` contract, its shared gateway socket and its budget.

What exists today:

- `ScheduleWatcher` (`lib/src/schedules/schedule_alerts.dart`) polls `GET /api/cron/jobs?profile=all` every minute while the app is in front. `runsSince(baseline, jobs)` and `alertsFor(ran)` are pure functions. The baseline lives in memory, so the first look after launch only sets it.
- `session.active_list` reports each session's `session_key` and `status`. The transport treats `working`, `waiting` and `starting` as a turn that still runs.
- `HermesChatRepository.loadMessagePage(sessionId, profile:, limit:)` reads a session's messages.
- `replyPreview` and the notification bodies for a completed or failed reply (`attention_policy.dart`) define what the app in front posts.

## Goals / Non-Goals

**Goals:**

- The app in front and the background runs never announce the same run twice.
- The same notification texts as in front.
- Each check is its own step, and fails alone.

**Non-Goals:** new alert rules, polling in the background.

## Decisions

### Running replies step

`ChatController` handles the two lifecycle changes:

- On `AppLifecycleState.paused`, it writes `hermes.background.running.v1`: one `{profile, threadId, since}` entry for each chat with a pending reply.
- On `resumed`, and when it starts, it clears the list, because the app in front catches up through replay. A reply that ends after the pause is taken off the list.

The step reads that list, drops entries older than 24 hours, and calls `session.active_list({profile})` once for each profile in the list, on the run's shared socket. A chat has finished when its session is absent from the answer, or present with a status outside `starting`, `waiting`, `working`, `streaming` and `resuming`.

For each finished chat, the step reads `loadMessagePage(limit: 5)` and builds the same notification the foreground posts for that outcome:

| Outcome                         | Notification body                           |
| ------------------------------- | ------------------------------------------- |
| The last assistant message      | `replyPreview` of that message              |
| The chat ends on the user's prompt | "Reply failed"                           |
| The read fails or finds no text | the empty-reply text, as for an empty reply |

Then it removes the chat from the list. When `session.active_list` fails, the step does nothing. Notifications are posted only while `settings.enabled` is on.

The step uses `status` (including `streaming` and `resuming`) instead of `activeStatuses()`, because a `resuming` session has not finished.

### Schedule step and the shared baseline

The baseline moves into `hermes.schedules.baseline.v1` in `SharedPreferencesAsync`, as a map from job key to the last run time (ISO 8601).

- `ScheduleWatcher` loads the baseline before its first look and saves it after each look. Turning the setting on still clears it, so runs from while it was off are not announced.
- The schedule step runs when `scheduleAlerts` is on and the cron routes answer. It calls `listJobs(profile: 'all')`, then `runsSince(stored, jobs)`, saves the new baseline, and posts `alertsFor(unmuted)` unchanged.
- With no stored baseline, which is the first run on a device, the step only records it.

The two writers cannot overlap. A background run happens while the app is suspended, and the watcher runs only in front.

### Headless outcomes

The steps run inside the `HeadlessDone` branch of `background-refresh`'s run. For `HeadlessSignedOut`, `HeadlessLocked` and `HeadlessUnreachable` they never start, so `hermes.background.running.v1` and the schedule baseline stay as they were and the next run picks them up. Reply-ready and schedule notifications are plain notifications; they use no #587 request category.

### Invariants touched

- Auth: only through `withHeadlessHermes`.
- API layering: the existing repositories and `HermesGatewayTransport.request`.
- Telemetry: `replies.finished` and `schedules.ran` are added to the run's `background.task` span in the two steps. They are counts only, with no id, title or text.
- Notifications: unchanged texts and lock-screen rules.

## Deviations from the first plan

- The list holds no `sessionKey`: a stored chat's id is the key `session.active_list` reports (the transport matches them the same way), so one field says both.
- History records no failure, so "the last reply failed" is read as a chat whose newest message is the user's own prompt.
- The chat's title comes from `loadThread` in the same step (6 s limit, "New chat" when it fails), since the list holds no text.
- The schedule baseline is cleared when the cron routes go away as well as when the setting is switched on, as the in-memory baseline was. `ScheduleWatcher` reads it at every look instead of keeping a copy, because a background run may have moved it.
- A reply that ends in front while the list is written is taken off it, so the run does not announce it a second time (the per-chat notification id would replace the first, but the second would alert again).
- `refreshShortcuts` (#617) and the badge (#615) are not part of this change: neither has merged.

## Risks / Trade-offs

- [A session absent from `session.active_list` may also mean the dashboard restarted] → The message read decides whether the reply is shown as ready or failed. A turn the restart cut off ends as the read finds it.
- [A duplicate notification after resume] → The replay in front may announce the same chat again. Notifications are one per chat, so it replaces the background one rather than adding a second.
- [`session_key` may not be the stored chat id] → Task 1.1 checks this against the real backend first.

## Migration Plan

Only new preferences keys. After the update, the first look, in front or in the background, sets the baseline without announcing older runs. On rollback, the watcher goes back to its in-memory baseline.
