## Purpose

Let users return to each specialist's canonical conversation and use Hermes' attributed messaging between bots on the connected server.

## ADDED Requirements

### Requirement: Canonical conversation identity

The system SHALL resolve a bot conversation by owner profile and the exact server title `Bot Chat`, preserving that title while displaying the bot's friendly name to the user.

#### Scenario: Existing conversation and compression

- **WHEN** the user opens a bot
- **THEN** the app opens its canonical registry row's `resolved_id` when present, otherwise its `id`, under the same profile
- **AND** the row preview refers to that same conversation rather than its latest ordinary session

#### Scenario: Confirmed absence and competing creators

- **WHEN** a successful exact lookup confirms no canonical conversation and the roster does not identify one
- **THEN** the app creates one canonical conversation and materializes its exact title before loading history
- **AND** concurrent creation is serialized for this owner; a title conflict causes re-lookup and adoption of the winner before any prompt is sent

#### Scenario: Uncertain absence

- **WHEN** lookup fails or returns empty while a canonical roster pointer still exists
- **THEN** the app shows a recoverable failure and creates no replacement conversation

### Requirement: Bot conversation lifecycle

The system SHALL preserve profile ownership throughout opening, sending, background replies, and reconnecting, without changing the user's CLI default profile.

#### Scenario: Reconnect or another bot is selected

- **WHEN** the socket is replaced or an older request completes after another bot was selected
- **THEN** resumes retain the stored session's owner profile and late results cannot replace the selected bot's conversation

#### Scenario: Fresh context and retirement

- **WHEN** `/new` or `/reset` is submitted in a canonical bot conversation
- **THEN** the app compacts it while preserving canonical identity
- **AND** New Chat opens an ordinary session; canonical title editing is unavailable; explicit archive explains retirement and the next bot open creates a fresh canonical conversation after confirmed absence

### Requirement: Local bot messaging

The system SHALL offer @mention suggestions for unambiguous bots on the connected server and rely on Hermes' injected `message_agent` protocol for delivery and attribution.

#### Scenario: Mention and eventual reply

- **WHEN** the user sends a message addressing a teammate in a canonical Bot Chat
- **THEN** the app preserves the user message and provides an unambiguous roster handle, and the server agent decides and sends its teammate message
- **AND** eventual attributed replies and failures are rendered from server transcript/events; a queued receipt is not labeled as completed delivery

#### Scenario: Ambiguous, unknown, or disabled messaging

- **WHEN** a friendly name is ambiguous, an @token is unknown, or `bot_mode_protocol` is false
- **THEN** the app does not guess a target, leaves ordinary text and email addresses intact, and explains disabled teammate messaging where applicable
- **AND** it never automatically resends an ambiguous handoff or appends its own protocol to SOUL

### Requirement: Canonical chat backend contract

The system SHALL require the following authenticated `/api/ws` contracts, verified against Hermes 0.21.4 source commit `35fdb4608aa8af455d2597664cff1754a3722cd1`. Earlier release compatibility SHALL be capability tested rather than inferred from a version string.

#### Scenario: Canonical lookup and creation

- **WHEN** resolving a canonical conversation
- **THEN** `session.list` receives `profile`, `title: "Bot Chat"`, `include_hidden: true`, and `limit: 200`, returning `sessions` with `id`, optional `resolved_id`, and `title`
- **AND** only after confirmed absence `session.create` receives `profile`, `title: "Bot Chat"`, `hidden: true`, `follow_profile_config: true`, returning runtime `session_id` and `stored_session_id`; `session.title` then receives runtime `session_id` and exact title
- **AND** a still-pending title result is not treated as a persisted registry row

#### Scenario: Resume and messaging prerequisites

- **WHEN** opening or sending into a Bot Chat
- **THEN** `session.resume` uses the stored ID with owner `profile`, and `prompt.submit` uses the runtime ID
- **AND** the install carries the `hermes-bots` metadata object, the session title is exact, and `profiles.list.bot_mode_protocol` indicates backend protocol support for local `message_agent` injection
- **AND** existing REST history and archive/pin operations name that same owner profile
