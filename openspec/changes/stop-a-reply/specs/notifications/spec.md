## MODIFIED Requirements

### Requirement: Notifiable events

The system SHALL post a local notification for exactly these chat events: a reply that completed, a reply that completed with failure, a reply that broke (the stream ended or failed while the reply was still pending, for example because the socket dropped or the gateway answered with an error, so that no completion arrived), an approval request from the agent, a clarifying question from the agent, and a request from the agent for something the app cannot answer (a secret value or a sudo password). A broken reply SHALL be announced exactly like a failed one. A reply the user stopped SHALL NOT produce a notification. Streaming text, tool activity, title changes, thread binding and expiring input requests SHALL NOT produce a notification. The notification title SHALL be the chat's title.

#### Scenario: Reply completes

- **WHEN** a reply finishes while a notification is warranted
- **THEN** a notification titled with the chat's title is shown

#### Scenario: Reply breaks while the user is away

- **WHEN** the app is in the background, the socket drops while a reply is pending and no completion arrived
- **THEN** a notification titled with the chat's title and the body "Reply failed" is shown

#### Scenario: Stream ends after the reply already completed

- **WHEN** the stream ends after the reply completed
- **THEN** no further notification is shown

#### Scenario: Streaming and tool events

- **WHEN** the agent streams text or runs a tool
- **THEN** no notification is shown

#### Scenario: Request the app cannot answer

- **WHEN** the agent asks for a secret value or a sudo password while a notification is warranted
- **THEN** a notification titled with the chat's title is shown

#### Scenario: Reply the user stopped

- **WHEN** the user stops a reply and it completes as stopped while the app is not in the foreground
- **THEN** no notification is shown
