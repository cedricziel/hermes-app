## Purpose

Define reliable transport, authority, replay, and exact user controls for Hermes-hosted bot group conversations.

## ADDED Requirements

### Requirement: Hosted room capability discovery

The system SHALL discover hosted room support through `groups.capabilities` over authenticated `/api/ws`. The verified transport baseline is Hermes 0.21.4 source commit `35fdb4608aa8af455d2597664cff1754a3722cd1`, hosted protocol version 2; earliest release support is unverified. It SHALL require a supported protocol, advertised required methods, `idempotent_send`, `monotonic_log`, `hosted_interactions_v1`, and driver readiness for execution. `hosted_interactions_v1` SHALL advertise task-fenced `groups.respond` for clarify and visible server refusal of hosted sudo and secret requests. Protocol version 2 alone does not establish interaction compatibility.

#### Scenario: Capability and readiness

- **WHEN** the app probes rooms
- **THEN** it reads `protocol_version`, `driver`, `persistent_process`, `authority_gateway_id`, `features`, `methods`, and `max_log_limit`
- **AND** absent support is distinguished from a transient/offline/unauthorized probe; driver unavailability or missing interaction support disables execution without erasing readable history

### Requirement: Hosted room requests

The system SHALL use the connected gateway's room authority, generate stable operation identifiers, and implement the following contracts without a client-owned agent driver.

#### Scenario: List and create

- **WHEN** listing rooms
- **THEN** `groups.list` receives optional `limit` and `offset` and returns `rooms` and optional `next_offset`
- **AND** `groups.create` receives a stable `room_id`, `name`, and 2–6 local members with unique `member_id`, `profile`, `handle`, and optional `display_name`, returning `room`
- **AND** a room includes `room_id`, `name`, `members`, `authority_gateway_id`, `authority_epoch`, `revision`, timestamps, and optional `latest_seq`; membership remains frozen after creation

#### Scenario: Send and management

- **WHEN** sending room text
- **THEN** `groups.send` receives `room_id`, a stable `event_id`, and `payload` containing only `text` and `thread_id`, returning `event`, optional `client_event_id`, `accepted`, and `driver_started`
- **AND** rename uses `groups.rename` with `room_id`, `event_id`, and `name`; stop uses `groups.stop` with `room_id` and stable `cancel_id`; disband uses `groups.disband` with `room_id` and stable `cancel_id`, returning a tombstone
- **AND** ambiguous sends retain the same event identity and reconcile against replay using the server event identity `user:` followed by the lowercase SHA-256 hex digest of the UTF-8 client event ID before any explicit retry, rather than being sent as new messages

### Requirement: Monotonic room replay

The system SHALL reconstruct room history from the durable server log, advancing its cursor only after validated events are incorporated.

#### Scenario: Page, reconnect, and deduplication

- **WHEN** reading or reconnecting a room
- **THEN** `groups.log` receives `room_id`, `since_seq`, and bounded `limit`, returning `events`, `cursor`, `latest_seq`, `has_more`, and `authority` with gateway ID and epoch
- **AND** events contain `room_id`, `seq`, `event_id`, `kind`, `actor`, `payload`, and `created_at`; pages continue while `has_more`; repeated sequence/event identities do not duplicate transcript rows
- **AND** an unexpected authority, stale response, or malformed event cannot silently advance the cursor or start a second driver

### Requirement: Exact room actions

The system SHALL obtain pending actions from `groups.state` and apply approval or retry only to the exact server coordinates after explicit user action.

#### Scenario: Pending approvals

- **WHEN** room state reports an approval
- **THEN** `groups.state` returns `room` and `driver_status` with `running`, `working`, `blocked`, `counts`, `pending_actions`, and `peer_routes`
- **AND** `groups.approve` sends `room_id`, `member_id`, `task_id`, `execution_generation`, `request_id`, and a choice of `once` or `deny`
- **AND** stale requests are not rebound to a newer task, and no request is automatically answered

### Requirement: Hosted clarification and unsupported input outcomes

The system SHALL let the user answer a hosted member's clarify request through a server-advertised room action. It SHALL never ask for sudo passwords or secret values in hosted groups. A server that cannot provide both behaviors SHALL leave group execution unavailable with a specific compatibility explanation while retaining readable room history.

#### Scenario: Exact pending clarification

- **WHEN** a hosted member calls `clarify`, including a batch of questions
- **THEN** `groups.state.driver_status.pending_actions` exposes a `clarify` action with `room_id`, `member_id`, `task_id`, `execution_generation`, `request_id`, and the question IDs, text, choices, and selection mode needed to answer it
- **AND** `groups.respond` submits answers or explicit skips for those question IDs against those exact coordinates; the server refuses a stale, already answered, stopped, or mismatched request without affecting another turn
- **AND** the action remains discoverable after app reconnect until answered, cancelled, or expired, and its resolution clears the pending action

#### Scenario: Sudo and secret refusal

- **WHEN** a hosted member requests a sudo password or secret value
- **THEN** the server refuses that request without accepting a value and publishes an attributed, durable failed-turn outcome with a non-sensitive reason code
- **AND** `groups.state` and `groups.log` expose the failure within 10 seconds in an isolated local conformance run, without waiting for the ordinary prompt or whole-turn timeout or requiring the user to press Stop
- **AND** no password, secret, prompt arguments, or answer appears in room state, room events, or added telemetry

#### Scenario: Missing interaction contract

- **WHEN** a protocol 2 server lacks `hosted_interactions_v1` or `groups.respond`, or the real-backend clarification and refusal checks fail
- **THEN** the app does not create or send executable hosted room work, explains the missing interaction support, and keeps existing room history readable
- **AND** it does not attach to hidden member sessions or substitute ordinary `session.resume`, `request.answer`, or `clarify.lock` calls for the fenced room action

#### Scenario: Explicit retry

- **WHEN** the user confirms a server-advertised pending retry action for an indeterminate or deferred task
- **THEN** `groups.retry` sends the exact `room_id` and `task_id`, returns `retried` and the task receipt, and the app handles a refusal without creating a replacement task
