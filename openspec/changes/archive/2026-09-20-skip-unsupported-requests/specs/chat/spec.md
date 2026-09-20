## MODIFIED Requirements

### Requirement: Requests the app cannot answer

The system SHALL show a request for a secret value or a sudo password, whether it arrives as the events `secret.request` and `sudo.request` or as the server-to-client requests `secret` and `sudo`, as a card "Hermes needs something else" in the reply, saying that Hermes asked for "a secret value, such as an API key" or "your sudo password", that this app cannot ask for it yet, and that it can be answered in the Hermes terminal or dashboard, with a "Skip" button. The system SHALL NOT ask the user for, collect, store or send a secret or password, and SHALL NOT show the request's prompt, variable name, metadata or command. It SHALL answer a secret or sudo request only when the user taps "Skip", and then only with an empty value, which tells Hermes to carry on without it.

#### Scenario: Sudo request

- **WHEN** a `sudo.request` event or a `sudo` server-to-client request arrives
- **THEN** a card titled "Hermes needs something else" is added to the reply, saying Hermes asked for your sudo password, that the app cannot ask for it yet, and to answer it in the Hermes terminal or dashboard

#### Scenario: Secret request

- **WHEN** a `secret.request` event or a `secret` server-to-client request arrives with a prompt and a variable name
- **THEN** the card says Hermes asked for a secret value, such as an API key, and shows neither the prompt nor the variable name

#### Scenario: Nothing is collected

- **WHEN** the card is shown
- **THEN** it has no text field and one button, "Skip", and nothing is sent until the user taps it

#### Scenario: Skipping

- **WHEN** the user taps "Skip" on a pending card
- **THEN** an empty answer is sent for that request, the button is disabled while it is in flight, and once sent the card reads "You skipped this request" with no button

#### Scenario: Skipping a request that already ended

- **WHEN** the user taps "Skip" and the gateway no longer waits for the request
- **THEN** the card is locked and shows "This request timed out"

#### Scenario: Skip fails

- **WHEN** sending the empty answer throws
- **THEN** the card shows "Could not send your answer. Try again." and the button is usable again

#### Scenario: No thinking indicator

- **WHEN** the request is pending
- **THEN** the thinking indicator is hidden

#### Scenario: Expiry

- **WHEN** a `secret.expire` or `sudo.expire` event, or a `request.cancel` event, names the request
- **THEN** only that pending card is locked and shows "This request timed out" instead of where to answer
- **AND WHEN** the reply completes or its stream breaks
- **THEN** every such card still pending is locked as expired

### Requirement: Backend contract

The system SHALL use the following dashboard routes, JSON-RPC methods and events for chat, and SHALL parse session rows leniently, skipping rows that do not fit.

#### Scenario: REST routes

- **WHEN** the chat reads or changes threads
- **THEN** it uses `GET /api/sessions` (`limit`, `offset`, `order=recent`, `archived=exclude`, `profile`; response `sessions` and optionally `total`), `GET /api/sessions/{id}/messages` (`profile`; response `messages`), `PATCH /api/sessions/{id}` (body with `title`, `pinned` or `archived`, and `profile`) and `DELETE /api/sessions/{id}` (`profile`)
- **AND** it uses `GET /api/profiles/active` to learn which profile to list, `POST /api/auth/ws-ticket` (response `ticket`) and `GET /` (the `__HERMES_SESSION_TOKEN__` value) to obtain socket credentials

#### Scenario: Row fields

- **WHEN** a session row is parsed
- **THEN** `id`, `title`, `preview`, `last_active`, `started_at` and `pinned` are read
- **AND** a message row's `id`, `role`, `content`, `timestamp` and `tool_calls` are read, and a loaded message's id is `<session id>-<row id>`

#### Scenario: JSON-RPC methods

- **WHEN** the chat talks over `/api/ws`
- **THEN** it requests `session.create` (optional `profile`), `session.resume` (`session_id`, optional `profile`), `prompt.submit` (`session_id`, `text`), `approval.respond` (`session_id`, `request_id`, `choice`; a `resolved` result above zero means accepted) and `clarify.respond` (`request_id`, `answer`, optional `question_id`; a `status` of `expired` means not accepted), `client.capabilities` (`server_requests`) and `clarify.lock` (`request_id`, `question_id`, `answer`; a `status` of `expired` means not accepted), as JSON-RPC 2.0 with integer ids
- **AND** the gateway binds a session to the profile it was created or resumed under, so `prompt.submit` and the answer calls carry no profile
- **AND** it answers a secret or a sudo request only to skip it: `sudo.respond` (`request_id`, `password` empty) or `secret.respond` (`request_id`, `value` empty), where a `status` of `expired` means not accepted

#### Scenario: Server-to-client requests

- **WHEN** the gateway sends a JSON-RPC request with a string id and a `method`
- **THEN** `approval` (`session_id`, `command`, `description`, `choices`) shows an approval card, and `clarify` (`session_id` with either `question`, `choices`, `multi_select` or a `questions` list of `qid`, `question`, `choices`, `multi_select`) shows a clarify card, both keyed by the request's `id`
- **AND** `secret` and `sudo` show the card for requests the app cannot answer, reading nothing but the `id` and the session
- **AND** any other method is answered at once with the JSON-RPC error -32601 "method not found"
- **AND** a request whose `session_id` is not the reply's runtime session is left alone

#### Scenario: Answering a server-to-client request

- **WHEN** the user answers an approval
- **THEN** a response frame `{id, result: {choice}}` is sent with the request's id
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
- **THEN** its `type` is mapped as follows: `message.start` (reply started), `message.delta` (`text`), `tool.start` (`name`, `context`), `tool.complete` (`name`, `result.error`), `session.title` (`title`), `message.complete` (`text`, `status`), `approval.request` (`request_id`, `command`, `description`, `choices`), `clarify.request` (`request_id` with either `question`, `choices`, `multi_select` or a `questions` list of `qid`, `question`, `choices`, `multi_select`), `secret.request` and `sudo.request` (`request_id` only; the prompt, variable name and metadata are not read), and `approval.expire`, `clarify.expire`, `secret.expire` or `sudo.expire` (`request_id`), and `request.cancel` (`id`, the id of a server-to-client request)
- **AND** other event types are ignored

#### Scenario: Socket closes

- **WHEN** the socket closes
- **THEN** all pending requests fail with a "connection closed" error, later requests fail at once, and frames that are not JSON-RPC are ignored
