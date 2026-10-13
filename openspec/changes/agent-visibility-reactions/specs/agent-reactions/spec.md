## Purpose

Defines read-only agent reactions in the Hermes app so users can inspect backend-reported activity without changing the agent protocol.

## ADDED Requirements

### Requirement: Durable reactions attach only by message identity

The app SHALL retain only a positive canonical integer transcript row_id with an explicit user or assistant role and match message.reaction by both row_id and role within the owning physical connection, confirmed runtime, profile, and stored-session lineage. The app SHALL NOT infer canonical identity from id, _row_id, text, position, or a role hint. A live user message SHALL receive canonical identity only from the verified prompt.submit user_row_id receipt for its exact captured submitted message under the current protected owner. Watch and unsolicited receipts SHALL NOT assign identity to another message. It SHALL show the supplied emoji and author in a read-only badge or details view, with empty reactions removing prior badges for that row. Messages without a matching durable ID SHALL not receive a guessed reaction. At most 128 pending unmatched rows SHALL be retained and reconciled when canonical matching history arrives. Physical connection loss, runtime replacement, profile replacement, reclaim, and protected activity retirement SHALL clear live and pending state; getter access SHALL reject an old scope even during earlier ownership notifications. Verified compression that preserves the owning runtime SHALL retain inherited row lineage.

#### Scenario: A reaction arrives before its transcript row

- **WHEN** history later loads the matching row_id
- **THEN** the reaction attaches only to that row

### Requirement: Identity-free reactions stay separate

For the fixture-verified reaction.kind=vibe, the app SHALL show a neutral in-app session acknowledgement using only supported kinds verified in a backend fixture. Unknown kinds SHALL be ignored safely. Since this payload has no row_id, the app SHALL not attach it to the latest user message or display an inferred emoji.

#### Scenario: An identity-free reaction arrives after multiple user messages

- **WHEN** reaction contains only kind
- **THEN** no individual message receives a guessed badge

### Requirement: Replay preserves reported reactions

The app SHALL deduplicate replayed reaction events using existing event sequence handling. A full message.reaction snapshot SHALL replace the badge list for its row rather than append duplicates. Cold start SHALL restore only reactions present under display_metadata.reactions, accepting a map or JSON-encoded map, when the same supplied row contains canonical row_id and role, or from later owned events; absence of a documented persisted reaction field SHALL not trigger an invented API call.

#### Scenario: The same reaction snapshot is replayed

- **WHEN** the row already shows its reactions
- **THEN** one copy of each reported reaction remains

### Requirement: Existing backend contract and compatibility

The app SHALL use the existing dashboard `/api/ws` JSON-RPC contract for message.reaction, reaction; session.history transcript row_id. The current pinned contract SHALL be Hermes Agent commit `71d34bad1045610252eda02ee79549436896e784`, recorded in `openrpc/HERMES_REF`. Retained reaction payload and supported-kind fixtures SHALL record their tested baseline `167e9fdb84248cd0fff80762dc57b6a914b6e930`; a minimum semantic release containing every required field is not established. Older backends SHALL keep ordinary chat usable when these optional events or methods are absent. Unsupported actions SHALL be unavailable, and malformed optional payloads SHALL not break the event stream. No backend route, protocol extension, or token-storage change SHALL be required.

`session.history` provides canonical transcript rows with optional integer `row_id`. The app uses its existing transcript parser and reads; it does not introduce a history route or call. The retained `167e9fdb84248cd0fff80762dc57b6a914b6e930` REST baseline projection returns database `id` without canonical `row_id`, so those REST rows cannot restore or receive a reaction badge. Optional canonical `row_id` supplied by compatible transcript data remains supported. MessageReaction entries require `emoji` and `author`, and optionally contain `at` and `seen`. The retained fixture baseline store persists reactions in display_metadata.reactions; the app reads only that verified field and sends no reaction mutations.

The event shapes are:

- `message.reaction`: `MessageReactionPayload`, required `row_id`, `reactions`, `role`.
- `reaction`: `ReactionPayload`, required `kind`.

#### Scenario: Optional capability is absent

- **WHEN** an older backend omits this capability or refuses an optional method as unsupported
- **THEN** ordinary chat remains usable and the app reports unavailable functionality without inventing state or submitting speculative requests


### Requirement: Reaction content stays out of telemetry

The app SHALL report reaction visibility and details actions with fixed feature, outcome, action, and optional count values only. Emoji, author, canonical row identity, runtime identity, profile names, and timestamps SHALL NOT be added to these events. Telemetry failures SHALL NOT break chat or reaction handling.

#### Scenario: The event logger fails

- **WHEN** a matched reaction arrives and its event logger throws
- **THEN** the reported badge remains inspectable and normal chat continues
