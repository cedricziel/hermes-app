## MODIFIED Requirements

### Requirement: Gateway session handling

The system SHALL send a message by starting a new gateway session (`session.create`) when the thread is not yet known to the dashboard, or resuming the thread's stored session (`session.resume` with its id) otherwise, then submitting the text to the resulting runtime session with `prompt.submit`; the reply SHALL arrive as events of that runtime session. When the chat is showing a Hermes profile, the system SHALL pass that profile's name as the `profile` param of `session.create` and `session.resume`, so the session is created in and resumed from that profile rather than the dashboard's own.

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
- **THEN** it requests `session.create` (optional `profile`), `session.resume` (`session_id`, optional `profile`), `prompt.submit` (`session_id`, `text`), `approval.respond` (`session_id`, `request_id`, `choice`; a `resolved` result above zero means accepted) and `clarify.respond` (`request_id`, `answer`, optional `question_id`; a `status` of `expired` means not accepted), as JSON-RPC 2.0 with integer ids
- **AND** the gateway binds a session to the profile it was created or resumed under, so `prompt.submit` and the answer calls carry no profile

#### Scenario: Events

- **WHEN** the gateway pushes an `event` notification
- **THEN** its `type` is mapped as follows: `message.start` (reply started), `message.delta` (`text`), `tool.start` (`name`, `context`), `tool.complete` (`name`, `result.error`), `session.title` (`title`), `message.complete` (`text`, `status`), `approval.request` (`request_id`, `command`, `description`, `choices`), `clarify.request` (`request_id` with either `question`, `choices`, `multi_select` or a `questions` list of `qid`, `question`, `choices`, `multi_select`), and `approval.expire` or `clarify.expire` (`request_id`)
- **AND** other event types are ignored

#### Scenario: Socket closes

- **WHEN** the socket closes
- **THEN** all pending requests fail with a "connection closed" error, later requests fail at once, and frames that are not JSON-RPC are ignored
