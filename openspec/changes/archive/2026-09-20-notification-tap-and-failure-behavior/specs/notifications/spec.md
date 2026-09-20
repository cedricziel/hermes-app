## MODIFIED Requirements

### Requirement: Notifiable events

The system SHALL post a local notification for exactly these chat events: a reply that completed, a reply that completed with failure, a reply whose stream broke before it completed (treated as a failed reply), an approval request from the agent, and a clarifying question from the agent. Streaming text, tool activity, title changes, thread binding and expiring input requests SHALL NOT produce a notification. The notification title SHALL be the chat's title.

#### Scenario: Reply completes

- **WHEN** a reply finishes while a notification is warranted
- **THEN** a notification titled with the chat's title is shown

#### Scenario: Streaming and tool events

- **WHEN** the agent streams text or runs a tool
- **THEN** no notification is shown

#### Scenario: Stream breaks while the user is away

- **WHEN** the connection drops or the stream ends before the reply completed and the app is not in the foreground
- **THEN** a notification with the body "Reply failed" is shown for that chat

#### Scenario: Reply that already completed

- **WHEN** a reply completed and its stream then closes normally
- **THEN** only the completion is announced, not a failure

### Requirement: Attention policy

The system SHALL NOT post a notification while the app is in the foreground and the event belongs to the chat that is currently open. It SHALL post one when the app is not in the foreground, even for the open chat, and when the app is in the foreground but another chat (or no chat) is open. A chat counts as open only while the app is still on the profile the turn was sent under. It SHALL post none while the user has notifications turned off, and none until the saved setting has finished loading.

#### Scenario: Watching the chat

- **WHEN** the app is focused on chat A and a reply in chat A completes
- **THEN** no notification is shown

#### Scenario: Reply for another chat

- **WHEN** the app is focused on chat B and a reply in chat A completes
- **THEN** a notification for chat A is shown

#### Scenario: App in the background

- **WHEN** the app is not in the foreground and a reply completes in the open chat
- **THEN** a notification is shown

#### Scenario: Notifications switched off

- **WHEN** the user has turned notifications off
- **THEN** no notification is shown for any event

#### Scenario: Profile changed since the turn was sent

- **WHEN** a turn was sent under profile A, the app is now on profile B, and a chat with the same id is open there
- **THEN** the reply is announced, with profile A, instead of being treated as the open chat

### Requirement: Tapping a notification opens its chat

The system SHALL open the chat a notification was posted for when the user taps it while the app is running, without closing any screen the user has opened above the chat; when the thread drawer of a narrow layout is open, the system SHALL close it. When the tap started the app, the system SHALL open that chat once the chat list has loaded. A tap made while the chat list is still loading SHALL be held and applied once the list has loaded. A notification carries the chat's thread id and, when known, its profile; one without a profile SHALL match on the thread id alone (so a notification posted by an earlier build, whose payload is a bare thread id, still works). When the chat cannot be opened, because the notification's profile differs from the one currently shown or the chat is not in the loaded list, the selection SHALL NOT change (for a launch, the first chat in the list SHALL be selected instead) and the system SHALL tell the user "Could not open that chat."

#### Scenario: Tap while running

- **WHEN** the user taps a notification for chat s2 while chat s1 is open
- **THEN** chat s2 opens

#### Scenario: Screen above the chat

- **WHEN** the user has another screen open above the chat and taps a notification
- **THEN** that screen stays open

#### Scenario: Thread drawer open

- **WHEN** the thread drawer is open on a narrow layout and the user taps a notification for another chat
- **THEN** that chat opens and the drawer closes

#### Scenario: Tap while the list loads

- **WHEN** the user taps a notification for chat s2 while the chat list is still loading
- **THEN** chat s2 opens once the list has loaded and no error is shown

#### Scenario: Tap for an unknown chat

- **WHEN** the tapped notification names a chat that is not in the list
- **THEN** the open chat stays as it was and "Could not open that chat." is shown

#### Scenario: Tap made under another profile

- **WHEN** the notification's profile differs from the profile currently shown
- **THEN** the open chat stays as it was and "Could not open that chat." is shown

#### Scenario: Notification without a profile

- **WHEN** the notification carries no profile
- **THEN** it matches on its thread id alone

#### Scenario: Cold start from a notification

- **WHEN** the app was launched by tapping a notification for chat s2
- **THEN** chat s2 is selected once the list has loaded

#### Scenario: Cold start for a chat that cannot be opened

- **WHEN** the launching notification names a chat that is not in the list, or another profile
- **THEN** the first chat is selected and "Could not open that chat." is shown
