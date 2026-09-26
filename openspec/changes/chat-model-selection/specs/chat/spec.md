## ADDED Requirements

### Requirement: Model and effort pill in the composer

The system SHALL show a pill in the composer with the open chat's model id and, when that model reasons and an effort is chosen, the effort's label after a separator in a dimmer colour. With no choice made in the chat, the pill SHALL show the profile's current model as reported by the server. A long model id SHALL be truncated with an ellipsis so the pill stays on one line. The pill SHALL be hidden while the model list has not loaded, when loading it failed, and when no provider is ready.

#### Scenario: Default model shown

- **WHEN** a chat is open, no model has been chosen in it, and the options report `"model": "claude-opus-4"`
- **THEN** the pill reads "claude-opus-4"

#### Scenario: Choice with effort shown

- **WHEN** the user has chosen model `gpt-5` with effort `high` in the open chat
- **THEN** the pill reads "gpt-5 · High", with "High" in a dimmer colour

#### Scenario: Options unavailable

- **WHEN** `GET /api/model/options` fails or lists no authenticated provider with models
- **THEN** no pill is shown and the composer works as before

### Requirement: Picking a model and effort

The system SHALL open a picker when the pill is tapped, as a bottom sheet below 900 logical pixels and as a dialog at 900 or wider. The picker SHALL list the models of every authenticated provider that has models, grouped under the provider's name, with the chat's current model checked. When the selected model reasons, the picker SHALL offer the effort levels Minimal, Low, Medium, High, Extra High, Max and Ultra, and Off when the model can disable reasoning. When it does not reason, no effort SHALL be offered and none SHALL be sent. Picking a model or an effort SHALL update the pill at once. Switching to another profile SHALL reload the list and drop the choice.

#### Scenario: Pick a model

- **WHEN** the user taps the pill and picks `gpt-5` under OpenAI
- **THEN** the pill shows "gpt-5" and the next message in that chat uses it

#### Scenario: Model without reasoning

- **WHEN** the selected model's capabilities report `"reasoning": false`
- **THEN** the picker offers no effort levels and the pill shows only the model

#### Scenario: Profile switch

- **WHEN** the user switches the chat screen to another profile
- **THEN** that profile's model list is loaded and the pill shows its current model

### Requirement: Sending the chosen model

The system SHALL send a chat's model choice to the gateway with the message. For a new chat, `session.create` SHALL carry `model`, `provider` and, when an effort is chosen, `reasoning_effort`. For an existing chat, after `session.resume` and before `prompt.submit`, the system SHALL call `config.set` with the runtime `session_id`, key `model` and value `<model> --provider <provider>` when the model differs from the one last applied to that chat, and with key `reasoning` and the effort as value when the effort differs. It SHALL NOT send `scope: "global"`. With no choice made, none of these fields or calls SHALL be sent. An error from `session.create` or `config.set` SHALL end the send as a failed reply, as any other gateway error does.

#### Scenario: New chat with a choice

- **WHEN** the user picks `gpt-5` from provider `openai` with effort `high` and sends the first message of a new chat
- **THEN** `session.create` carries `"model": "gpt-5"`, `"provider": "openai"` and `"reasoning_effort": "high"`

#### Scenario: Existing chat, model changed

- **WHEN** the user picks a different model in an existing chat and sends a message
- **THEN** `config.set` with key `model` goes out before `prompt.submit`

#### Scenario: Existing chat, nothing changed

- **WHEN** the user sends a second message in a chat without changing the choice
- **THEN** no `config.set` is sent

### Requirement: Model options contract

The system SHALL load the model list with `GET /api/model/options`, with the `profile` query parameter when a profile is known. The answer is an object with `providers`, `model` (the current model id) and `provider` (the current provider slug). Each provider carries `slug`, `name`, `is_current`, `authenticated` (may be missing), `models` (a list of model id strings) and `capabilities` (a map from model id to an object with `reasoning` and optionally `can_disable_reasoning`). A missing `reasoning` SHALL be read as true. A provider SHALL be listed only when `authenticated` is not false and it has models. The body SHALL be parsed leniently: rows without a `slug` and model entries that are not strings are skipped, and a body that is not an object reads as no providers. The session overrides rely on `session.create` accepting `model`, `provider` and `reasoning_effort`, and on `config.set` accepting the session-scoped `model` and `reasoning` keys. The minimum Hermes version is 0.21.4.

#### Scenario: Junk rows skipped

- **WHEN** the options list a provider without a `slug` and a provider whose `models` holds a number
- **THEN** the first is left out and the second lists only its string model ids

#### Scenario: Unauthenticated provider hidden

- **WHEN** a provider row has `"authenticated": false`
- **THEN** its models are not offered
