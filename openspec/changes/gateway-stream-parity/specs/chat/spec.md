# Spec Delta

## MODIFIED Requirements

### Requirement: Streaming the reply

The system SHALL stream the assistant reply into the transcript as it arrives and SHALL keep streaming into the reply's own thread when the user switches to another thread.

#### Scenario: Deltas stream in

- **WHEN** reply text chunks arrive
- **THEN** they are appended to the reply, which moves from thinking to streaming

#### Scenario: Completion

- **WHEN** the reply completes with a final text
- **THEN** the reply shows that text in full, replacing what had streamed since the last text sealed before a tool call or by an interim message, and is finished
- **AND WHEN** the final text is empty
- **THEN** the text that had streamed is kept

#### Scenario: Final already shown as an interim message

- **WHEN** the completion is marked `response_previewed` or `response_reused`
- **AND WHEN** its text equals the text last sealed by an interim message, or the text that streamed since
- **THEN** the reply is finished without showing that text a second time
- **AND WHEN** its text appears nowhere in the reply
- **THEN** it is shown as for any other completion

#### Scenario: Final rewritten after streaming

- **WHEN** the completion is marked `response_transformed`
- **THEN** its text replaces what had streamed since the last seal, even when it shares no prefix with it

#### Scenario: Interim message for text that already streamed

- **WHEN** an interim message arrives with `already_streamed` true
- **THEN** the text that streamed since the last seal is sealed in the interim message's form, and nothing is added twice
- **AND WHEN** an interim message arrives with `already_streamed` false
- **THEN** any text that had streamed since the last seal is sealed as it is, and the interim message's text is sealed after it

#### Scenario: Thinking text is not reply text

- **WHEN** a `thinking.delta` event arrives
- **THEN** nothing is added to the reply text or its reasoning (an explained provider wait may update the status line, see "Reply status line")

#### Scenario: Reply completes while the user looks elsewhere

- **WHEN** the user switches to another thread before the reply finishes
- **THEN** the reply lands in its own thread, and opening that thread shows the reply so far

#### Scenario: Thread title from the dashboard

- **WHEN** the dashboard names or renames the thread while the reply streams
- **THEN** the new title replaces the thread's title in the sidebar and in the top bar

### Requirement: Reply error handling

The system SHALL end a reply that failed or whose stream broke as an error, and SHALL let the user send again.

#### Scenario: Failed completion

- **WHEN** the gateway completes a turn with status `error`
- **THEN** the reply is marked as an error and shows the message text the gateway supplied

#### Scenario: Failed completion with a partial answer

- **WHEN** the gateway completes a turn with status `error` and `partial` true
- **THEN** the completion's text is kept as the reply's answer, and the reply is marked as an error showing the completion's `error` as the explanation

#### Scenario: Failed completion without text

- **WHEN** the gateway completes a turn with status `error` and supplies no message text
- **THEN** the reply is marked as an error, keeps any text that had already streamed, and otherwise shows "Something went wrong. Try sending it again."

#### Scenario: Error event without a completion

- **WHEN** an `error` event arrives for the reply's runtime session while the turn runs, and no completion follows before the session settles
- **THEN** the reply is marked as an error showing the event's `message`, and keeps any text that had already streamed
- **AND WHEN** a failed completion arrives after the `error` event
- **THEN** the reply shows one error, not two

#### Scenario: Stream drops or ends without completion

- **WHEN** the socket drops and the reply cannot be picked up again (see "Reconnecting a live reply"), the gateway answers a request with an error, or the stream ends before a completion
- **THEN** the reply is marked as an error, keeps any text that had already streamed, and otherwise shows "Something went wrong. Try sending it again."
- **AND** the user is notified that the reply failed when a notification is warranted, as for a failed completion (see the notifications spec)

#### Scenario: The selected profile no longer exists

- **WHEN** the gateway answers `session.create` or `session.resume` with the JSON-RPC error 4064 because the profile the chat is showing was deleted or never existed
- **THEN** the reply is marked as an error and shows "That profile is no longer available. Pick another one." instead of the generic message
- **AND** the request is not retried, the user's message stays in the thread, and the text the gateway put in the error is never shown
- **AND** the user is notified that the reply failed when a notification is warranted, as for any other failed reply

#### Scenario: Sending again after a failure

- **WHEN** a reply failed
- **THEN** the user can send another message in the thread

### Requirement: Gateway session handling

