## MODIFIED Requirements

### Requirement: Stopping a reply

The system SHALL, while a reply is in flight in the open thread, show a bar above the composer saying "Hermes is replying…" with a "Stop" button, and SHALL ask the gateway to interrupt that thread's running turn when the user taps it. The reply SHALL end as a completed reply that keeps what had streamed, or reads "Stopped." when nothing had, and SHALL NOT be shown as failed. A stopped reply that kept streamed text SHALL be marked "Stopped" under it, so it does not read as a finished answer. The bar SHALL NOT be shown when no reply is in flight, and sending SHALL work again once the reply has ended.

#### Scenario: Stop while replying

- **WHEN** a reply is in flight in the open thread and the user taps "Stop"
- **THEN** the running turn of that thread is interrupted and the button is disabled while the request is in flight

#### Scenario: The reply ends as stopped

- **WHEN** the gateway completes the turn with the status `interrupted`
- **THEN** the reply keeps its streamed text, or reads "Stopped." when it had none, and the bar disappears

#### Scenario: A stopped reply with text is marked

- **WHEN** the user stops a reply after some text had streamed
- **THEN** the reply keeps that text and shows "Stopped" under it
- **AND WHEN** a reply completes without being stopped
- **THEN** no such mark is shown

#### Scenario: Sending again

- **WHEN** a reply was stopped and the user sends another prompt in that thread
- **THEN** the prompt is sent

#### Scenario: Nothing is replying

- **WHEN** no reply is in flight in the open thread
- **THEN** no bar and no "Stop" button are shown

#### Scenario: Nothing is running any more

- **WHEN** the gateway reports that no turn was running
- **THEN** nothing changes and no error is shown

#### Scenario: Stop fails

- **WHEN** sending the interrupt fails
- **THEN** "Could not stop the reply. Try again." is shown and "Stop" stays available

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

- **WHEN** Hermes runs a turn of its own after a reply, such as a goal continuation
- **AND WHEN** the user sends in that thread during it
- **THEN** the message is queued and sent once that turn completes

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

#### Scenario: A sent queued message comes into view

- **WHEN** the user is at the bottom of the thread and a queued message is sent after a long reply
- **THEN** the transcript shows the new message and follows its reply
