## Context

Notifications today are chat events: `AttentionNotifier` turns a `ChatEvent` into an `AttentionNotification` through `attentionFor`, the `NotificationService` posts it and reports taps as a `NotificationTarget` (a thread id and a profile), and `NotificationSettings` holds the on and off setting. Hermes has no push channel to the app, so the app can only look. See proposal.md for scope.

## Goals / Non-Goals

**Goals:**
- Reuse the permission flow, the settings and the service; add a second kind of event and target.
- Keep the diff logic a pure function so it is tested as data.

**Non-Goals:**
- Background execution of any kind.

## Decisions

**A `ScheduleWatcher`, separate from `SchedulesController`.** The controller lives while its tab is open and only refreshes while selected; alerts must work from the chat. The watcher owns its own timer and one request (`profile=all`) and runs only when the app is resumed, cron is available and both settings are on. When Schedules is in front the controller's refresh feeds the watcher's baseline so a visible run is not announced again, and the watcher does not post while Schedules is in front. Alternative: make the controller poll always. Rejected: the list's error and retry states are wrong for something the user is not looking at.

**Diff as a pure function.** `runsSince(previous, current)` takes a map of job key (profile and id) to `last_run_at` and the new jobs and returns the jobs whose time moved on, with their outcome. First sight of a job returns nothing and records the baseline. It is tested as data, including clock skew (a `last_run_at` that moves backwards is ignored) and deleted jobs.

**Baseline is in memory.** A restart forgets it, so runs that happened while the app was closed are not announced on launch. Persisting `last_run_at` per job would announce old runs after a long gap, days later, which is noise, not news. It is a stated limit and the reason the feature is described as "while the app is open".

**Mutes in the existing settings store.** `NotificationSettings` gains a set of `profile/jobId` strings in shared preferences, next to its on and off flag, and the same load and change-notification pattern. A mute is dropped when the list loads without that job.

**A target with a job.** `NotificationTarget` gains an optional `jobId`; the payload the local notification service encodes carries it, and old payloads without it still decode as chats. The shell routes a target with a job id to Schedules and any other to Chat, so the chat's own handling is untouched.

**One watcher owned by the shell.** The shell creates the `ScheduleWatcher` when the notification service, the notification settings and the cron repository are all provided, tells it whether the cron routes answer and whether Schedules is in front, and disposes it. A look asked for while another runs joins it, so the first look after starting and an explicit one do not race.

**A summary has no job.** More than five runs in one look become one notification whose target is a job with an empty id. A tap on it shows the Schedules list and no detail.

**Taps reach the shell through the chat.** The chat already owns the notification stream and the launch target, so it hands a job target to the shell (`onOpenJob`) instead of trying to open it as a chat. A tap that arrives before the cron check has answered waits for it, and a launch tap only happens once the chat has loaded its threads. The shell then selects Schedules and asks its controller to open the job, which the screen does: beside the list on a wide screen, pushed on a phone. A job the list does not hold is fetched by id; a 404 says it no longer exists.

**Body without content.** The lock screen shows the job name and a fixed phrase, following the chat rule for failures ("Reply failed", not the error).

**Platforms:** the platforms the notification service supports today; the others post nothing, as now. No permission prompt of its own: the existing one covers it, and it is not requested from a watcher (as for a watch turn).

**Invariants touched:** telemetry and auth are untouched. Requests go through the generated client.

## Risks / Trade-offs

- [Nothing arrives while the app is closed] → Said plainly in the proposal and the setting's description; the job's delivery target (Telegram and so on) remains the push channel.
- [A minute of polling drains battery] → Foreground only, one small request.
- [A burst of runs floods the lock screen] → More than five collapse into one summary.
- [Job ids collide across profiles] → Mutes and baselines are keyed by profile and id.
