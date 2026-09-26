## Why

A Kanban task runs on its assignee profile's model. Hermes lets a task override that: `POST /api/plugins/kanban/tasks` takes `model_override`, `provider_override` and `reasoning_effort`, and the plugin lists the models it accepts at `GET /api/plugins/kanban/model-options`. The app's create form offers none of this, so a task that needs a stronger or cheaper model has to be created on the dashboard.

## What Changes

- The create form gets a "Model" row showing "Profile default" until the user picks something. Tapping it opens the model picker the chat already uses, fed with the plugin's options: the models of each configured provider, grouped by provider, and the effort levels Minimal to Ultra for the picked model.
- The picker's "Use the profile's default" entry (`onUseDefault`, added to the shared picker on the base branch) clears the choice and closes the picker. The pill gains the same optional callback, names "Profile default" while nothing is picked, and passes it on; the chat passes nothing and keeps working as before.
- Creating a task with a pick sends `model_override`, `provider_override` and, when an effort is picked, `reasoning_effort`. With no pick, none of the three is sent.
- When the plugin lists no providers (none configured, the route failed or does not exist), the row becomes a text field for a model name, as the dashboard does. A typed name is sent as `model_override` alone.
- Options load once when the form opens.

This is the Kanban create step of the model-selection stack. The task panel and bulk edit follow in `kanban-task-panel-model`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `kanban`: the create form can set a task's model, provider and reasoning effort.

## Impact

- Code: `lib/src/kanban/kanban_create_screen.dart`, `lib/src/kanban/kanban_repository.dart` (options and create fields), `lib/src/models/model_provider_option.dart` (read the plugin's `label`), `lib/src/models/widgets/composer_model_pill.dart` (passes `onUseDefault` to the picker).
- Widgetbook: use cases for the pill and picker with the default entry.
- API: `GET /api/plugins/kanban/model-options` and the existing create route, through the generated client. No change to `openapi/` or `packages/hermes_api`.
- Contract test: the options shape in `test/real_backend_contract_test.dart`.

## Non-goals

- Changing an existing task's model or effort, and bulk edit (`kanban-task-panel-model`).
- A reasoning effort without a model override on create. The server allows it; the form offers effort only with a picked model, and the default entry leaves both to the profile.
- Thinking off (`none`). The plugin reports no capabilities, so the app cannot tell which models can turn reasoning off; only Hermes' `VALID_REASONING_EFFORTS` are offered.
- Setting up providers. Only providers the user configured are listed.

## Security and privacy impact

None. The options answer carries provider slugs, labels and model ids, never credentials. Nothing is stored.

## Telemetry

None beyond the existing HTTP spans, which already cover the options request.
