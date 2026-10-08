# model-settings Specification

## Purpose
Lets the user see and change the helper models a Hermes profile uses for its side jobs, from the app instead of the web dashboard.

## Requirements

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

Tapping a row SHALL open the model picker with the profile's models (`GET /api/model/options?profile=`), titled with the task's name, the slot's model checked, and a "Use the profile's default" entry above the providers, checked while the slot is on `auto`. When the picker closes with a pick that differs from the slot, the system SHALL send `POST /api/model/set?profile=<chat profile>` with `{"scope": "auxiliary", "task": <task>, "provider", "model"}` plus `reasoning_effort` when an effort is picked, and the default entry SHALL send `provider: "auto"` and an empty model. The row SHALL show the new model once the server accepts it, and the old one with an error message when it does not. When the answer carries `confirm_required: true`, the system SHALL show its `confirm_message` and resend the same body with `confirm_expensive_model: true` only when the user confirms; otherwise nothing changes.

#### Scenario: Pin a model

- **WHEN** the user opens Vision, picks `gpt-5-mini` under OpenAI and closes the picker
- **THEN** the app posts `{"scope": "auxiliary", "task": "vision", "provider": "openai", "model": "gpt-5-mini"}` and the row shows `gpt-5-mini`

#### Scenario: Back to the main model

- **WHEN** the user picks "Use the profile's default" for a pinned slot
- **THEN** the app posts `provider: "auto"` and `model: ""` for that task and the row reads "Same as main model"

#### Scenario: Expensive model declined

- **WHEN** the server answers `{"ok": false, "confirm_required": true, "confirm_message": "…"}` and the user cancels the confirmation
- **THEN** no second request is sent and the row keeps its previous model

#### Scenario: Nothing picked

- **WHEN** the user closes the picker without changing the pick
- **THEN** no request is sent

### Requirement: Mixture-of-agents slots

The helper models screen SHALL read `GET /api/model/moa?profile=<chat profile>` (Hermes Agent at `HERMES_REF` 7b3c7ae or later), whose answer is `{"default_preset", "active_preset", "presets": {<name>: {"reference_models": [{"provider", "model", "reasoning_effort"?, "enabled"}], "aggregator": {"provider", "model", "reasoning_effort"?}, …}}, …}`, and show a "Mixture of agents" section with one row per reference model of the default preset ("Advisor 1", "Advisor 2", …) and one for its aggregator. A row SHALL show the model id, the provider and the effort label when one is set; a disabled advisor SHALL be marked "(off)" after its name. The section header SHALL name the preset when it is not `default`. Slots without a provider and model SHALL be skipped. When the MoA config cannot be read or has no preset, the section SHALL be left out.

#### Scenario: Default preset shown

- **WHEN** the default preset has advisors `openai-codex/gpt-5.5` and `openrouter/deepseek-v4-pro` and the aggregator `openrouter/claude-opus-4.8`
- **THEN** the section lists "Advisor 1", "Advisor 2" and "Aggregator" with those models

#### Scenario: MoA unavailable

- **WHEN** `GET /api/model/moa` fails
- **THEN** the task slots are shown and the Mixture of agents section is not

### Requirement: Changing a mixture-of-agents slot

Tapping a MoA row SHALL open the model picker with the slot's model checked, without the "Use the profile's default" entry and without the `moa` provider. When the picker closes with a different pick, the system SHALL send `PUT /api/model/moa?profile=<chat profile>` with the config as read, in which only that slot's provider, model and effort changed; every other preset, slot and setting SHALL be sent as the server reported it. A slot's `enabled` flag SHALL be kept. While the request runs, the MoA rows SHALL not open. The row SHALL show the new model once the server accepts it; on an error (for example a 422 for an invalid config) it SHALL keep the old one and say that the change failed.

#### Scenario: Change the aggregator

- **WHEN** the user picks `claude-sonnet-4-5` under Anthropic for the aggregator and closes the picker
- **THEN** the app sends the MoA config with `presets.default.aggregator` set to `{"provider": "anthropic", "model": "claude-sonnet-4-5"}` and the other slots unchanged

#### Scenario: Rejected config

- **WHEN** `PUT /api/model/moa` answers 422
- **THEN** the row keeps its previous model and the screen says the change failed

### Requirement: No mixture-of-agents save while the privacy filter is on

The system SHALL NOT save the mixture of agents while `GET /api/model/moa` reports a non-empty `privacy_filter`, because `PUT /api/model/moa` has no field for it and Hermes then writes it as off. Its slots SHALL still be listed but SHALL NOT open the picker, and the section SHALL say that the privacy filter is on and the slots are changed on the server.

#### Scenario: Privacy filter on

- **WHEN** the answer carries `"privacy_filter": "display"` and the user taps the aggregator
- **THEN** no picker opens and no `PUT /api/model/moa` is sent
