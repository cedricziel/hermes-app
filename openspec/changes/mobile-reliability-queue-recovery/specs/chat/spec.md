## MODIFIED Requirements

### Requirement: Queued messages

The system SHALL hold the messages queued on a thread, text and attachments, in the order they were sent, and SHALL show those of the open thread above the composer, each with a control to remove it. While the thread's reply is pending the composer's hint SHALL read "Queue a message…". When a reply ends normally, whether it answered a prompt or was a turn Hermes started on its own, and no reply is pending, the system SHALL send the first queued message as a new turn and remove it from the queue, once the gateway reports the session settled (`session.info` with `running` false) or 2 seconds after the completion when no such report comes. A queued message SHALL be submitted with `queued: true`. When a reply is stopped by the user or fails, the queue SHALL pause: nothing more is sent on its own, and the queue SHALL offer "Send now", which sends its first message. A message sent on a thread whose queue is paused SHALL join the end of the queue, and the first queued message SHALL be sent. An attachment that cannot be sent SHALL be refused when the message is queued, as for a direct send. The queue SHALL be committed to protected local storage before the composer is cleared and SHALL survive restart and profile reload under the same server, account, profile, and conversation identity. Restored queues SHALL remain paused until explicitly reviewed and sent by the user. Their restored state SHALL override automatic draining, settle timers, and the rule that a new prompt on a paused live queue sends its first entry. New prompts added to a restored queue SHALL remain paused. Switching away from a profile SHALL pause its local queue until the user returns and reviews it. A queue commit failure SHALL keep the composer content and SHALL report that the prompt was not queued. The queue SHALL NOT use any backend route or RPC method beyond those of a direct send (`session.resume`, `prompt.submit`).

#### Scenario: Queued message shown

- **WHEN** the user sends "next" while the reply is streaming
- **THEN** "next" is listed above the composer and is not in the transcript yet

#### Scenario: Sent when the reply completes

- **WHEN** two messages are queued during the current app visit and the reply completes
- **THEN** the first queued message is sent and moves into the transcript with a thinking placeholder
- **AND** the second stays queued until that reply completes, and is then sent

#### Scenario: Sent only once the session settled

- **WHEN** a message is queued during the current app visit and the reply completes
- **THEN** nothing is submitted until the gateway reports the session not running, or 2 seconds have passed
- **AND** the message is then submitted with `queued` set to true

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
- **AND WHEN** a stop of that reply is still unanswered and the gateway then answers that nothing was running
- **THEN** the queue stays paused

#### Scenario: A stop that finds nothing running

- **WHEN** a message is queued, the user stops the reply, and the turn ends on its own before the stop is answered
- **AND** the gateway answers that nothing was running
- **THEN** the queued message is sent as after a normal settle
- **AND WHEN** an earlier stop of the same reply was confirmed, or the reply failed
- **THEN** the queue stays paused

#### Scenario: Send on a paused queue

- **WHEN** a live queue paused by a stop or failure has "first" queued
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

#### Scenario: Restart requires review

- **WHEN** the app restarts with locally unsent records for the selected conversation
- **THEN** their text and retained attachments appear in FIFO order with a review-required state
- **AND** completion or settle events do not send them

#### Scenario: New prompt on restored queue

- **WHEN** the user adds another prompt to a restored queue
- **THEN** it joins the end without sending any restored entry

#### Scenario: Profile reload

- **WHEN** a profile reload replaces conversation objects
- **THEN** recovered records bind to their original conversation identities and remain paused

#### Scenario: Commit failure preserves input

- **WHEN** a queue write fails before commitment
- **THEN** the composer retains its text and attachments and reports that queueing failed

#### Scenario: Review and send

- **WHEN** the user explicitly sends a reviewed unsent entry while its original session is available
- **THEN** only the first eligible entry is submitted using the existing send protocol
- **AND** the rest of the restored queue still waits for explicit sending

