# background-refresh-alerts Specification

## Purpose
Describes how background runs announce replies that finished while the app was suspended, and the list of running replies the app keeps for that.

## Requirements

### Requirement: Finished replies in the background

When the app moves to the background, it SHALL remember the chats whose reply is still running, in every profile, and SHALL forget them when it returns to the front. A background run SHALL check the session of each remembered chat and SHALL announce only on positive evidence: the session is listed with its turn ended (`idle`) and the newest stored message is the assistant's own text. The run SHALL then post the chat's notification, as the notifications spec defines it for a completed reply, with a one-line preview of that text, and only after posting forget the chat.

A chat whose session is no longer listed or has a status the app does not know, one that ends on the user's own prompt or on a tool call, and one whose reply has no text, SHALL be forgotten without a notification: nothing says its reply was completed, and a turn that was stopped or lost shows no differently. A chat whose history cannot be read SHALL be kept for the next run.

When the app returns and replays the ending of a reply a run announced, it SHALL NOT announce it again: a run records the chats it announced, and the app checks and consumes that record when the reply ends, and discards it a short while after returning, so it can only silence the replay of that ending.

A chat SHALL be forgotten after 24 hours. When the run is signed out, locked or cannot reach the server, nothing SHALL be announced or forgotten, and the schedule baseline SHALL stay as it was. When the live sessions cannot be read, nothing SHALL be announced or forgotten. Nothing SHALL be posted while notifications are off.

#### Scenario: Reply finished while suspended

- **WHEN** the user leaves the app while chat A's reply runs, and the reply finishes before a background run
- **THEN** the run posts chat A's notification with the start of the reply

#### Scenario: Still working

- **WHEN** chat A's session still reports a running or resuming turn
- **THEN** nothing is posted and chat A stays remembered

#### Scenario: Phone locked since restart

- **WHEN** a background run happens before the first unlock after a restart
- **THEN** nothing is posted and chat A stays remembered

#### Scenario: Back in front

- **WHEN** the user opens the app before any background run
- **THEN** the remembered chats are forgotten and the app in front shows the replies

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

### Requirement: Messages from Hermes in the background

A background run SHALL look for messages from Hermes as the agent-messages spec defines, only while notifications and the "Messages from Hermes" setting are on and the app is not in front, and SHALL post them with the same texts and per-chat notifications as the app in front. It SHALL save the record before posting, so a record that cannot be saved announces nothing rather than the same chat at every run. When the run is signed out, locked or cannot reach the server, or the profile names cannot be read, nothing SHALL be announced and the record SHALL stay as it was.

#### Scenario: Message while suspended

- **WHEN** a profile delivers a message while the app is suspended and the system grants a background run
- **THEN** the run posts the message's notification

#### Scenario: Locked before first unlock

- **WHEN** a background run happens before the first unlock after a restart
- **THEN** nothing is posted and the record is unchanged
