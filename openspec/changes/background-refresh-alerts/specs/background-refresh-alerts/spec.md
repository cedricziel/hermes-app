# Spec Delta

## Purpose

Describes how background runs announce replies that finished while the app was suspended, and the list of running replies the app keeps for that.

## ADDED Requirements

### Requirement: Finished replies in the background

When the app moves to the background, it SHALL remember the chats whose reply is still running, and SHALL forget them when it returns to the front. A background run SHALL check the session of each remembered chat. When the session no longer runs a turn, the run SHALL post the chat's notification, as the notifications spec defines it for a completed reply, and forget the chat:

- a one-line preview of the last reply;
- "Reply ready" when the reply cannot be read or is empty;
- "Reply failed" for a failed reply.

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

The background run's `background.task` span SHALL include the number of finished replies and the number of scheduled runs it announced. It SHALL NOT hold ids, titles, profile names or text.

#### Scenario: One reply announced

- **WHEN** a run announces one finished reply
- **THEN** its span says `replies.finished: 1` and holds no chat id

### Requirement: Backend contract

These checks SHALL rely on:

- the gateway method `session.active_list`: params `profile`; result `sessions[]` with `session_key` and `status`;
- `GET /api/sessions/{session_id}/messages`;
- `GET /api/cron/delivery-targets`;
- `GET /api/cron/jobs?profile=all`.

The app already uses all of them. These checks SHALL need no new Hermes route, RPC method or minimum version.

#### Scenario: Oldest supported Hermes

- **WHEN** the app is connected to the oldest Hermes it supports
- **THEN** background runs announce finished replies and scheduled runs as described
