## ADDED Requirements

### Requirement: Requests the app cannot answer

The system SHALL show a request for a secret value (`secret.request`) or a sudo password (`sudo.request`) as a card "Hermes needs something else" in the reply, saying that Hermes asked for "a secret value, such as an API key" or "your sudo password", that this app cannot ask for it yet, and that it can be answered in the Hermes terminal or dashboard. The system SHALL NOT ask the user for, collect, store or send a secret or password, and SHALL NOT show the request's prompt, variable name or metadata.

#### Scenario: Sudo request

- **WHEN** a `sudo.request` arrives
- **THEN** a card titled "Hermes needs something else" is added to the reply, saying Hermes asked for your sudo password, that the app cannot ask for it yet, and to answer it in the Hermes terminal or dashboard

#### Scenario: Secret request

- **WHEN** a `secret.request` arrives with a prompt and a variable name
- **THEN** the card says Hermes asked for a secret value, such as an API key, and shows neither the prompt nor the variable name

#### Scenario: Nothing is collected

- **WHEN** the card is shown
- **THEN** it has no text field or button, and no `secret.respond` or `sudo.respond` call is ever made

#### Scenario: No thinking indicator

- **WHEN** the request is pending
- **THEN** the thinking indicator is hidden

#### Scenario: Expiry

- **WHEN** a `secret.expire` or `sudo.expire` event names the request
- **THEN** only that pending card is locked and shows "This request timed out" instead of where to answer
- **AND WHEN** the reply completes or its stream breaks
- **THEN** every such card still pending is locked as expired

## MODIFIED Requirements

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
- **THEN** it requests `session.create`, `session.resume` (`session_id`), `prompt.submit` (`session_id`, `text`), `approval.respond` (`session_id`, `request_id`, `choice`; a `resolved` result above zero means accepted) and `clarify.respond` (`request_id`, `answer`, optional `question_id`; a `status` of `expired` means not accepted), as JSON-RPC 2.0 with integer ids
- **AND** it requests no method to answer a secret or a sudo request

#### Scenario: Events

- **WHEN** the gateway pushes an `event` notification
- **THEN** its `type` is mapped as follows: `message.start` (reply started), `message.delta` (`text`), `tool.start` (`name`, `context`), `tool.complete` (`name`, `result.error`), `session.title` (`title`), `message.complete` (`text`, `status`), `approval.request` (`request_id`, `command`, `description`, `choices`), `clarify.request` (`request_id` with either `question`, `choices`, `multi_select` or a `questions` list of `qid`, `question`, `choices`, `multi_select`), `secret.request` and `sudo.request` (`request_id` only; the prompt, variable name and metadata are not read), and `approval.expire`, `clarify.expire`, `secret.expire` or `sudo.expire` (`request_id`)
- **AND** other event types are ignored

#### Scenario: Socket closes

- **WHEN** the socket closes
- **THEN** all pending requests fail with a "connection closed" error, later requests fail at once, and frames that are not JSON-RPC are ignored
