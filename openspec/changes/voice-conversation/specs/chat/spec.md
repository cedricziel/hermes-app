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

## ADDED Requirements

### Requirement: Voice turns

A prompt sent from a voice call SHALL go through the chat's send path and appear in the transcript, but SHALL NOT be queued: it is sent only when the thread has no running reply and an empty queue, else it is dropped with a notice and nothing is sent. Its `prompt.submit` SHALL carry `voice_turn: true`, and `interrupted: true` on the first spoken turn after the user cut off speech (by tapping the orb or speaking over it). Typed prompts SHALL carry neither flag.

#### Scenario: Spoken prompt

- **WHEN** a call sends the transcript "what's on my calendar"
- **THEN** the thread shows it as a user message and `prompt.submit` carries `voice_turn: true` and no `queued`

#### Scenario: Reply still running

- **WHEN** the user finishes speaking while a typed reply is still running
- **THEN** nothing is sent and the call says "Hermes is still answering. Nothing was sent."

#### Scenario: Typed prompt

- **WHEN** the user types and sends a message
- **THEN** `prompt.submit` carries neither flag

### Requirement: Voice turn outcomes

The result of a spoken `prompt.submit` SHALL be read by `status`. `streaming` starts the turn. `queued`, `steered` or `redirected` mean Hermes was busy: the call SHALL stop waiting for a spoken reply, say "Hermes was busy. Your words are in the chat.", and listen again, and SHALL NOT claim the prompt was withdrawn. A `voice_stopped` answer without a `status`, to a typed or a spoken prompt, SHALL count as consumed: no reply placeholder remains, and a running call ends.

#### Scenario: Server folds the prompt

- **WHEN** a spoken prompt is answered `steered`
- **THEN** the call shows the notice and listens again within a second, not after ten minutes

#### Scenario: Server ends voice mode

- **WHEN** `prompt.submit` answers `{"voice_stopped": true}`
- **THEN** no reply placeholder remains and a running call ends
