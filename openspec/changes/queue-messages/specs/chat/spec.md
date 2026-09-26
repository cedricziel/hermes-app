## REMOVED Requirements

### Requirement: Sending a message

**Reason**: Replaced by "Sending a message and queueing", which queues a send on a thread with a pending reply instead of refusing it.

**Migration**: None; the queue takes the refused sends.

## ADDED Requirements

### Requirement: Sending a message and queueing

The system SHALL append the user's message and a thinking placeholder for the assistant reply to the transcript at once when the user sends, and SHALL clear the composer. Blank text with no attachments SHALL NOT be sent. On a thread that has a pending reply, meaning a reply that is thinking or streaming, including one that waits for the user to answer an approval or clarify request, the system SHALL queue the message instead of sending it (see "Queued messages"). Other threads SHALL NOT be affected.

#### Scenario: Send shows prompt and placeholder

- **WHEN** the user sends "hello"
- **THEN** the transcript shows "hello" and a thinking placeholder, and the composer is emptied

#### Scenario: Enter sends

- **WHEN** the user presses Enter in the composer
- **THEN** the message is sent
- **AND WHEN** the user presses Shift+Enter
- **THEN** a line break is added and nothing is sent

#### Scenario: Whitespace-only message

- **WHEN** the composer holds only whitespace and there are no attachments
- **THEN** nothing is sent

#### Scenario: Send button state

- **WHEN** the composer is empty and there are no attachments
- **THEN** the send button is disabled
- **AND WHEN** there are attachments, even with no text
- **THEN** it is enabled

#### Scenario: Overlapping sends

- **WHEN** the user sends in several threads while an earlier reply in another thread is still streaming
- **THEN** every reply streams into its own place beside its own prompt

#### Scenario: Queued while the reply streams

- **WHEN** the user sends again in a thread whose reply is still streaming
- **THEN** nothing is sent yet, the message is queued and the composer is emptied

#### Scenario: Queued while a request is pending

- **WHEN** the reply waits on an approval or clarify request that is not answered yet
- **AND WHEN** the user sends again in that thread
- **THEN** nothing is sent yet and the message is queued

#### Scenario: Allowed after completion

- **WHEN** the reply in a thread has completed
- **AND WHEN** the user sends again in that thread
- **THEN** the message is sent

#### Scenario: Allowed after a broken stream

- **WHEN** the reply stream of a thread broke and the reply is marked failed
- **AND WHEN** the user sends again in that thread with nothing queued
- **THEN** the message is sent

#### Scenario: Other thread unaffected

- **WHEN** a thread has a pending reply
- **AND WHEN** the user switches to another thread and sends
- **THEN** the message is sent under that other thread

### Requirement: Queued messages

The system SHALL hold the messages queued on a thread, text and attachments, in the order they were sent, and SHALL show those of the open thread above the composer, each with a control to remove it. While the thread's reply is pending the composer's hint SHALL read "Queue a message…". When a reply ends normally, whether it answered a prompt or was a turn Hermes started on its own, and no reply is pending, the system SHALL send the first queued message as a new turn and remove it from the queue. When a reply is stopped by the user or fails, the queue SHALL pause: nothing more is sent on its own, and the queue SHALL offer "Send now", which sends its first message. A message sent on a thread whose queue is paused SHALL join the end of the queue, and the first queued message SHALL be sent. An attachment that cannot be sent SHALL be refused when the message is queued, as for a direct send. The queue SHALL be held in memory only, and SHALL be dropped when the threads are loaded again, for example on a profile switch. The queue SHALL NOT use any backend route or RPC method beyond those of a direct send (`session.resume`, `prompt.submit`).

#### Scenario: Queued message shown

- **WHEN** the user sends "next" while the reply is streaming
- **THEN** "next" is listed above the composer and is not in the transcript yet

#### Scenario: Sent when the reply completes

- **WHEN** two messages are queued and the reply completes
- **THEN** the first queued message is sent and moves into the transcript with a thinking placeholder
- **AND** the second stays queued until that reply completes, and is then sent

#### Scenario: Waits for a turn Hermes starts

- **WHEN** a message is queued and Hermes starts a turn of its own after the reply completes
- **THEN** the message is sent once that turn completes

#### Scenario: Paused by stop

- **WHEN** a message is queued and the user stops the reply
- **THEN** the message is not sent and the queue offers "Send now"
- **AND WHEN** the user taps "Send now"
- **THEN** the message is sent

#### Scenario: Paused by a failure

- **WHEN** a message is queued and the reply fails
- **THEN** the message is not sent and the queue offers "Send now"

#### Scenario: Send on a paused queue

- **WHEN** the queue is paused with "first" queued
- **AND WHEN** the user sends "second"
- **THEN** "first" is sent and "second" stays queued

#### Scenario: Removed from the queue

- **WHEN** the user removes a queued message
- **THEN** it is no longer listed and is never sent

#### Scenario: Queue belongs to its thread

- **WHEN** a thread has queued messages and the user opens another thread
- **THEN** the other thread shows no queue, and the first thread's queue is sent there when its reply completes
