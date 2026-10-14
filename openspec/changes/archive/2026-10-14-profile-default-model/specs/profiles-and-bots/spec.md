## ADDED Requirements

### Requirement: Changing a profile's default model

The system SHALL let the user change the default model of any listed profile from the Profiles screen, without switching to that profile. It SHALL offer the models of every authenticated provider that profile can use, grouped by provider, with the profile's current model checked, and SHALL say that the default applies to chats started afterwards while open chats keep their model. It SHALL NOT offer a reasoning effort. Saving SHALL send `PUT /api/profiles/{name}/model` with the body `{"provider": <provider slug>, "model": <model id>}`, with the profile name percent-encoded in the path. The server answers `{"ok": true, "provider", "model"}`, and 400 when the pair is not usable. The route and `GET /api/model/options?profile=` exist in the Hermes version pinned by `HERMES_REF`.

#### Scenario: Opening the picker

- **WHEN** the user taps "Change default model" on a profile row
- **THEN** the models are loaded with `GET /api/model/options?profile=<name>` and a picker titled "Default model" opens with that profile's current model checked, a note that new chats use it, and no effort levels

#### Scenario: Saving a new default

- **WHEN** the user picks `gpt-5` under the provider `openrouter` for the profile `work`
- **THEN** the picker closes, `PUT /api/profiles/work/model` is sent with `{"provider": "openrouter", "model": "gpt-5"}`, the profile list reloads, and a message says new chats in that profile use `gpt-5`

#### Scenario: Picking the current model

- **WHEN** the user picks the model that is already the profile's default
- **THEN** nothing is sent

#### Scenario: Save refused

- **WHEN** the server refuses the change
- **THEN** the user is told "Could not change the default model" and the row keeps its old model

#### Scenario: Models unavailable

- **WHEN** the model list cannot be loaded or offers no model
- **THEN** no picker opens and the user is told "Could not load models"

#### Scenario: Active profile and chat unchanged

- **WHEN** the default model of a profile is changed
- **THEN** the active profile and the profile shown in the chat stay as they were
