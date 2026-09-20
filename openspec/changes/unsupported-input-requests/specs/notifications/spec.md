## MODIFIED Requirements

### Requirement: Notifiable events

The system SHALL post a local notification for exactly these chat events: a reply that completed, a reply that completed with failure, an approval request from the agent, a clarifying question from the agent, and a request from the agent for something the app cannot answer (a secret value or a sudo password). Streaming text, tool activity, title changes, thread binding and expiring input requests SHALL NOT produce a notification. The notification title SHALL be the chat's title.

#### Scenario: Reply completes

- **WHEN** a reply finishes while a notification is warranted
- **THEN** a notification titled with the chat's title is shown

#### Scenario: Streaming and tool events

- **WHEN** the agent streams text or runs a tool
- **THEN** no notification is shown

#### Scenario: Request the app cannot answer

- **WHEN** the agent asks for a secret value or a sudo password while a notification is warranted
- **THEN** a notification titled with the chat's title is shown

### Requirement: Notification body

For a completed reply the notification body SHALL be a one-line preview of the reply: whitespace runs collapsed to single spaces and trimmed, cut at 120 characters (counted as user-perceived characters, so an emoji is never split) with an ellipsis appended when cut. An empty reply SHALL use the body "Reply ready". A failed reply SHALL use the body "Reply failed" and SHALL NOT include the error text. An approval request SHALL use "Waiting for your approval", a clarifying question SHALL use "Has a question for you", and a request for a secret value or a sudo password SHALL use "Waiting for you in Hermes"; these SHALL NOT include the command, the question or anything about the secret asked for, so that nothing sensitive shows on a lock screen.

#### Scenario: Long reply

- **WHEN** a reply of 200 characters completes
- **THEN** the body is its first 120 characters followed by an ellipsis

#### Scenario: Approval request

- **WHEN** the agent asks for approval to run `rm -rf build`
- **THEN** the body is "Waiting for your approval" and does not mention the command

#### Scenario: Secret or sudo request

- **WHEN** the agent asks for a secret value named `SERVICE_API_KEY` or for a sudo password
- **THEN** the body is "Waiting for you in Hermes" and does not mention the variable or the kind of request

#### Scenario: Failed reply

- **WHEN** a reply completes with failure and an error text
- **THEN** the body is "Reply failed"
