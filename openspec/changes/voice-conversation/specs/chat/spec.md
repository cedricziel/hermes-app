# Spec Delta

## MODIFIED Requirements

### Requirement: Backend contract

The system SHALL use the following dashboard routes, JSON-RPC methods and events for chat, and SHALL parse session rows leniently, skipping rows that do not fit. The minimum Hermes is the ref pinned for the contract test (`7b3c7aef`); behaviour that needs a newer Hermes SHALL degrade to the pinned behaviour.

#### Scenario: REST routes

- **WHEN** the chat reads or changes threads
- **THEN** it uses `GET /api/sessions` (`limit`, `offset`, `order=recent`, `archived=exclude`, `profile`; response `sessions` and optionally `total`), `GET /api/sessions/{id}/messages` (`profile`, `limit`, `offset`, `order`; response `messages`), `PATCH /api/sessions/{id}` (body with `title`, `pinned` or `archived`, and `profile`) and `DELETE /api/sessions/{id}` (`profile`)
- **AND** it uses `GET /api/profiles/active` to learn which profile to list, `POST /api/auth/ws-ticket` (response `ticket`) and `GET /` (the `__HERMES_SESSION_TOKEN__` value) to obtain socket credentials

#### Scenario: Row fields

- **WHEN** a session row is parsed
- **THEN** `id`, `title`, `preview`, `last_active`, `started_at` and `pinned` are read
- **AND** a message row's `id`, `role`, `content`, `timestamp` and `tool_calls` are read, and a loaded message's id is `<session id>-<row id>`

#### Scenario: JSON-RPC methods

- **WHEN** the chat talks over `/api/ws`
- **THEN** it requests `session.create` (optional `profile`), `session.resume` (`session_id`, optional `profile`; the result's `session_id`, `running`, `inflight.assistant`, `open_requests` and `messages` are read), `prompt.submit` (`session_id`, `text`, optional `queued`, `voice_turn` and `interrupted` on spoken turns; the result's `status` is read, and a `voice_stopped` answer without a `status` means the prompt was consumed), `session.events.since` (`session_id`, `last_seen`; result `events`, `latest_seq`, `truncated`, `epoch`, `open_requests`), `session.active_list`, `gateway.ping` (any answer counts), `approval.respond` (`session_id`, `request_id`, `choice`; a `resolved` result above zero means accepted) and `clarify.respond` (`request_id`, `answer`, optional `question_id`; a `status` of `expired` means not accepted), `client.capabilities` (`server_requests`) and `clarify.lock` (`request_id`, `question_id`, `answer`; a `status` of `expired` means not accepted) and `session.interrupt` (`session_id`; a `status` of `interrupted` means a running turn was stopped), as JSON-RPC 2.0 with integer ids
- **AND** the gateway binds a session to the profile it was created or resumed under, so `prompt.submit` and the answer calls carry no profile
- **AND** it answers a secret or a sudo request only to skip it: `sudo.respond` (`request_id`, `password` empty) or `secret.respond` (`request_id`, `value` empty), where a `status` of `expired` means not accepted

#### Scenario: Unknown profile

- **WHEN** `session.create` or `session.resume` carries a `profile` that names no profile on the host
- **THEN** a Hermes newer than the ref pinned for the contract test answers with the JSON-RPC error 4064 and a message naming the profile; the system treats that code as "the selected profile no longer exists" and reads nothing else from the error
- **AND** an older Hermes may drop the socket instead, which the system treats as any other socket drop

#### Scenario: Server-to-client requests

- **WHEN** the gateway sends a JSON-RPC request with a string id and a `method`
- **THEN** `approval` (`session_id`, `command`, `description`, `choices`) shows an approval card, and `clarify` (`session_id` with either `question`, `choices`, `multi_select` or a `questions` list of `qid`, `question`, `choices`, `multi_select`) shows a clarify card, both keyed by the request's `id`
- **AND** `secret` and `sudo` show the card for requests the app cannot answer, reading nothing but the `id` and the session
- **AND** any other method is answered at once with the JSON-RPC error -32601 "method not found" when its `session_id` is a runtime session this app has a reply in flight for
- **AND** an unhandled request for any other session is neither shown nor answered, because another client attached to that session may answer it, and the first response settles it for all of them
- **AND** a request whose `session_id` is not the reply's runtime session is left alone

#### Scenario: Answering a server-to-client request

- **WHEN** the user answers an approval
- **THEN** a response frame `{id, result: {choice}}` is sent with the request's id, on whichever connection is open; the gateway matches answers by id, not by connection
- **AND WHEN** the user answers a single clarify question
- **THEN** a response frame `{id, result: {answer}}` is sent, the answer being the JSON-encoded list for a multi-select question
- **AND WHEN** the user answers one question of a batch
- **THEN** `clarify.lock` is requested with the request's id as `request_id`, and its result decides whether the answer was accepted
- **AND WHEN** the user skips a `secret` or `sudo` request
- **THEN** a response frame `{id, result: {value: ''}}` is sent with the request's id
- **AND WHEN** the user skips a whole batch
- **THEN** a response frame with an empty result is sent with the request's id, and `clarify.lock` is not requested

