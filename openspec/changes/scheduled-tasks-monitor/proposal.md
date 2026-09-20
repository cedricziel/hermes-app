## Why

Hermes runs scheduled tasks (cron jobs): a prompt or script on a schedule, whose result is delivered to a chat platform or kept locally. The dashboard has a page for them, and agents create them through a tool, but the app shows nothing. A user who set up a morning brief has no way to see from their phone that it stopped working, to run it once, or to pause it.

This is the first of three changes. It gives the user a place to watch and control jobs that already exist. Creating and editing (`scheduled-tasks-editor`) and alerts (`scheduled-tasks-alerts`) build on it.

## What Changes

- A **Schedules** destination next to Chat and Kanban, shown when the server has the cron routes. Unlike Kanban it is not a plugin, so it is offered whenever those routes answer.
- The signed-in home screen is no longer the chat alone once there is more than one destination. Chat-only servers (no Kanban, no cron routes) look exactly as before.
- A job list, filtered to the active profile by default, with chips for all profiles, failing and paused jobs. Each row shows the name, the schedule in words, the next run, the last result and the delivery target, with a switch to pause and resume.
- A job detail: status, run now, pause and resume, delete, the schedule with its raw expression, the prompt, the settings the job carries, and the run history.
- Opening a run from the history shows it in the chat, where its transcript can be read and continued.
- A two-pane list and detail on wide screens.
- The Kanban requirements that promise a bare chat and a two-item navigation are reworded for a navigation with any number of destinations.

## Capabilities

### New Capabilities

- `scheduled-tasks`: the Schedules destination, the job list and filters, the job detail, pause, resume, run now and delete, the run history and opening a run as a chat, and the backend routes relied on.

### Modified Capabilities

- `kanban`: "Plugin detection gates the Kanban tab" and "Chat and Kanban navigation adapts to screen width" no longer say that the home screen is the chat alone or that the navigation has exactly two destinations.

## Impact

- New `lib/src/schedules/` (models, repository, controller, screens). `lib/src/shell/app_shell.dart` builds its destinations from what the server offers. `lib/src/chat/chat_screen.dart` learns to open a session that another destination asks for, including one outside its first page of sessions.
- Tests: models, repository, controller, screens and shell, run against `FakeHermesServer`. `test/real_backend_contract_test.dart` gains the cron shapes.
- No change to `openapi/` or `packages/hermes_api`: every route used is already in the generated client. No native, entitlement or signing change.
- Minimum server: a Hermes with `/api/cron/jobs` (0.21.3 has it). An older server has no Schedules destination.

## Non-goals

- Creating or editing jobs, and blueprints (`scheduled-tasks-editor`).
- Notifications about runs (`scheduled-tasks-alerts`).
- Background polling while the app is closed.
- A "running now" indicator in the list. A job record carries no running state; only a run's own session says whether it is still active, so the detail shows it and the list does not.
- The managed-cron fire webhook (`/api/cron/fire`), which is for the hosted scheduler and not for clients.

## Security and privacy impact

None on tokens or storage. Job prompts, scripts and results are shown to the signed-in user only, over the existing authenticated connection. Nothing about a job is written to preferences.

## Telemetry

The requests go through the existing Dio pipeline, so they are traced as any other request. The route template is used as the span name, never the job id. No new spans or events.
