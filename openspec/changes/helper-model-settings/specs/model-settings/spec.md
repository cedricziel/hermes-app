## Purpose

Lets the user see and change the helper models a Hermes profile uses for its side jobs, from the app instead of the web dashboard.

## ADDED Requirements

### Requirement: Helper model list

The system SHALL offer a "Helper models" screen from the chat sidebar's More section while signed in. It SHALL read `GET /api/model/auxiliary?profile=<chat profile>` (Hermes Agent at `HERMES_REF` 7b3c7ae or later), whose answer is `{"tasks": [{"task", "provider", "model", "base_url", "reasoning_effort", "local_endpoint"}], "main": {"provider", "model"}}`, and show one row per task in the server's order. A row SHALL name the task in words ("Vision", "Chat titles", and the task id itself for a task the app does not know) and show the model it runs on: "Same as main model" with the main model's id when the provider is `auto` or empty, otherwise the model id, the provider and the effort label when an effort is set. Rows that do not carry a task name SHALL be skipped. The screen SHALL say that changes apply to new chats. When the list cannot be loaded, the screen SHALL say so and offer to retry.

#### Scenario: Slot on auto

- **WHEN** the server reports `{"task": "vision", "provider": "auto", "model": ""}` and the main model `claude-opus-4`
- **THEN** the Vision row reads "Same as main model (claude-opus-4)"

#### Scenario: Pinned slot

- **WHEN** the server reports `{"task": "title_generation", "provider": "openrouter", "model": "gemini-flash", "reasoning_effort": "low"}`
- **THEN** the Chat titles row shows "gemini-flash", "openrouter" and "Low"

#### Scenario: Load fails

- **WHEN** `GET /api/model/auxiliary` fails
- **THEN** the screen shows an error with a Retry button instead of rows

### Requirement: Changing a helper model

Tapping a row SHALL open the model picker with the profile's models (`GET /api/model/options?profile=`), the slot's model checked, and a "Same as main model" entry above the providers. When the picker closes with a pick that differs from the slot, the system SHALL send `POST /api/model/set?profile=<chat profile>` with `{"scope": "auxiliary", "task": <task>, "provider", "model"}` plus `reasoning_effort` when an effort is picked, and "Same as main model" SHALL send `provider: "auto"` and an empty model. The row SHALL show the new model once the server accepts it, and the old one with an error message when it does not. When the answer carries `confirm_required: true`, the system SHALL show its `confirm_message` and resend the same body with `confirm_expensive_model: true` only when the user confirms; otherwise nothing changes.

#### Scenario: Pin a model

- **WHEN** the user opens Vision, picks `gpt-5-mini` under OpenAI and closes the picker
- **THEN** the app posts `{"scope": "auxiliary", "task": "vision", "provider": "openai", "model": "gpt-5-mini"}` and the row shows `gpt-5-mini`

#### Scenario: Back to the main model

- **WHEN** the user picks "Same as main model" for a pinned slot
- **THEN** the app posts `provider: "auto"` and `model: ""` for that task and the row reads "Same as main model"

#### Scenario: Expensive model declined

- **WHEN** the server answers `{"ok": false, "confirm_required": true, "confirm_message": "…"}` and the user cancels the confirmation
- **THEN** no second request is sent and the row keeps its previous model

#### Scenario: Nothing picked

- **WHEN** the user closes the picker without changing the pick
- **THEN** no request is sent
