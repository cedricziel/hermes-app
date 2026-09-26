## ADDED Requirements

### Requirement: Mixture-of-agents slots

The helper models screen SHALL read `GET /api/model/moa?profile=<chat profile>` (Hermes Agent at `HERMES_REF` 7b3c7ae or later), whose answer is `{"default_preset", "active_preset", "presets": {<name>: {"reference_models": [{"provider", "model", "reasoning_effort"?, "enabled"}], "aggregator": {"provider", "model", "reasoning_effort"?}, …}}, …}`, and show a "Mixture of agents" section with one row per reference model of the default preset ("Advisor 1", "Advisor 2", …) and one for its aggregator. A row SHALL show the model id, the provider and the effort label when one is set; a disabled advisor SHALL be marked "(off)" after its name. The section header SHALL name the preset when it is not `default`. Slots without a provider and model SHALL be skipped. When the MoA config cannot be read or has no preset, the section SHALL be left out.

#### Scenario: Default preset shown

- **WHEN** the default preset has advisors `openai-codex/gpt-5.5` and `openrouter/deepseek-v4-pro` and the aggregator `openrouter/claude-opus-4.8`
- **THEN** the section lists "Advisor 1", "Advisor 2" and "Aggregator" with those models

#### Scenario: MoA unavailable

- **WHEN** `GET /api/model/moa` fails
- **THEN** the task slots are shown and the Mixture of agents section is not

### Requirement: Changing a mixture-of-agents slot

Tapping a MoA row SHALL open the model picker with the slot's model checked, without a "Same as main model" entry and without the `moa` provider. When the picker closes with a different pick, the system SHALL send `PUT /api/model/moa?profile=<chat profile>` with the config as read, in which only that slot's provider, model and effort changed; every other preset, slot and setting SHALL be sent as the server reported it. A slot's `enabled` flag SHALL be kept. While the request runs, the MoA rows SHALL not open. The row SHALL show the new model once the server accepts it; on an error (for example a 422 for an invalid config) it SHALL keep the old one and say that the change failed.

#### Scenario: Change the aggregator

- **WHEN** the user picks `claude-sonnet-4-5` under Anthropic for the aggregator and closes the picker
- **THEN** the app sends the MoA config with `presets.default.aggregator` set to `{"provider": "anthropic", "model": "claude-sonnet-4-5"}` and the other slots unchanged

#### Scenario: Rejected config

- **WHEN** `PUT /api/model/moa` answers 422
- **THEN** the row keeps its previous model and the screen says the change failed
