# Bot Creation Specification

## Purpose

TBD - created by archiving change simplify-bot-creation. Update Purpose after archive.

## Requirements

### Requirement: Progressive bot creation

The system SHALL initially show Name, Title, and Description with guidance that Name is permanent. Advanced SHALL disclose standing instructions, model and provider selection, and a default-on option labelled Copy provider API keys. The form SHALL explain that OAuth sign-ins require separate authentication. Dialog chrome, actions, text fields, and switches SHALL adapt to Apple and Material platforms using the same grouped form layout as app settings, with persistent field labels and enough desktop width for the form.

#### Scenario: Basic creation

- **WHEN** the user creates a bot without expanding Advanced
- **THEN** no model or provider override is sent, and API key copying remains enabled
- **AND** an empty name produces visible validation without a backend write

#### Scenario: Advanced model selection

- **WHEN** the user selects a model under Advanced
- **THEN** the chosen provider and model are sent together
- **AND** the user can return to the inherited default, removing both overrides

#### Scenario: Model catalog failure

- **WHEN** the model catalog cannot load
- **THEN** the form reports the failure, permits retry, and still permits basic creation

### Requirement: Creation completion and recovery

The system SHALL prevent concurrent submissions, retain drafts and the created profile after metadata failure, and open the saved bot's canonical chat after successful creation. It SHALL NOT submit an automatic introduction prompt.

#### Scenario: Successful creation

- **WHEN** profile creation and Bot Mode metadata saving succeed
- **THEN** the dialog closes and the new bot's canonical chat opens with its saved title and description

#### Scenario: Partial failure

- **WHEN** profile creation succeeds but metadata saving fails
- **THEN** the draft remains and retry saves metadata without creating another profile or opening the chat prematurely

### Requirement: Existing creation backend contracts

The system SHALL use authenticated profiles.create with name, description, optional soul, model and provider, explicit mirror_credentials, and clone_channels=false. It SHALL check ok and name before revision-checked profiles.configure saves ui_meta.hermes-bots. Model options SHALL use GET /api/model/options through the generated client. Chat opening SHALL reuse exact canonical Bot Chat lookup and creation. The verified profile baseline is source 0.21.4; support SHALL be capability-based rather than a guessed minimum release.

#### Scenario: Contract preservation

- **WHEN** the user saves a new bot
- **THEN** creation and metadata writes use existing authenticated contracts and the client does not read or copy credential values
