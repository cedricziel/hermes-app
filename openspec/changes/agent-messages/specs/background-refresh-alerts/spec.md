# Spec Delta

## MODIFIED Requirements

### Requirement: Alert counts in telemetry

The background run's `background.task` span SHALL include the number of finished replies, the number of scheduled runs and the number of messages from Hermes it announced. It SHALL NOT hold ids, titles, profile names or text.

#### Scenario: One reply announced

- **WHEN** a run announces one finished reply
- **THEN** its span says `replies.finished: 1` and holds no chat id

#### Scenario: Messages announced

- **WHEN** a run announces two messages from Hermes
- **THEN** its span says `agent_messages.found: 2` and holds no chat id or title

### Requirement: Backend contract

These checks SHALL rely on:

- the gateway method `session.active_list`: params `profile`; result `sessions[]` with `session_key` and `status`;
- `GET /api/sessions/{session_id}/messages`;
- `GET /api/cron/delivery-targets`;
- `GET /api/cron/jobs?profile=all`;
- for messages from Hermes, `GET /api/sessions` with `source`, `order`, `offset` and `profile`, and the profile list, as the agent-messages spec defines.

The app already uses all of them. Finished replies and scheduled runs SHALL need no new Hermes route, RPC method or minimum version; messages from Hermes need session read state, as the agent-messages spec says, and are simply not announced without it.

#### Scenario: Oldest supported Hermes

- **WHEN** the app is connected to the oldest Hermes it supports
- **THEN** background runs announce finished replies and scheduled runs as described

#### Scenario: Hermes without read state

- **WHEN** a background run reaches a Hermes whose sessions carry no read state
- **THEN** it announces no messages from Hermes and still announces replies and scheduled runs

## ADDED Requirements

### Requirement: Messages from Hermes in the background

A background run SHALL look for messages from Hermes as the agent-messages spec defines, only while notifications and the "Messages from Hermes" setting are on and the app is not in front, and SHALL post them with the same texts and per-chat notifications as the app in front. It SHALL save the record before posting, so a record that cannot be saved announces nothing rather than the same chat at every run. When the run is signed out, locked or cannot reach the server, or the profile names cannot be read, nothing SHALL be announced and the record SHALL stay as it was.

#### Scenario: Message while suspended

- **WHEN** a profile delivers a message while the app is suspended and the system grants a background run
- **THEN** the run posts the message's notification

#### Scenario: Locked before first unlock

- **WHEN** a background run happens before the first unlock after a restart
- **THEN** nothing is posted and the record is unchanged
