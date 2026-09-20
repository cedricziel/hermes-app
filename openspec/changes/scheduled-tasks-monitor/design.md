## Context

The shell (`lib/src/shell/app_shell.dart`) shows the chat alone unless the Kanban plugin is on, and then offers two destinations with a fixed list and a fixed index. The chat screen owns the profile it lists (`_profile`) and only knows the first page of sessions. Job records, run rows and the cron routes have no response schema in the OpenAPI spec, so the generated methods return untyped JSON; `HermesProfilesRepository` and `KanbanRepository` show the pattern for parsing that leniently. The backend contract is read from the server's own code (`hermes_cli/web_routers/cron.py`, `cron/jobs.py`) and pinned by the real-backend contract test.

See proposal.md for motivation and scope.

## Goals / Non-Goals

**Goals:**
- Schedules is a peer of Chat and Kanban, built from what the server offers.
- One controller owns the list, so the phone list and the wide detail cannot disagree.
- A run opens in the existing chat rather than in a second transcript viewer.

**Non-Goals:**
- A shared "destination" abstraction for every future tab. Three destinations do not need it; the shell gets a small list built each time the checks change.
- Caching jobs on disk.

## Decisions

**Availability probe: `GET /api/cron/delivery-targets`.** It is cheap, needs no profile, and the editor needs its answer anyway. Alternatives: probing `/api/cron/jobs` (loads every profile's jobs just to learn a route exists) or reading the server version from `/api/status` (a version number is a poor proxy for a route). Any failure counts as off, the same rule as Kanban, so a flaky network hides the tab until the next resume rather than showing a broken one.

**Destinations are a list of ids, not fixed indexes.** The shell builds `[chat, kanban?, schedules?]` and keeps the selection by id, so a tab disappearing returns to Chat instead of pointing at another tab. The Kanban and Schedules pages stay alive behind Chat once opened, as Kanban's does today, and each is dropped when its destination goes off.

**Repository over the generated client.** `HermesCronRepository` takes `DefaultApi` (through `authController.api!.raw`) and returns typed models parsed leniently in `schedule_models.dart`. Errors are mapped once into a small exception like `KanbanException`, so the controller shows a message per action instead of a stack trace.

**Controller with a generation counter.** `SchedulesController` (a `ChangeNotifier`, like `KanbanBoardController`) holds rows, the selected id, the filter and the load state. Each refresh takes a generation number and drops its answer when a newer one started; that is how "an older answer does not replace a newer one" is met. The timer runs only while the destination is selected and the app is resumed; the shell tells the controller (`active`).

**Pause is optimistic, run-now is not.** The switch flips at once and reverts on failure, because a pause is instant and reversible. Run now only reports that a run was requested: the server answers before the run ends, and claiming success would be wrong.

**No "running" in the list.** A job record has no running flag. A run session with `ended_at == null` and recent activity is the only signal (`is_active` in the runs response), so it is shown in the detail's history, where the runs are already loaded. Showing it in the list would cost a request per job.

**Schedule in words on the client.** The server's display of a cron job is its expression. `CronJob.scheduleWords` spells out intervals and the expressions that fire at one time of day (daily, weekdays, weekends, named days) and otherwise shows what the server says. It is a pure function, tested as data. The editor change reuses it and adds the inverse.

**Sorting on the client.** The server returns jobs in storage order. Failing first, then soonest next run, then paused and completed matches what a user opens the tab to find. It is a pure function over rows and is tested as data.

**Profile scope.** The list asks for `profile=<active>`; "All profiles" sends `profile=all`. Reading the active profile follows the chat's rule: a 404 means an unscoped server, any other failure is an error and nothing is listed unscoped, so one profile's jobs are never shown as another's (see the fix in commit 4eb098c).

**Opening a run in the chat.** A small `ChatOpenRequests` object (a `ChangeNotifier` holding the latest `NotificationTarget`, provided above the shell) lets Schedules ask the chat to open `{threadId, profile}`. The chat already opens a notification's target through `_openFromNotification`; the same path is reused, with one addition: when the thread is not in the loaded page or the chat is on another profile, the chat reloads on the target's profile and, if the session is still missing, fetches it with `GET /api/sessions/{id}` and prepends it. Alternative: a read-only run page in Schedules. Rejected because the user asked for the chat, where the transcript can be continued, and a second renderer for tool calls would drift from the first.

**Wide layout.** The same 900 px breakpoint as the shell. The list and detail are two widgets sharing the controller; below the breakpoint the detail is pushed as a route so back works as expected.

**Platforms:** iOS, Android, macOS, Windows, Linux. watchOS is untouched. No entitlement, manifest or Xcode change.

**Invariants touched:** API layering (all calls through the generated client; no hand-written route); concurrent 401s are handled by the shared Dio and not by this code; telemetry is unaffected.

## Risks / Trade-offs

- [A transient failure hides the Schedules tab] → It comes back on the next resume; same trade-off Kanban already makes, and a broken tab is worse than a missing one.
- [The response shapes are read from server code, not a schema, and can drift] → Lenient parsing, plus cron shapes in the real-backend contract test that runs in CI against a pinned Hermes.
- [A cron session opened in chat can be continued, which the server may not expect for a session with source `cron`] → The chat resumes any session by id the same way; if the server refuses, the chat's existing error handling shows it.
- [Every server now gets a navigation bar when cron routes exist, changing the chat-only look] → Intended, and spelled out in the modified Kanban requirements.
- [Polling every minute costs a request per minute while the tab is open] → Only while selected and in front; one small request.