The system SHALL send a message by starting a new gateway session (`session.create`) when the thread is not yet known to the dashboard, or resuming the thread's stored session (`session.resume` with its id) otherwise, then submitting the text to the resulting runtime session with `prompt.submit`; the reply SHALL arrive as events of that runtime session. Right after opening a connection and before any session call, the system SHALL tell the gateway that it answers server-to-client requests (`client.capabilities` with `server_requests: true`); a gateway that does not know the method answers with an error, which the system SHALL ignore. When the chat is showing a Hermes profile, the system SHALL pass that profile's name as the `profile` param of `session.create` and `session.resume`, so the session is created in and resumed from that profile rather than the dashboard's own.

#### Scenario: New thread

- **WHEN** a message is sent without a thread id
- **THEN** `session.create` is requested, the stored session id it returns is reported as the thread's id, and `prompt.submit` is requested with the runtime session id and the text

#### Scenario: Existing thread

- **WHEN** a message is sent with a thread id
- **THEN** `session.resume` is requested with `session_id` set to that id and `prompt.submit` is requested on the runtime session id it returns

#### Scenario: Events that arrive before the resume answer

- **WHEN** the gateway pushes events of the resumed runtime session before it answers `session.resume`
- **THEN** those events are kept and delivered in order once the runtime session is known, not dropped

#### Scenario: New thread in a profile

- **WHEN** a message is sent without a thread id while the chat shows the profile "work"
- **THEN** `session.create` is requested with `profile` set to "work"

#### Scenario: Existing thread in a profile

- **WHEN** a message is sent with a thread id while the chat shows the profile "work"
- **THEN** `session.resume` is requested with `session_id` set to that id and `profile` set to "work"

#### Scenario: Profile changes between sends

- **WHEN** the user switches the chat to another profile and sends a message
- **THEN** the session is created or resumed under the newly shown profile, not the previous one

#### Scenario: No profile known

- **WHEN** the server has no active-profile route (404), so it reports none
- **THEN** `session.create` and `session.resume` are requested without a `profile` param, and the dashboard uses its own profile

#### Scenario: Events of other sessions

- **WHEN** an event arrives for another runtime session, or of a type the app does not model
- **THEN** it is ignored

#### Scenario: Prompt is rejected

- **WHEN** `prompt.submit` is answered with a JSON-RPC error
- **THEN** the send fails instead of hanging, and the reply is marked as an error

#### Scenario: Connection is opened lazily and reused

- **WHEN** no message has been sent yet
- **THEN** no socket is opened
- **AND WHEN** several messages are sent
- **THEN** one connection is reused, and a new one is opened when the previous one has closed or when an earlier connection attempt failed

#### Scenario: Credentials for the socket

- **WHEN** the dashboard requires sign-in
- **THEN** each connection first requests a fresh single-use ticket and joins with it as the `ticket` query parameter
- **AND WHEN** the dashboard does not require sign-in
- **THEN** the connection joins with the session token embedded in the dashboard's start page as the `token` query parameter, and fails if the page carries none

#### Scenario: Socket URL

- **WHEN** the socket URL is derived from the server address
- **THEN** it uses `ws` for `http` and `wss` for `https`, keeps any path prefix the dashboard is served under, and appends `/api/ws`

#### Scenario: Capability is announced once per connection

- **WHEN** a connection is opened
- **THEN** `client.capabilities` is requested with `server_requests` set to true before `session.create` or `session.resume`, and not again on that connection

#### Scenario: Gateway does not know the capability call

- **WHEN** `client.capabilities` is answered with a JSON-RPC error
- **THEN** the connection is used as usual and the send does not fail

#### Scenario: Requests of other sessions

- **WHEN** a server-to-client request arrives for another runtime session
- **THEN** it is not shown in this reply and it is not answered by it

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
- **THEN** it requests `session.create` (optional `profile`), `session.resume` (`session_id`, optional `profile`; the result's `session_id`, `running`, `inflight.assistant`, `open_requests` and `messages` are read), `prompt.submit` (`session_id`, `text`, optional `queued`; the result's `status` is read), `session.events.since` (`session_id`, `last_seen`; result `events`, `latest_seq`, `truncated`, `epoch`, `open_requests`), `session.active_list`, `gateway.ping` (any answer counts), `approval.respond` (`session_id`, `request_id`, `choice`; a `resolved` result above zero means accepted) and `clarify.respond` (`request_id`, `answer`, optional `question_id`; a `status` of `expired` means not accepted), `client.capabilities` (`server_requests`) and `clarify.lock` (`request_id`, `question_id`, `answer`; a `status` of `expired` means not accepted) and `session.interrupt` (`session_id`; a `status` of `interrupted` means a running turn was stopped), as JSON-RPC 2.0 with integer ids
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

### Requirement: Queued messages

