## MODIFIED Requirements

### Requirement: Several tasks can be changed at once

The system SHALL offer a selection mode, entered by long-pressing a card on a narrow screen or from the board menu ("Select tasks"). In selection mode tapping a card selects or deselects it instead of opening it, the app bar shows the number selected, and a bar offers Move, Assign, Priority, Effort and Archive (after a confirmation), applied with `POST /api/plugins/kanban/tasks/bulk`. Effort offers "Profile default" and the levels Minimal, Low, Medium, High, Extra High, Max and Ultra; a level is sent as `reasoning_effort` (`minimal` to `ultra`) and "Profile default" as `clear_reasoning_effort: true`. When the plugin refuses some of the tasks, the system SHALL name how many failed and why, and SHALL keep exactly those tasks selected so the change can be retried; otherwise selection mode ends. Selected tasks that leave the board SHALL be dropped from the selection.

#### Scenario: Partial failure

- **WHEN** a bulk archive of two tasks is refused for one of them
- **THEN** a message says 1 of 2 could not be changed, and only the refused task stays selected

#### Scenario: Raise the effort of several tasks

- **WHEN** the user selects two tasks, taps Effort and picks High
- **THEN** one bulk request carries both ids and `reasoning_effort: "high"`

## ADDED Requirements

### Requirement: A task's model can be changed from its detail

The task detail SHALL show a Model section with the task's `model_override` and, when set, its `reasoning_effort` (for example "claude-opus-4 · High", or "Off" for `none`), or "Profile default" when the task has neither. Tapping it SHALL open the model picker with the models from `GET /api/plugins/kanban/model-options` and a "Use the profile's default" entry, which closes the picker. When the picker closes, the system SHALL send one `PATCH /api/plugins/kanban/tasks/{id}` if, and only if, the pick differs from the task: a model sends `model_override` and `provider_override`, plus `reasoning_effort` when an effort is picked; "Use the profile's default" sends `clear_model_override: true` and `clear_reasoning_effort: true`. When the plugin lists no models, tapping the section SHALL ask for a model name instead: a name is sent as `model_override`, and an empty name as `clear_model_override: true`. The fields are those of the Kanban plugin in Hermes Agent 0.21.4.

#### Scenario: Move a task to another model

- **WHEN** the user opens a task on the profile default, picks `claude-opus-4` under Anthropic with effort High and closes the picker
- **THEN** one patch carries `model_override: "claude-opus-4"`, `provider_override: "anthropic"` and `reasoning_effort: "high"`, and the task reloads

#### Scenario: Back to the profile default

- **WHEN** a task has an override and the user picks "Use the profile's default"
- **THEN** one patch carries `clear_model_override: true` and `clear_reasoning_effort: true`

#### Scenario: Picker closed without a change

- **WHEN** the user opens the picker and closes it without picking anything new
- **THEN** no request is sent