#### Scenario: Events

- **WHEN** the gateway pushes an `event` notification
- **THEN** its `type` is mapped as follows: `message.start` (reply started), `message.delta` (`text`), `message.interim` (`text`, `already_streamed`), `tool.start` (`name`, `context`), `tool.complete` (`name`, `result.error`), `session.title` (`title`), `message.complete` (`text`, `status`, `error`, `partial`, `response_previewed`, `response_reused`, `response_transformed`; status `error` marks a failed reply and `interrupted` a stopped one), `error` (`message`), `session.info` (`running`, `stored_session_id`), `status.update` (`kind`, `text`), `approval.request` (`request_id`, `command`, `description`, `choices`), `clarify.request` (`request_id` with either `question`, `choices`, `multi_select` or a `questions` list of `qid`, `question`, `choices`, `multi_select`), `secret.request` and `sudo.request` (`request_id` only; the prompt, variable name and metadata are not read), `approval.expire`, `clarify.expire`, `secret.expire` or `sudo.expire` (`request_id`), `request.cancel` (`id`, the id of a server-to-client request), and the session-less broadcast `approval.cancelled` (`payload.session_id`, `payload.request_ids`)
- **AND** the event's `seq` (in `params`, rising per runtime session) is read when present
- **AND** `thinking.delta` (`text`) is read only for the status line, and other event types are ignored

#### Scenario: Socket closes

- **WHEN** the socket closes
- **THEN** all pending requests fail with a "connection closed" error, later requests fail at once, and frames that are not JSON-RPC are ignored

### Requirement: Sending a message and queueing

The system SHALL append the user's message and a thinking placeholder for the assistant reply to the transcript at once when the user sends, and SHALL clear the composer. Blank text with no attachments SHALL NOT be sent. On a thread that has a pending reply, meaning a reply that is thinking or streaming, including one that waits for the user to answer an approval or clarify request, the system SHALL queue the message instead of sending it (see "Queued messages"), except that a voice turn from a call SHALL NOT be queued (see "Voice turns"). Other threads SHALL NOT be affected.

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

The system SHALL hold the messages queued on a thread, text and attachments, in the order they were sent, and SHALL show those of the open thread above the composer, each with a control to remove it. While the thread's reply is pending the composer's hint SHALL read "Queue a message…". When a reply ends normally, whether it answered a prompt or was a turn Hermes started on its own, and no reply is pending, the system SHALL send the first queued message as a new turn and remove it from the queue, once the gateway reports the session settled (`session.info` with `running` false) or 2 seconds after the completion when no such report comes. A queued message SHALL be submitted with `queued: true`. When a reply is stopped by the user or fails, the queue SHALL pause: nothing more is sent on its own, and the queue SHALL offer "Send now", which sends its first message. A message sent on a thread whose queue is paused SHALL join the end of the queue, and the first queued message SHALL be sent. An attachment that cannot be sent SHALL be refused when the message is queued, as for a direct send. The queue SHALL be committed to protected local storage before the composer is cleared and SHALL survive restart and profile reload under the same server, account, profile, and conversation identity. Restored queues SHALL remain paused until explicitly reviewed and sent by the user. Their restored state SHALL override automatic draining, settle timers, and the rule that a new prompt on a paused live queue sends its first entry. New prompts added to a restored queue SHALL remain paused. Switching away from a profile SHALL pause its local queue until the user returns and reviews it. A queue commit failure SHALL keep the composer content and SHALL report that the prompt was not queued. The queue SHALL NOT use any backend route or RPC method beyond those of a direct send (`session.resume`, `prompt.submit`). A voice turn SHALL NOT join a queue or cause a queued message to be sent; it is refused as busy.

#### Scenario: Queued message shown

- **WHEN** the user sends "next" while the reply is streaming
- **THEN** "next" is listed above the composer and is not in the transcript yet

#### Scenario: Sent when the reply completes

- **WHEN** two messages are queued during the current app visit and the reply completes
- **THEN** the first queued message is sent and moves into the transcript with a thinking placeholder
- **AND** the second stays queued until that reply completes, and is then sent

#### Scenario: Fresh messages after recovered work is handled

- **GIVEN** session recovery suspended a queue for explicit review
- **WHEN** its last recovered entry is explicitly sent and accepted, or removed
- **AND WHEN** a fresh message is queued during the next reply
- **THEN** the fresh message is sent automatically after successful completion and session settlement

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

### Requirement: Submit outcome

The system SHALL read the `status` of `prompt.submit`. On `streaming` and `queued` the reply waits for its turn's events. On `redirected` or `steered` the server folded the text into the running turn, so the system SHALL end the new reply's placeholder without an error and leave the user's message in place. A voice call SHALL stop waiting for its own reply on any status but `streaming`.

