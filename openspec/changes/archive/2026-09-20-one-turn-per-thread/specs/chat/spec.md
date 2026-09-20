## MODIFIED Requirements

### Requirement: Sending a message

The system SHALL append the user's message and a thinking placeholder for the assistant reply to the transcript at once when the user sends, and SHALL clear the composer. Blank text with no attachments SHALL NOT be sent. The system SHALL NOT send on a thread that has a pending reply, meaning a reply that is thinking or streaming, including one that waits for the user to answer an approval or clarify request. It SHALL tell the user why with the message "Hermes is still replying. Wait for it to finish, or answer its request." and SHALL keep the composer text and attachments. Other threads SHALL NOT be affected.

#### Scenario: Send shows prompt and placeholder

- **WHEN** the user sends "hello"
- **THEN** the transcript shows "hello" and a thinking placeholder, and the composer is emptied

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

#### Scenario: Blocked while the reply streams

- **WHEN** the user sends again in a thread whose reply is still streaming
- **THEN** nothing is sent and the user is told "Hermes is still replying. Wait for it to finish, or answer its request."
- **AND** the composer keeps its text

#### Scenario: Blocked while a request is pending

- **WHEN** the reply waits on an approval or clarify request that is not answered yet
- **AND WHEN** the user sends again in that thread
- **THEN** nothing is sent and the user is told "Hermes is still replying. Wait for it to finish, or answer its request."

#### Scenario: Allowed after completion

- **WHEN** the reply in a thread has completed
- **AND WHEN** the user sends again in that thread
- **THEN** the message is sent

#### Scenario: Allowed after a broken stream

- **WHEN** the reply stream of a thread broke and the reply is marked failed
- **AND WHEN** the user sends again in that thread
- **THEN** the message is sent

#### Scenario: Other thread unaffected

- **WHEN** a thread has a pending reply
- **AND WHEN** the user switches to another thread and sends
- **THEN** the message is sent under that other thread
