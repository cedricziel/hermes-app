## Purpose

Expose Hermes specialists as profile-backed named bots, with shared identity and configuration that persists across clients.

## ADDED Requirements

### Requirement: Specialist roster

The system SHALL expose Bots as a primary destination and Messaging as platform settings. It SHALL distinguish managed bots from plain profiles using the server's `ui_meta["hermes-bots"]` object, and offer to add existing profiles explicitly.

#### Scenario: Roster loads

- **WHEN** the user opens Bots
- **THEN** managed profiles appear with their friendly title, description, model, and canonical conversation preview when available
- **AND** title fallback is profile display name then profile name, identity includes the connected server and profile name, and search filters the roster

#### Scenario: Empty, loading, and failed states

- **WHEN** the roster is loading, empty, or unavailable
- **THEN** the view respectively shows progress, an Add bot action, or an explanatory error and Retry
- **AND** unread and working badges appear only when supported by observed activity rather than gateway connectivity alone

### Requirement: Bot creation and editing

The system SHALL let the user create a fresh profile-backed bot or add an existing profile, and edit its friendly title, description, standing instructions, and profile default model.

#### Scenario: Fresh bot

- **WHEN** the user provides a valid unique profile name and saves
- **THEN** the server creates the profile and persists its Bot Mode metadata
- **AND** the UI explains the choice to use the current provider credentials, sends an explicit `mirror_credentials` value, never copies messaging channels, and retains partial creation information if metadata saving fails

#### Scenario: Existing profile

- **WHEN** the user adds an existing profile to Bots
- **THEN** its existing state and configuration are retained and only its Bot Mode presentation is added

#### Scenario: Concurrent or partial edit

- **WHEN** another client updates the same presentation or one requested section fails
- **THEN** the UI reloads server state, keeps unsaved user input, and identifies the unapplied section
- **AND** unrelated metadata fields are preserved, no lost update is silently retried, and a successful RPC alone is not treated as a successful save

### Requirement: Bot roster backend contract

The system SHALL use authenticated `/api/ws` JSON-RPC with the following contracts. The verified baseline is Hermes source version 0.21.4 at commit `35fdb4608aa8af455d2597664cff1754a3722cd1`; the earliest released version is unverified, so support SHALL be established through response capabilities rather than a guessed semantic version.

#### Scenario: List and edit contracts

- **WHEN** the app loads bots
- **THEN** `profiles.list` with `include_sessions: true` returns `profiles`, `bot_mode_protocol`, and per-profile `name`, `display_name`, `description`, `model`, `provider`, `ui_meta`, `ui_meta_revisions`, and optional `canonical_session`, `last_session`, `worker_session`
- **AND** editing reads `profiles.describe` with `name` (result `name`, `description`, `soul`, `model`) and writes `profiles.configure` with `name`, selected sections, `ui_meta` and `ui_meta_expected_revisions`
- **AND** the app checks each requested `applied` field, handles `ui_meta_conflicts`, and honors explicit expensive-model confirmation before resubmitting

#### Scenario: Creation contract

- **WHEN** the app creates a bot
- **THEN** `profiles.create` sends `name`, `description`, optional `soul`, `model`, `provider`, explicit `mirror_credentials`, and `clone_channels: false`, with no `clone_from` for a fresh profile
- **AND** it checks `ok`, returned `name`, and the server's mirroring outcomes before storing the `hermes-bots` presentation block

#### Scenario: Older server

- **WHEN** methods or metadata revision support are missing
- **THEN** the app explains that this server needs a Bot Mode compatible update, leaves ordinary Chat and Messaging usable, and sends no speculative write to detect support
