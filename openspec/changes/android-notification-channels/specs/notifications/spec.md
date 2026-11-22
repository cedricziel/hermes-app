# Spec Delta

## ADDED Requirements

### Requirement: Android notification channels

On Android the system SHALL post each notification through the channel for its kind, so the user can control each kind in the system settings: `chat_replies` for finished and failed replies, `chat_requests` for approvals, questions and needs-you requests and the notice that an answer could not be sent, `agent_messages` for messages from Hermes and their summary, and `scheduled_tasks` for a scheduled task's run. The first three SHALL have high importance and `scheduled_tasks` default importance. The channel SHALL depend only on the kind of notification, never on its title, body, profile or any server value. The channels SHALL exist before the first notification is posted, in the app and in a background run. The channel ids are permanent. A channel's name and description SHALL be the app's text in the user's language, set when the channel is created and updated when the app's language changes, and SHALL never carry a title, profile name, server address or identifier. The channels do not change a notification's body, buttons, lock-screen visibility, tag or grouping.

#### Scenario: A reply finishes

- **WHEN** a reply finishes and a notification is posted on Android
- **THEN** it goes through the `chat_replies` channel

#### Scenario: A request

- **WHEN** an approval or question notification is posted on Android, with or without buttons
- **THEN** it goes through the `chat_requests` channel
- **AND** it keeps its secret lock-screen visibility and tag

#### Scenario: A scheduled task ran

- **WHEN** a scheduled task's run is announced on Android
- **THEN** it goes through the `scheduled_tasks` channel, whose importance is default

#### Scenario: A message from Hermes

- **WHEN** a message from Hermes, or the summary of several, is announced on Android
- **THEN** it goes through the `agent_messages` channel

#### Scenario: The user silences one kind

- **WHEN** the user silences `scheduled_tasks` in the system settings
- **THEN** replies, requests and messages keep their own settings

#### Scenario: Language changes

- **WHEN** the app's language changes
- **THEN** the channels' names and descriptions follow it
- **AND** no channel's importance changes

#### Scenario: Another platform

- **WHEN** a notification is posted on iOS, macOS, Windows or Linux
- **THEN** it behaves as before and no channel is created

### Requirement: Moving from the single Android channel

The system SHALL, once after an update that brings the channels, replace the earlier single channel `agent_activity`. When that channel exists and its importance is lower than high (the user lowered or blocked it), the new channels SHALL be created with that importance so the user's choice stays; the earlier channel SHALL then be deleted, and the step SHALL not run again. When it does not exist, only the new channels are created. A step that fails SHALL leave the earlier channel in place and be tried again at the next start, and SHALL never sign the user out or lose a notification. The step SHALL record its outcome with a fixed name and flags only.

#### Scenario: Untouched earlier channel

- **WHEN** the app starts after the update and `agent_activity` still has its original importance
- **THEN** the four channels exist at their own importance
- **AND** `agent_activity` is deleted

#### Scenario: The user had muted it

- **WHEN** the app starts after the update and the user had set `agent_activity` to silent or blocked
- **THEN** the four channels are created with that importance
- **AND** `agent_activity` is deleted

#### Scenario: Fresh install

- **WHEN** the app starts and `agent_activity` never existed
- **THEN** the four channels are created and nothing is deleted

#### Scenario: Migration fails

- **WHEN** reading or deleting the earlier channel fails
- **THEN** it is tried again at the next start
- **AND** notifications still post through the new channels
