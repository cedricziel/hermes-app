## ADDED Requirements

### Requirement: Turns sent from the watch

The system SHALL post a notification for a turn sent from the watch and relayed through the phone, under the rules of "Notifiable events" and "Notification body": a reply that completed, a reply that completed with failure, and a reply that broke (the connection dropped, the stream ended without a completion, or no event arrived for the send timeout) once the chat was known. A broken reply SHALL be announced as a failed one. The system SHALL post it whichever chat the phone has open and whether or not the app is in front, because the phone's chat screen does not follow a turn it did not send, so "Attention policy" does not suppress it. Its title SHALL be the chat's title when the gateway named it during the turn, and "Hermes" otherwise. It SHALL replace an earlier notification for the same chat and profile. The system SHALL NOT post for an approval request, a question or an unsupported request raised during such a turn, SHALL NOT post while notifications are off or the saved setting is loading, SHALL NOT post for a reply that broke before the chat was known, and SHALL NOT ask the operating system for permission on behalf of a watch turn.

#### Scenario: Reply completes while the wrist is down

- **WHEN** a turn sent from the watch completes with "Done. Two files changed." and notifications are on and permitted
- **THEN** a notification with the body "Done. Two files changed." is shown

#### Scenario: Chat named during the turn

- **WHEN** the gateway titles a new chat "Groceries" during a watch turn and the reply completes
- **THEN** the notification is titled "Groceries"

#### Scenario: Existing chat not renamed

- **WHEN** a watch turn into an existing chat completes without the gateway renaming it
- **THEN** the notification is titled "Hermes"

#### Scenario: Phone showing the same chat

- **WHEN** the phone app is in front on chat A and a turn the watch sent into chat A completes
- **THEN** a notification is shown

#### Scenario: Failed reply

- **WHEN** a watch turn completes with failure and an error text
- **THEN** the body is "Reply failed" and does not include the error text

#### Scenario: Turn breaks after the chat is known

- **WHEN** the connection drops after the chat was created or resumed and no completion arrived
- **THEN** a notification with the body "Reply failed" is shown

#### Scenario: Turn breaks before the chat is known

- **WHEN** the connection fails before the gateway reported a chat
- **THEN** no notification is shown

#### Scenario: Input request during a watch turn

- **WHEN** the agent asks for an approval or a question during a watch turn
- **THEN** no notification is shown

#### Scenario: Notifications off or not permitted

- **WHEN** notifications are off, or the user has never answered the permission prompt
- **THEN** no notification is shown and no permission prompt is raised