The system SHALL hold the messages queued on a thread, text and attachments, in the order they were sent, and SHALL show those of the open thread above the composer, each with a control to remove it. While the thread's reply is pending the composer's hint SHALL read "Queue a message…". When a reply ends normally, whether it answered a prompt or was a turn Hermes started on its own, and no reply is pending, the system SHALL send the first queued message as a new turn and remove it from the queue, once the gateway reports the session settled (`session.info` with `running` false) or 2 seconds after the completion when no such report comes. A queued message SHALL be submitted with `queued: true`. When a reply is stopped by the user or fails, the queue SHALL pause: nothing more is sent on its own, and the queue SHALL offer "Send now", which sends its first message. A message sent on a thread whose queue is paused SHALL join the end of the queue, and the first queued message SHALL be sent. An attachment that cannot be sent SHALL be refused when the message is queued, as for a direct send. The queue SHALL be held in memory only, and SHALL be dropped when the threads are loaded again, for example on a profile switch. The queue SHALL NOT use any backend route or RPC method beyond those of a direct send (`session.resume`, `prompt.submit`).

#### Scenario: Queued message shown

- **WHEN** the user sends "next" while the reply is streaming
- **THEN** "next" is listed above the composer and is not in the transcript yet

#### Scenario: Sent when the reply completes

- **WHEN** two messages are queued and the reply completes
- **THEN** the first queued message is sent and moves into the transcript with a thinking placeholder
- **AND** the second stays queued until that reply completes, and is then sent

#### Scenario: Sent only once the session settled

- **WHEN** a message is queued and the reply completes
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

## ADDED Requirements

### Requirement: Turn settling

The system SHALL end a reply's turn on whichever comes first: `message.complete`, an `error` event with no completion before the session settles, or `session.info` with `running` false. A live turn with no frame for 45 seconds SHALL be checked with `session.active_list` and ended only when the session is no longer listed as running.

#### Scenario: Settled without a completion

- **WHEN** a reply has started and `session.info` arrives with `running` false before any completion
- **THEN** the reply ends keeping its streamed text, empty placeholders are removed, open input requests are locked as expired, and running tools are settled
- **AND WHEN** a completion for that turn arrives later
- **THEN** it lands on the same reply and does not create a second one

#### Scenario: Stale report before the turn began

- **WHEN** `session.info` with `running` false arrives within 15 seconds of `prompt.submit` and before `message.start`
- **THEN** the reply is not ended

#### Scenario: A silent live turn

- **WHEN** a reply in flight receives no frame for 45 seconds
- **THEN** `session.active_list` is requested, and the reply is ended as for a broken stream only when its session is not listed as running
- **AND WHEN** the session is still listed as running
- **THEN** the reply keeps waiting

### Requirement: Submit outcome

The system SHALL read the `status` of `prompt.submit`. On `streaming` and `queued` the reply waits for its turn's events. On `redirected` or `steered` the server folded the text into the running turn, so the system SHALL end the new reply's placeholder without an error and leave the user's message in place.

#### Scenario: Folded into the running turn

- **WHEN** `prompt.submit` is answered with status `redirected` or `steered`
- **THEN** no thinking placeholder stays behind for that message, nothing is marked failed, and the running turn's reply goes on streaming

#### Scenario: Queued by the server

- **WHEN** `prompt.submit` is answered with status `queued`
- **THEN** the reply stays thinking until the server starts that turn with `message.start`

#### Scenario: The reply arrives before the submit answer

- **WHEN** `message.start` and deltas arrive before `prompt.submit` is answered
- **THEN** they stream into the reply as usual

### Requirement: Reconnecting a live reply

The system SHALL record the highest `seq` seen for each runtime session. When the socket drops while a reply is in flight, the system SHALL reconnect, rebind with `session.resume`, and replay missed events with `session.events.since`. Events at or below the recorded `seq` SHALL NOT be delivered twice. When replay cannot cover the gap, the reply SHALL be rebuilt from the server's state.

#### Scenario: Replay fills the gap

- **WHEN** the socket drops after event 7 of a running turn and the server's ring holds events 8 to 12
- **THEN** the system reconnects, rebinds the session, delivers events 8 to 12 once each, and goes on with live events from 13

#### Scenario: Live events overlap the replay

- **WHEN** live events arrive after rebinding while the replay is still being read
- **THEN** they are held until the replay is delivered, and any event whose `seq` was already delivered is dropped

#### Scenario: Replay truncated or server restarted

- **WHEN** `session.events.since` reports `truncated`, or its `epoch` differs from the one the recorded seqs were seen under
- **THEN** no replayed event is delivered, the reply's text is replaced by the resume result's `inflight.assistant` while the turn runs, or by the thread's stored messages read over REST once it ended
- **AND** live events the server sent after its `inflight` snapshot are still delivered on top of it, so no text streamed during the reconnect is lost; text the snapshot may already hold is delivered at most twice, never dropped

