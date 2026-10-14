## Why

`kanban-task-model` lets a new task run on a chosen model. An existing task still cannot be moved to another model from the app, which is the usual fix when a provider is rate-limited or a task turns out harder than expected, and there is no way to raise or lower the reasoning effort of several tasks at once. Hermes supports both: `PATCH /api/plugins/kanban/tasks/{id}` sets or clears the override, and `POST /api/plugins/kanban/tasks/bulk` sets the effort of many tasks.

## What Changes

- The task panel shows a "Model" section with the task's override (for example "claude-opus-4 · High") or "Profile default". Tapping it opens the model picker with the plugin's list and its "Use the profile's default" entry, which closes it. When the picker closes, one change is sent, and only if the pick differs from the task.
- Picking a model sends `model_override` and `provider_override`, plus `reasoning_effort` when one is picked. Picking "Use the profile's default" sends `clear_model_override` and `clear_reasoning_effort`.
- When the plugin lists no models, tapping the section asks for a model name instead; an empty name clears the override.
- Bulk edit gets an Effort action: pick a level (Minimal to Ultra) or "Profile default" for every selected task, sent as `reasoning_effort` or `clear_reasoning_effort`.
- Task rows are read with their `model_override`, `provider_override` and `reasoning_effort`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `kanban`: a task's model and effort can be changed from its detail, and bulk edit can set the effort.

## Impact

- Code: `lib/src/kanban/kanban_models.dart` (override fields), `kanban_repository.dart` (update and bulk fields), `kanban_task_controller.dart` (options and model change), `kanban_board_controller.dart` and `kanban_screen.dart` (bulk effort), `widgets/task_panel/kanban_task_fields.dart`, `widgets/kanban_task_panel.dart`, `widgets/kanban_bulk_bar.dart`.
- Widgetbook: the fields with and without an override, the bulk bar.
- API: existing routes through the generated client. No change to `openapi/` or `packages/hermes_api`.
- Contract test: a task created with an override reports it back.

## Non-goals

- Bulk model changes. A model pair for many tasks at once is rarely what the user wants, and the dashboard's bulk bar does not offer it either.
- Changing effort without the picker on the panel (an effort-only override shows in the section and is cleared with the default entry).
- Thinking off (`none`) from the app, as in `kanban-task-model`. A `none` set elsewhere is shown as "Off".

## Security and privacy impact

None. Only model ids, provider slugs and effort levels are sent or shown.

## Telemetry

None beyond the existing HTTP spans.
