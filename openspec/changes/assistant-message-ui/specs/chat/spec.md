## MODIFIED Requirements

### Requirement: Rendering of messages

The system SHALL render a message as its reasoning first, then tool call cards, then agent input request cards, then the text, then a thinking indicator, and SHALL render message text as markdown.

#### Scenario: Thinking indicator

- **WHEN** an assistant reply is pending with no text yet, no reasoning yet and no input request is waiting
- **THEN** a thinking indicator (three pulsing dots) is shown in place of text

#### Scenario: No indicator while the agent waits for the user

- **WHEN** a reply is still thinking and one of its input requests is pending
- **THEN** the thinking indicator is hidden

#### Scenario: No indicator once reasoning shows

- **WHEN** a reply is still thinking and has reasoning
- **THEN** the thinking indicator is hidden and the reasoning block is shown

#### Scenario: Failed reply

- **WHEN** a reply ended in error and has text
- **THEN** its text is drawn in the error colour

#### Scenario: Empty thread

- **WHEN** the open thread has no messages, or no thread is selected
- **THEN** the welcome view shows "Where should we begin?" (with the user's display name appended when known) and four starter prompts, and tapping a prompt sends it as a message

#### Scenario: Responsive layout

- **WHEN** the available width is at least 900 logical pixels
- **THEN** the thread rail is permanently shown beside the transcript, with the thread title above it
- **AND WHEN** the width is smaller
- **THEN** the rail opens as a drawer and the thread title is shown in the app bar

## ADDED Requirements

### Requirement: Reasoning

The system SHALL show the model's reasoning, when there is any, as a block above the rest of the reply that is folded by default and opens and closes when tapped. The block SHALL read "Thinking…" while the reply is pending and "Reasoning" once it has ended. A reply without reasoning SHALL have no block.

#### Scenario: Reasoning streams in

- **WHEN** the gateway sends `reasoning.delta` events for the running turn
- **THEN** their `text` is appended to the reply's reasoning in order
- **AND WHEN** it sends `reasoning.available`
- **THEN** its `text` replaces the reasoning

#### Scenario: Reasoning does not end the wait

- **WHEN** reasoning arrives and no reply text has
- **THEN** the reply is still pending, and no reply text is shown

#### Scenario: Loaded thread

- **WHEN** a session message row carries a `reasoning` string
- **THEN** that message shows it in a reasoning block, and a `reasoning` that is not a string is read as none

#### Scenario: Spinner text is not reasoning

- **WHEN** the gateway sends `thinking.delta`
- **THEN** nothing is shown for it

### Requirement: Reply actions

The system SHALL show an action bar below the text of a finished assistant reply, and none below a reply that is still being written or below a message of the user. The bar SHALL offer Copy, which puts the reply's text on the clipboard and shows a tick in place of its icon for two seconds, and, on the latest reply of the open thread only, Try again, which sends the text of the thread's last prompt again as a new turn, without its files, and is not offered when that prompt had no text. A failed reply SHALL offer Try again but not Copy. Try again SHALL NOT be offered while a reply is being written, and SHALL NOT touch the composer or its attachments.

#### Scenario: Copy

- **WHEN** the user taps Copy under a reply
- **THEN** the reply's text is on the clipboard and the icon shows a tick until two seconds have passed

#### Scenario: Try again

- **WHEN** the user taps Try again under the latest reply
- **THEN** the text of the thread's last prompt is sent again to the same thread without its files, and what the user had typed and attached in the composer is kept

#### Scenario: Only the latest reply

- **WHEN** a newer reply has finished in the thread
- **THEN** the earlier replies offer Copy only

#### Scenario: Still being written

- **WHEN** a reply is streaming
- **THEN** no action bar is shown under it, and no reply offers Try again

#### Scenario: Failed reply

- **WHEN** a reply ended in error
- **THEN** it offers Try again and no Copy

### Requirement: Follow-up chips

The system SHALL show three chips below the action bar of the latest reply of the open thread, reading "Explain in more detail", "Give an example" and "Summarize this", and SHALL send the chip's text as a prompt in that thread when the user taps one. The chips SHALL NOT be shown under an earlier reply, under a reply that is still being written or under a failed reply, and SHALL NOT change with the reply.

#### Scenario: Tapping a chip

- **WHEN** the user taps "Give an example"
- **THEN** "Give an example" is sent as a new turn in the open thread

#### Scenario: Only the latest reply

- **WHEN** a newer reply finishes, or the latest one failed
- **THEN** the earlier reply shows no chips
