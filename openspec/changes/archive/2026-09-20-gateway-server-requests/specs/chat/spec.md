## MODIFIED Requirements

### Requirement: Gateway session handling

The system SHALL send a message by starting a new gateway session (`session.create`) when the thread is not yet known to the dashboard, or resuming the thread's stored session (`session.resume` with its id) otherwise, then submitting the text to the resulting runtime session with `prompt.submit`; the reply SHALL arrive as events of that runtime session. Right after opening a connection and before any session call, the system SHALL tell the gateway that it answers server-to-client requests (`client.capabilities` with `server_requests: true`); a gateway that does not know the method answers with an error, which the system SHALL ignore. When the chat is showing a Hermes profile, the system SHALL pass that profile's name as the `profile` param of `session.create` and `session.resume`, so the session is created in and resumed from that profile rather than the dashboard's own.

#### Scenario: New thread

- **WHEN** a message is sent without a thread id
- **THEN** `session.create` is requested, the stored session id it returns is reported as the thread's id, and `prompt.submit` is requested with the runtime session id and the text

#### Scenario: Existing thread

- **WHEN** a message is sent with a thread id
- **THEN** `session.resume` is requested with `session_id` set to that id and `prompt.submit` is requested on the runtime session id it returns

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

- **WHEN** the dashboard did not report the active profile
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

### Requirement: Requests the app cannot answer

The system SHALL show a request for a secret value or a sudo password, whether it arrives as the events `secret.request` and `sudo.request` or as the server-to-client requests `secret` and `sudo`, as a card "Hermes needs something else" in the reply, saying that Hermes asked for "a secret value, such as an API key" or "your sudo password", that this app cannot ask for it yet, and that it can be answered in the Hermes terminal or dashboard. The system SHALL NOT ask the user for, collect, store or send a secret or password, and SHALL NOT show the request's prompt, variable name, metadata or command. It SHALL NOT answer a secret or sudo request in any form.

#### Scenario: Sudo request

- **WHEN** a `sudo.request` event or a `sudo` server-to-client request arrives
- **THEN** a card titled "Hermes needs something else" is added to the reply, saying Hermes asked for your sudo password, that the app cannot ask for it yet, and to answer it in the Hermes terminal or dashboard

#### Scenario: Secret request

- **WHEN** a `secret.request` event or a `secret` server-to-client request arrives with a prompt and a variable name
- **THEN** the card says Hermes asked for a secret value, such as an API key, and shows neither the prompt nor the variable name

#### Scenario: Nothing is collected

- **WHEN** the card is shown
- **THEN** it has no text field or button, and no `secret.respond` or `sudo.respond` call and no response to a `secret` or `sudo` server-to-client request is ever made

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
- **AND** it requests no method to answer a secret or a sudo request

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

#### Scenario: Events

- **WHEN** the gateway pushes an `event` notification
- **THEN** its `type` is mapped as follows: `message.start` (reply started), `message.delta` (`text`), `tool.start` (`name`, `context`), `tool.complete` (`name`, `result.error`), `session.title` (`title`), `message.complete` (`text`, `status`), `approval.request` (`request_id`, `command`, `description`, `choices`), `clarify.request` (`request_id` with either `question`, `choices`, `multi_select` or a `questions` list of `qid`, `question`, `choices`, `multi_select`), `secret.request` and `sudo.request` (`request_id` only; the prompt, variable name and metadata are not read), and `approval.expire`, `clarify.expire`, `secret.expire` or `sudo.expire` (`request_id`), and `request.cancel` (`id`, the id of a server-to-client request)
- **AND** other event types are ignored

#### Scenario: Socket closes

- **WHEN** the socket closes
- **THEN** all pending requests fail with a "connection closed" error, later requests fail at once, and frames that are not JSON-RPC are ignored