#### Scenario: Missing or deleted conversation

- **WHEN** the original conversation is unavailable or a profile no longer exists
- **THEN** its recovered queue is not rebound to a new conversation and is not submitted

#### Scenario: App Lock

- **WHEN** App Lock is active
- **THEN** recovered prompt text and attachments remain hidden until the app is unlocked

## ADDED Requirements

### Requirement: Durable queued submission ownership

Before submitting a durable entry, the app SHALL commit submission-started state. If submission never starts, it SHALL remain unsent. If the result is unknown after restart or connection interruption, it SHALL show an unknown submission outcome and SHALL NOT retry automatically or enable the ordinary unsent-entry send control. The user SHALL be able to inspect current conversation history and discard the local uncertain record. Sending the same content again SHALL require an explicit new prompt and warn that the earlier attempt may already have reached Hermes. Text matching SHALL NOT be used as proof of backend acceptance.

A successful `prompt.submit` result with status `streaming`, `queued`, `redirected`, or `steered` SHALL transfer ownership to Hermes and remove the entry from the locally unsent queue. A record whose local acceptance write was interrupted SHALL remain uncertain even if the backend may have accepted it. No backend idempotency guarantee SHALL be assumed. A durable queued dispatch SHALL append its user transcript row only after known positive status acceptance. The optional canonical user-row receipt SHALL remain a separate proof and SHALL NOT replace the status acceptance boundary.

#### Scenario: Unknown submit status

- **WHEN** the submit response has a missing, empty, malformed or unknown status
- **THEN** local ownership remains uncertain, even if a canonical user row receipt or reply completion arrives
- **AND** no automatic resend occurs

#### Scenario: Credential expiry retains local work

- **WHEN** the server rejects the refresh token
- **THEN** encrypted queued records remain stored but queue access, visible DTOs and auxiliary leases are revoked
- **AND WHEN** the same owner is verified again
- **THEN** their queue reloads paused without an automatic submission

#### Scenario: Explicit sign-out after expiry

- **WHEN** the user explicitly signs out after credentials expired
- **THEN** the remembered owner scope is deleted
- **AND** records belonging to another account remain intact

#### Scenario: Profile cannot be resolved

- **WHEN** the server cannot provide a nonempty selected or active profile
- **THEN** ordinary immediate sends keep their existing behavior
- **AND** durable enqueue and replay are refused without clearing the draft or rebinding stored records

#### Scenario: Active profile changes after resolution

- **WHEN** a default profile was resolved before durable dispatch
- **AND** the backend later selects another active profile
- **THEN** the dispatch still names its original resolved profile explicitly

#### Scenario: Lost submit answer

- **WHEN** submission starts and the app loses the connection before acceptance can be established
- **THEN** the entry is shown as uncertain and no automatic resend occurs

#### Scenario: Server queues a prompt

- **WHEN** `prompt.submit` answers with status `queued`
- **THEN** the app removes the entry from its local unsent queue and follows the existing server-turn behavior

#### Scenario: User discards uncertain entry

- **WHEN** the user discards an uncertain local entry
- **THEN** its local payload is deleted without interrupting or removing any backend turn

### Requirement: Queue recovery backend contract

Recovery SHALL use existing `session.resume` and `prompt.submit` over `/api/ws`, including `session_id`, `text`, and `queued: true` for a queued send. Existing `session.info` running state and the existing settle fallback SHALL continue to govern live queues, but SHALL NOT release restored queues. Existing conversation-history reads SHALL remain informational for uncertain submissions. The contract baseline is bundled Hermes revision `167e9fdb84248cd0fff80762dc57b6a914b6e930`. No new API, RPC field, or minimum Hermes version SHALL be required.

#### Scenario: Backend lacks queue recovery extension

- **WHEN** the existing supported gateway provides its current session and submit contracts
- **THEN** reviewed queue recovery works without an additional backend capability
