## Why

With `scheduled-tasks-monitor` the user can see and control jobs but not make or change one. Setting up a job means opening the web dashboard or asking the agent in chat. The dashboard offers 15 ready-made blueprints so that nobody has to write cron, plus a full form; the app should offer both.

## What Changes

- A **New** action on the Schedules list opens a gallery: a "Custom task" card and the server's blueprints, searchable and filterable by category.
- A blueprint opens a short form built from the slots the server describes (time, choice, text, weekdays), and creates the job through the server's own blueprint route, so the server fills in the schedule and prompt.
- **Custom task** and **Edit** open one form: name, prompt, when, where to deliver, profile, start paused, and an Advanced section (skills, model and provider, pre-run script, context from other jobs, working directory).
- "When" is a picker (Every, Daily, Weekly, Once) that writes the schedule string Hermes understands and previews the next runs; a Cron option takes a raw expression.
- The delivery list comes from the server, with a warning when a platform has no home channel.
- Server refusals show next to the form and keep what the user typed.

## Capabilities

### New Capabilities

- `scheduled-task-editor`: the blueprint gallery and form, the job form, the schedule picker and the routes used to create and change jobs.

### Modified Capabilities

None. It builds on `scheduled-tasks`, which `scheduled-tasks-monitor` introduces; archive that change first.

## Impact

- `lib/src/schedules/`: blueprint and draft models, a schedule codec (picker to string and back), `ScheduleEditorController`, the gallery, blueprint form and job form screens; the repository gains create, update, blueprints, instantiate and delivery targets.
- The list gets a **New** button and the detail an **Edit** action.
- Tests against `FakeHermesServer`, and a real-backend contract check for blueprints.
- No change to `openapi/`, `packages/hermes_api`, native code or entitlements.

## Non-goals

- Creating a job by describing it in chat.
- Editing the base URL, tool sets, reasoning effort, attach-to-session or failure delivery of a job. The form leaves those untouched on edit.
- A skill picker. Skills are typed as names.
- Choosing a time zone: times are the phone's local time, sent in the form the server reads.
- Computing next runs for a raw cron expression on the phone. The server answers with the real next run once saved.

## Security and privacy impact

The form can name a pre-run script and a working directory, which run on the server. The server validates that a script lies inside the profile's scripts directory and refuses others; the app shows the refusal and does not try to check paths itself. Prompts the user types are sent only to the signed-in server. Nothing is stored on the phone except an unsaved draft in memory.

## Telemetry

None beyond the traced requests.
