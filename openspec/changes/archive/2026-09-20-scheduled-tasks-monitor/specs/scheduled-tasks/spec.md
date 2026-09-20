## Purpose

Describes how the app shows the scheduled tasks (cron jobs) of a Hermes server: when the Schedules destination is offered, how the jobs are listed, filtered and refreshed, what a job's detail shows, how a job is paused, resumed, run once or deleted, how its run history opens as a chat, and which backend routes it relies on.

## ADDED Requirements

### Requirement: The Schedules destination follows the server's cron routes

The system SHALL offer a Schedules destination only while the server answers `GET /api/cron/delivery-targets` with a success status. Any other outcome (a network error, an error status, a server too old to have the route) SHALL count as off. The check SHALL run when the signed-in home screen is first shown and every time the app returns to the foreground; when several checks overlap, only the answer of the most recently started one SHALL apply. When it turns off while Schedules is selected, the app SHALL return to Chat. The destination SHALL NOT depend on the Kanban plugin.

#### Scenario: Server has cron routes

- **WHEN** the delivery targets request succeeds
- **THEN** the navigation offers a Schedules destination

#### Scenario: Server without cron routes

- **WHEN** the delivery targets request answers 404
- **THEN** no Schedules destination is offered

#### Scenario: Cron goes away while selected

- **WHEN** Schedules is selected, the app resumes and the check now fails
- **THEN** the destination disappears and the chat is shown

#### Scenario: Schedules without Kanban

- **WHEN** the Kanban plugin is off and the cron routes answer
- **THEN** the navigation offers Chat and Schedules

### Requirement: Jobs load only once the destination has been opened

The system SHALL NOT request the job list until the user has selected the Schedules destination for the first time. Once opened, the list SHALL stay alive behind Chat, keeping its filter and selection. When the destination turns off, the app SHALL forget that it was opened.

#### Scenario: Never opened

- **WHEN** the cron routes answer and the user stays on Chat
- **THEN** no request for `/api/cron/jobs` is made

#### Scenario: Visit to Chat and back

- **WHEN** the user picks the Failing filter, selects Chat and then Schedules again
- **THEN** the Failing filter is still picked

### Requirement: Job list

The system SHALL list the jobs of the server, each row showing the job's name (its prompt's first words when the name is empty), its schedule in words, when it runs next, the outcome of its last run, and its delivery target. A paused job SHALL show "Paused" and no next run. A job whose last run failed SHALL show the failure and, when the server gave one, a one-line reason. A job that has finished for good (a one-shot that ran) SHALL show "Completed". Rows SHALL be ordered with failing jobs first, then by next run, soonest first, then paused and completed jobs.

#### Scenario: Healthy job

- **WHEN** a job is scheduled, its last run succeeded two hours ago and it runs next in three hours
- **THEN** its row shows the schedule, "Last run succeeded 2 h ago" and "Next run in 3 h"

#### Scenario: Schedule in words

- **WHEN** a job's schedule is the cron expression `0 8 * * 1-5`, or an interval of 360 minutes
- **THEN** its row says "Weekdays at 08:00", or "Every 6 hours"; an expression that is not a single time of day is shown as it is

#### Scenario: Failed job

- **WHEN** a job's last status is an error with the text "Provider timeout"
- **THEN** its row shows a failure marker and the reason, and it is listed above the healthy jobs

#### Scenario: Paused job

- **WHEN** a job is paused
- **THEN** its row shows "Paused" and no next run, and it is listed after the scheduled jobs

#### Scenario: Job never ran

- **WHEN** a job has no last run
- **THEN** its row shows "Not run yet" in place of the last result

#### Scenario: No jobs

- **WHEN** the server has no jobs for the chosen profile
- **THEN** the list shows an empty state that says there are no scheduled tasks

#### Scenario: List fails to load

- **WHEN** the request fails
- **THEN** the list shows an error with a retry action and keeps the last successful rows when it has any

### Requirement: Profile scope and filters

The system SHALL start with the jobs of the sticky active profile and offer "All profiles", "Failing" and "Paused" as filters. With all profiles chosen, rows SHALL name their profile. The active profile SHALL be read from `GET /api/profiles/active`; when the server has no such route the list SHALL be unscoped, and when the request fails otherwise the list SHALL NOT load unscoped: it SHALL show the load error. Filters SHALL combine with the profile choice.

#### Scenario: Default scope

- **WHEN** the active profile is `work` and the list opens
- **THEN** the request carries `profile=work` and only its jobs are shown

#### Scenario: All profiles

- **WHEN** the user chooses "All profiles"
- **THEN** the request carries `profile=all` and each row names its profile

#### Scenario: Failing filter

- **WHEN** the user chooses "Failing"
- **THEN** only jobs whose last run failed, or that are in the error state, are shown

#### Scenario: Active profile lookup fails

- **WHEN** reading the active profile fails with something other than 404
- **THEN** no job request is made unscoped and the list shows the load error

### Requirement: The list stays current

The system SHALL refresh the list when it is opened, when the app returns to the foreground while it is selected, on the user's request (a refresh gesture or action), after any change the user makes, and every minute while it is selected and the app is in front. A refresh SHALL NOT clear the rows already shown, and an older answer SHALL NOT replace a newer one.

#### Scenario: Timed refresh

- **WHEN** the list has been in front for a minute
- **THEN** the jobs are requested again and changed rows update in place

#### Scenario: App in the background

- **WHEN** the app is not in the foreground
- **THEN** no timed refresh is made

#### Scenario: Slow older answer

- **WHEN** an earlier refresh answers after a newer one
- **THEN** the earlier answer is ignored