#### Scenario: Turn ended while disconnected

- **WHEN** the resume result reports `running` false after a drop
- **THEN** the replayed events up to the completion are delivered, and when the completion is not among them, the reply ends with the last stored assistant message, as before

#### Scenario: Requests open across the drop

- **WHEN** the resume or replay result lists `open_requests`
- **THEN** each is shown once, keyed by its id, and a card already shown for that id is not duplicated

#### Scenario: Backoff

- **WHEN** reconnecting fails
- **THEN** the system waits a jittered, growing delay (300 ms base, 15 s cap) between attempts, and after 5 attempts or 60 seconds marks the reply as broken

### Requirement: Connection heartbeat

The system SHALL send `gateway.ping` every 15 seconds on an open connection while a reply is in flight or a thread is listened to, and SHALL treat the connection as dead when no frame of any kind has arrived for 45 seconds.

#### Scenario: Quiet but alive

- **WHEN** no event arrives for 30 seconds but each ping is answered
- **THEN** the connection stays open

#### Scenario: Dead socket

- **WHEN** no frame arrives for 45 seconds
- **THEN** the connection is closed, which starts a reconnect for any reply in flight

#### Scenario: Gateway without ping

- **WHEN** `gateway.ping` is answered with a JSON-RPC error
- **THEN** that answer counts as a sign of life

### Requirement: Turns the user did not submit

The system SHALL show a turn Hermes runs on a thread without a prompt from this app, such as a crash auto-continue after a resume or a goal continuation, as a reply in that thread, while the thread is open or listened to.

#### Scenario: Auto-continue after resume

- **WHEN** a resume reports `auto_continue` and a turn starts that the app did not submit
- **THEN** a new reply appears in the thread and streams as any other
- **AND** while that turn runs ahead of a prompt the user sent, the approvals and questions it raises are shown on the reply in front and can be answered, and that reply says Hermes is finishing the interrupted turn until the turn ends
- **AND** the turn's text appears in a reply of its own once the submitted prompt's turn begins or ends

#### Scenario: Missed start of a chained turn

- **WHEN** after a completed reply the session's deltas or tool events arrive without a `message.start`
- **THEN** a new reply is opened for them instead of dropping them

#### Scenario: Two starts for one continuation

- **WHEN** a goal continuation sends `message.start` twice before its completion
- **THEN** one reply is shown

### Requirement: Thread moved by compression

The system SHALL follow a thread to its new stored session when `session.info` reports a `stored_session_id` different from the thread's id, so later sends, history reads and stops use the new id.

#### Scenario: Compression rotates the stored id

- **WHEN** `session.info` reports `stored_session_id` "stored-2" for a thread known as "stored-1", whether `running` is true or false
- **THEN** the thread keeps its place, title and transcript, and the next send resumes "stored-2"
- **AND** a reply still streaming is not ended by that report

### Requirement: Withdrawn approvals

The system SHALL lock an approval card as expired when an `approval.cancelled` broadcast names its request, or names its session without listing request ids. A broadcast for another session SHALL change nothing.

#### Scenario: Approvals cancelled by an interrupt

- **WHEN** `approval.cancelled` arrives with the reply's session id and the request's id in `request_ids`
- **THEN** that card is locked as expired

#### Scenario: Another session

- **WHEN** `approval.cancelled` names another session
- **THEN** no card changes

### Requirement: Reply status line

The system SHALL show what a thinking reply waits on in place of "Thinking…": "Compacting the conversation…" for `status.update` of kind `compacting`, and the text of a `thinking.delta` that is an explained provider wait (it starts with ⏳, ⚠, ↻ or ⚙ followed by a phrase such as "waiting on", "loading", "no output", "rate limited" or "provider overloaded"). The next delta, tool event, completion or error SHALL clear it.

#### Scenario: Compacting

- **WHEN** a reply is thinking and `status.update` arrives with kind `compacting`
- **THEN** the indicator reads "Compacting the conversation…" until the next delta, tool event or completion

#### Scenario: Explained provider wait

- **WHEN** `thinking.delta` arrives with "⏳ waiting on local-model — 30s with no output yet"
- **THEN** the indicator shows that text
- **AND WHEN** a `message.delta`, `reasoning.delta`, `tool.start`, `message.complete` or `error` follows
- **THEN** the indicator reads "Thinking…" again, or is gone with the placeholder

#### Scenario: Spinner noise

- **WHEN** `thinking.delta` arrives with text that is not an explained wait, such as "◉_◉ cogitating..."
- **THEN** the indicator is unchanged, and an explained wait shown before is cleared

#### Scenario: Other status kinds

- **WHEN** `status.update` arrives with a kind other than `compacting`
- **THEN** the indicator is unchanged
