## MODIFIED Requirements

### Requirement: Tasks are created from a form

The system SHALL offer a "New task" action on the board that opens a form with a title, a description, an assignee (defaulting to "Auto (triage picks)", with the profiles and assignees the board knows as options), a model (defaulting to "Profile default"), a priority of Normal or P1 to P3, and a start of Triage (the default) or Todo. Creating SHALL call `POST /api/plugins/kanban/tasks` with the selected board and, when a tenant filter is active, that tenant. A task without a title SHALL NOT be sent. When the plugin answers with a dispatcher warning, the system SHALL show it. When the plugin refuses the task, the form SHALL stay open and show the plugin's reason.

#### Scenario: Create a triage task

- **WHEN** the user enters a title, chooses P2 and creates the task
- **THEN** the request carries the title, priority 2 and `triage: true`, the form closes and the board refreshes

#### Scenario: Missing title

- **WHEN** the user creates a task with an empty title
- **THEN** no request is sent and the form stays open

## ADDED Requirements

### Requirement: A new task can run on a chosen model

The create form SHALL load the models it offers from `GET /api/plugins/kanban/model-options`, which answers `{"providers": [{"slug", "label", "models": [<model id>]}]}` and lists only providers the user configured. Tapping the form's model row SHALL open a picker with a "Use the profile's default" entry, then each provider's models under its label, and, once a model is picked, the reasoning efforts Minimal, Low, Medium, High, Extra High, Max and Ultra. Creating the task with a picked model SHALL send `model_override` (the model id) and `provider_override` (the provider slug), plus `reasoning_effort` (`minimal` to `ultra`) when an effort is picked. With the profile's default, none of the three SHALL be sent. When the answer lists no provider, or the request fails, the row SHALL be a text field instead, and a non-empty name SHALL be sent as `model_override` alone. The route and fields are those of the Kanban plugin in Hermes Agent 0.21.4; an older plugin that lacks the route gets the text field.

#### Scenario: Create a task on a chosen model

- **WHEN** the user picks `claude-opus-4` under Anthropic with effort High and creates the task
- **THEN** the request carries `model_override: "claude-opus-4"`, `provider_override: "anthropic"` and `reasoning_effort: "high"`

#### Scenario: Back to the profile default

- **WHEN** the user picks a model, then picks "Use the profile's default", and creates the task
- **THEN** the request carries no `model_override`, `provider_override` or `reasoning_effort`

#### Scenario: No models listed

- **WHEN** the plugin answers `{"providers": []}` and the user types `gpt-5` into the model field
- **THEN** the request carries `model_override: "gpt-5"` and no provider or effort