#### Scenario: Folded into the running turn

- **WHEN** `prompt.submit` is answered with status `redirected` or `steered`
- **THEN** no thinking placeholder stays behind for that message, nothing is marked failed, and the running turn's reply goes on streaming

#### Scenario: Queued by the server

- **WHEN** `prompt.submit` is answered with status `queued`
- **THEN** the reply stays thinking until the server starts that turn with `message.start`

#### Scenario: The reply arrives before the submit answer

- **WHEN** `message.start` and deltas arrive before `prompt.submit` is answered
- **THEN** they stream into the reply as usual

## ADDED Requirements

### Requirement: Voice turns

A prompt sent from a voice call SHALL go through the chat's send path and appear in the transcript, but the client SHALL NOT queue it. Its `prompt.submit` carries `voice_turn: true`; typed prompts carry neither flag.

#### Scenario: Spoken prompt

- **WHEN** a call sends the transcript "what's on my calendar"
- **THEN** the thread shows it as a user message and `prompt.submit` carries `voice_turn: true` and no `queued`

#### Scenario: Typed prompt

- **WHEN** the user types and sends a message
- **THEN** `prompt.submit` carries neither flag

### Requirement: Voice turn authorization

`ChatController.submit` for a voice turn SHALL take a predicate saying the turn is still wanted (the call has not ended, is not muted, is not waiting for a request and has consent), and SHALL check it again after the persisted queue was restored, immediately before the send, and as the `authorize` check of the `prompt.submit` request itself; End SHALL cancel a send whose `prompt.submit` was not written.

#### Scenario: End during the session resume

- **WHEN** the user taps End after the send was handed off and while the transport resumes the session
- **THEN** no `prompt.submit` is written

#### Scenario: End during the queue restore

- **WHEN** the user taps End while `submit` waits for the saved queue
- **THEN** the predicate fails, nothing is sent and nothing is queued

### Requirement: Voice turn refusal

`submit` for a voice turn SHALL return a typed reason when it does not send: busy (a reply runs or the queue is not empty), no longer wanted, queue restore failed, model or branch not allowed, profile not confirmed, or session reclaimed. The call SHALL say "Hermes is still answering. Nothing was sent." only for busy, "Couldn't send. Nothing was sent." for the others that leave the call usable, and SHALL end the call for a lost session or profile.

#### Scenario: Reply still running

- **WHEN** the user finishes speaking while a typed reply is still running
- **THEN** nothing is sent and nothing is queued, and the call says "Hermes is still answering. Nothing was sent."

#### Scenario: Queue not restored yet

- **WHEN** a spoken turn is finished before the saved queue was read, and the queue holds a prompt
- **THEN** nothing is sent and nothing is queued by the client

### Requirement: Interrupted flag

A spoken turn SHALL carry `interrupted: true` only when it is the first one after the user cut off speech (an orb tap or speaking over it), and only when the thread is settled: no pending reply and the session not running (`session.info` running false). Hermes keeps it in a process-wide latch for 120 s that annotates the next turn it starts.

#### Scenario: Barge-in prompt

- **WHEN** the user speaks over a reply and the call submits what they said on a settled thread
- **THEN** `prompt.submit` carries `voice_turn: true` and `interrupted: true`, and the next spoken turn carries only `voice_turn`

### Requirement: Interrupted flag lifetime

A refused, dropped or echoed turn SHALL leave the flag pending. It SHALL be cleared by the first submit that reaches the transport (whatever the answer), by mute, a route change or a typed message, or after 120 s.

#### Scenario: Turn dropped as echo

- **WHEN** the first turn after a tap is dropped as echo and the user then speaks a real turn within 120 s
- **THEN** the real turn carries `interrupted: true`

### Requirement: Voice turn outcomes

The result of a spoken `prompt.submit` SHALL be read by `status`. `streaming` starts the turn. `queued`, `steered` or `redirected` mean Hermes was busy: the call SHALL stop waiting for a spoken reply and listen again, SHALL say which status it was, and SHALL NOT claim the prompt was withdrawn. A `voice_stopped` answer without a `status`, to a typed or a spoken prompt, SHALL count as consumed: no reply placeholder remains, and a running call ends.

#### Scenario: Server folds the prompt

- **WHEN** a spoken prompt is answered `steered`
- **THEN** the call says "Hermes took your words into its current reply." and listens again at once, not after ten minutes

#### Scenario: Other busy answers

- **WHEN** a spoken prompt is answered `queued` or `redirected`
- **THEN** the call says "Hermes will answer your words after its current reply." or "Hermes is adjusting its current reply to your words." and listens again

#### Scenario: Server ends voice mode

- **WHEN** `prompt.submit` answers `{"voice_stopped": true}`
- **THEN** no reply placeholder remains and a running call ends