### Requirement: Pause and resume

The system SHALL let the user pause an active job and resume a paused one from its list row and from its detail, using `POST /api/cron/jobs/{id}/pause` and `POST /api/cron/jobs/{id}/resume` with the job's profile. The switch SHALL move at once and SHALL go back, with a message, when the server refuses. After the call the job SHALL be reloaded so the next run shown is the server's.

#### Scenario: Pause

- **WHEN** the user turns the switch of an active job off
- **THEN** the pause request is sent, the row shows "Paused" and the next run disappears

#### Scenario: Resume

- **WHEN** the user turns the switch of a paused job on
- **THEN** the resume request is sent and the row shows the next run the server computed

#### Scenario: Server refuses

- **WHEN** the pause request fails
- **THEN** the switch returns to on and a message says the job could not be paused

### Requirement: Run now

The system SHALL let the user start a job once from its detail with `POST /api/cron/jobs/{id}/trigger`, and SHALL confirm that the run was requested without claiming it finished. The run is not awaited. A paused job SHALL be startable too.

#### Scenario: Run requested

- **WHEN** the user taps "Run now" and the server accepts
- **THEN** a message says the run was requested and the run history is reloaded

#### Scenario: Run refused

- **WHEN** the server answers with an error
- **THEN** a message says the run could not be started and shows nothing else changed

### Requirement: Delete

The system SHALL let the user delete a job from its detail with `DELETE /api/cron/jobs/{id}`, after a confirmation that names the job. Its past runs remain as chats.

#### Scenario: Confirmed

- **WHEN** the user confirms
- **THEN** the job is deleted, removed from the list, and the list is shown

#### Scenario: Cancelled

- **WHEN** the user cancels the confirmation
- **THEN** nothing is sent and the job stays

#### Scenario: Job already gone

- **WHEN** the delete answers 404
- **THEN** the job is removed from the list as if it had been deleted

### Requirement: Job detail

The system SHALL show for the selected job: its state and last result, when it runs next, the schedule in words with its raw expression, the prompt, and, when the job has them, the skills, model, provider, script, working directory, jobs it takes context from, the delivery target and the profile. It SHALL load the job with `GET /api/cron/jobs/{id}` so a change made elsewhere shows. A delivery failure the server recorded SHALL be shown apart from the run's own result. A job that is gone (404) SHALL be dropped from the list with a message.

#### Scenario: Full detail

- **WHEN** the user opens a job with skills, a model and a Telegram target
- **THEN** each is shown under its label, and settings the job does not have are not shown

#### Scenario: Delivery failed

- **WHEN** the last run succeeded but the server recorded a delivery error
- **THEN** the detail shows the run as succeeded and the delivery error separately

#### Scenario: Job vanished

- **WHEN** the detail request answers 404
- **THEN** the user returns to the list, the job is gone from it, and a message says it no longer exists

### Requirement: Run history

The system SHALL list a job's runs newest first from `GET /api/cron/jobs/{id}/runs` (20 at a time, with a way to ask for more up to the server's cap of 100), each with its start, its duration when it ended, and whether it is still active. Selecting a run SHALL open its session in the chat, on the run's profile, where the transcript can be read and continued. A run the chat's first page of sessions does not hold SHALL still open, fetched with `GET /api/sessions/{id}`; if it cannot be found, a message SHALL say so.

#### Scenario: Runs listed

- **WHEN** the detail opens for a job with five runs
- **THEN** five rows appear, newest first, each with a start time and a duration

#### Scenario: Active run

- **WHEN** a run's session is still active
- **THEN** the row says it is running and has no duration

#### Scenario: Open a run

- **WHEN** the user selects a run
- **THEN** the chat is shown with that run's session open

#### Scenario: Run outside the chat's first page

- **WHEN** the run is older than the sessions the chat has loaded
- **THEN** the run is fetched by id and opens all the same

#### Scenario: No runs yet

- **WHEN** the job has never run
- **THEN** the history says there are no runs yet

### Requirement: Wide layout

The system SHALL show the list and the selected job's detail side by side when the available width is 900 logical pixels or more, with the first job selected by default, and SHALL show the list alone with the detail pushed on top of it below that.

#### Scenario: Wide

- **WHEN** the width is 900 logical pixels or more
- **THEN** the list is on the left and the selected job's detail on the right

#### Scenario: Narrow

- **WHEN** the width is below 900 and the user selects a job
- **THEN** the detail replaces the list and a back action returns to it

### Requirement: Backend contract

The system SHALL read jobs with `GET /api/cron/jobs` (query `profile`) and `GET /api/cron/jobs/{id}`, parsing the bodies leniently because the routes declare no response schema: a row without an `id` is skipped; a missing text falls back to empty; `state` is one of `scheduled`, `paused`, `completed`, `error`, and anything else counts as `scheduled`; `next_run_at` and `last_run_at` are ISO 8601 times and one that does not parse counts as absent; `schedule_display` is the schedule in words; `last_status` is `ok` or an error and `last_error` and `last_delivery_error` are texts; `deliver` names the target; `repeat` carries `times` and `completed`. Runs SHALL be read from the `runs` array of the runs response, in the shape of a session row. The minimum server version is one that has these routes.

#### Scenario: Malformed row

- **WHEN** the list holds a row without an id and a row that is not an object
- **THEN** both are skipped and the other rows show

#### Scenario: Unknown state

- **WHEN** a job's state is a word the app does not know
- **THEN** the job is treated as scheduled

#### Scenario: Unparseable time

- **WHEN** `next_run_at` is not a valid time
- **THEN** the row shows no next run
