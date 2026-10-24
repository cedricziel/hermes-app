## MODIFIED Requirements

### Requirement: Tool call cards

The system SHALL show each tool the agent runs as a card in the reply with the tool name, a summary, and a status of running, completed or failed. A `memory` call whose result says the memory is full (see the memory-tool-calls spec) SHALL show a warning status instead of failed, since nothing went wrong and the agent usually retries.

#### Scenario: Tool runs and completes

- **WHEN** a tool starts
- **THEN** a running card with the tool's name and context summary appears
- **AND WHEN** that tool finishes
- **THEN** the card shows completed

#### Scenario: Tool fails

- **WHEN** a tool finishes and its result carries a non-empty `error`
- **THEN** its card shows failed

#### Scenario: Memory is full

- **WHEN** the `memory` tool finishes with `success: false`, an `error` starting "Memory at " and a `usage` of the form "X/Y"
- **THEN** its card shows a warning status, not failed

#### Scenario: Matching by name

- **WHEN** a tool finishes
- **THEN** the first still-running card with that name is settled and other cards are untouched
- **AND WHEN** no running card has that name
- **THEN** nothing changes

#### Scenario: Tools that never report back

- **WHEN** the reply completes, or the stream breaks, while a tool is still running
- **THEN** that card is settled, as completed after a successful reply and as failed after a failed reply or a broken stream

## ADDED Requirements

### Requirement: Opening Memory from the background review

The "Memory & review" card of the Activity panel lists what the latest background review saved. When the chat's profile is known and the chat has a dashboard connection, that section SHALL end with a "Memory" link that opens the Memory screen for that profile. The earlier "row under the reply" no longer exists: review notes live in the Activity panel.

#### Scenario: Opening memory from the review

- **WHEN** the user taps "Memory" under the review notes of a chat in profile "work"
- **THEN** the Memory screen opens on "work"
