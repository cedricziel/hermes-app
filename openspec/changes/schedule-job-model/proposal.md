## Why

The job form's Advanced section takes the model and the provider as free text. A typo in either is only found when the job runs and fails, possibly hours later with nobody watching. The chat now has a picker that lists the models each authenticated provider offers, and the job form can use the same list.

## What Changes

- The "Model" and "Provider" text fields become one "Model" field that opens the shared model picker. It shows the job's model and its provider, or "Profile default" when the job has neither.
- The picker lists the models of the job's profile (`GET /api/model/options?profile=`), grouped by provider, with a "Use the profile's default" entry first. Picking a model sets both model and provider; the default entry clears both.
- The picker's reasoning-effort section is hidden here: cron jobs take no effort (`CronJobCreate` has only `model` and `provider`).
- A saved model the list does not offer (a custom provider, a model the server no longer lists, or a model saved without a provider) stays in the field, marked as not in the server's list, and is sent back unchanged. Only a new pick replaces it.
- When the list cannot be loaded, the field still shows the saved value, and the picker offers only the default entry.
- The shared picker gains two options for this: hiding effort and offering a default entry. The chat pill keeps its current behaviour.

This is the schedule step of the stack started by `chat-model-selection`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `scheduled-task-editor`: the job form chooses the model and provider from the profile's model list instead of free text.

## Impact

- Code: `lib/src/models/widgets/model_picker.dart` (optional default entry and effort), a new model field widget in `lib/src/schedules/widgets/`, `lib/src/schedules/job_form_controller.dart` (loads the options for the job's profile), `lib/src/schedules/job_form_screen.dart`.
- Widgetbook: use cases for the job model field and the picker without effort and with a default entry.
- API: `GET /api/model/options` through the generated client, as the chat does. `POST /api/cron/jobs` and `PUT /api/cron/jobs/{id}` unchanged. No change to `openapi/` or `packages/hermes_api`.

## Non-goals

- Effort, fast mode or a base URL per job. Hermes stores a `base_url` per job, but the dashboard's create schema has none, and effort is not a job field.
- Pinning a job to the profile's current model (`pinned`); "Use the profile's default" leaves the job following the profile.
- Typing a model the server does not list. A custom provider's model is kept when already saved, but a new one has to be set on the server.
- Blueprint forms, which have no model slot.

## Security and privacy impact

None. The options answer carries provider slugs, names and model ids, never credentials. Nothing new is stored on the device.

## Telemetry

None beyond the existing HTTP spans, which cover the options request.
