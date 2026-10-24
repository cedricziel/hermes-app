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

### Requirement: What the background review saved

After a turn ends, Hermes may read the reply back and save memories, the user profile or skills, and it reports what it saved with `review.summary`. The system SHALL show that report under the latest finished reply of the thread, never under a reply still being written, as a muted row with a memory icon and the changes joined by " · ". It SHALL leave out the leading glyph and the label before the first ": ", and SHALL show nothing for a report with no changes. When the chat's profile is known and the chat has a dashboard connection, the row SHALL end with a "Memory" link that opens the Memory screen for that profile. The row is not stored in the history, so it is gone after the thread is read again.

#### Scenario: A memory is saved after the reply

- **WHEN** a reply completed and `review.summary` arrives with "💾 Self-improvement review: Memory updated · Skill 'x' patched"
- **THEN** a row under that reply reads "Memory updated · Skill 'x' patched"

#### Scenario: The next turn is already running

- **WHEN** `review.summary` arrives while the next reply of the thread is streaming
- **THEN** the row goes under the reply before it, which the review read

#### Scenario: Opening memory from the note

- **WHEN** the user taps "Memory" in the row of a chat in profile "work"
- **THEN** the Memory screen opens on "work"
