# Spec Delta

## MODIFIED Requirements

### Requirement: Notifiable events

The system SHALL post a local notification for exactly these chat events: a reply that completed, a reply that completed with failure, a reply that broke (the stream ended or failed while the reply was still pending, for example because the socket dropped or the gateway answered with an error, so that no completion arrived), an approval request from the agent, a clarifying question from the agent, a request from the agent for something the app cannot answer (a secret value or a sudo password), and a new message a Hermes profile delivered to the Hermes App inbox (see the agent-messages spec). A broken reply SHALL be announced exactly like a failed one. A reply the user stopped SHALL NOT produce a notification. Streaming text, tool activity, title changes, thread binding and expiring input requests SHALL NOT produce a notification. The notification title SHALL be the chat's title, with the additions the agent-messages spec makes for a message from Hermes.

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

#### Scenario: Message from Hermes

- **WHEN** a Hermes profile delivers a message to the Hermes App inbox while a notification is warranted
- **THEN** a notification titled with the new chat's title is shown

### Requirement: Tapping a notification opens its chat

The system SHALL open the chat a notification was posted for when the user taps it while the app is running. When the Chat and Kanban destinations are shown, the system SHALL select Chat on every tap, including a tap whose chat cannot be opened, so that the user is not left on the Kanban board, and SHALL dismiss the screens pushed over the board (a task, board management, the create form). When the tap started the app, the system SHALL select Chat and open that chat once the chat list has loaded. A tap that arrives while the chat list is still loading SHALL be held and applied when the list has loaded, and SHALL take precedence over the notification that launched the app. A notification carries the chat's thread id and, when known, its profile; a notification without a profile SHALL match on the thread id alone (so a notification posted by an earlier build, whose payload is a bare thread id, still works). A notification for a message from Hermes, and the summary of several, SHALL open as the agent-messages spec defines (switching profile and fetching the chat); for every other notification, if the target chat cannot be opened, because it belongs to a different profile than the one currently shown or is not in the loaded list, the selection SHALL NOT change (for a launch, the welcome view for a new chat is shown instead) and the system SHALL tell the user with the message "Could not open that chat." Opening a chat from a notification SHALL close the chat list drawer when it is open, and SHALL NOT close or pop any other screen the user has open, except the screens pushed over the Kanban board.

#### Scenario: Tap while running

- **WHEN** the user taps a notification for chat s2 while chat s1 is open
- **THEN** chat s2 opens

#### Scenario: Tap while Kanban is shown

- **WHEN** the user taps a notification for chat s2 while the Kanban destination is selected
- **THEN** the Chat destination is selected
- **AND** chat s2 is open

#### Scenario: Tap while a task is open over the board

- **WHEN** the user taps a notification while a task, board management or the create form is open over the Kanban board
- **THEN** that screen is dismissed and the Chat destination is selected

#### Scenario: Tap for an unknown chat

- **WHEN** a tapped notification other than a message from Hermes names a chat that is not in the list
- **THEN** the open chat stays as it was
- **AND** the message "Could not open that chat." is shown

#### Scenario: Tap made under another profile

- **WHEN** the profile of a notification other than a message from Hermes differs from the profile currently shown
- **THEN** the open chat stays as it was
- **AND** the message "Could not open that chat." is shown

#### Scenario: Tap while the list is loading

- **WHEN** the user taps a notification for chat s2 while the chat list is still loading
- **THEN** chat s2 is selected as soon as the list has loaded

#### Scenario: Tap while another screen is open

- **WHEN** the user taps a notification for chat s2 while a secondary screen such as Profiles or Bots is open over the chat
- **THEN** chat s2 is selected
- **AND** the secondary screen stays open

#### Scenario: Cold start from a notification

- **WHEN** the app was launched by tapping a notification for chat s2
- **THEN** chat s2 is selected once the list has loaded

## ADDED Requirements

### Requirement: Messages from Hermes setting

The system SHALL offer a "Messages from Hermes" switch among the notification settings, on by default, that applies only while the general notification setting is on, and explains that it announces chats a Hermes profile starts for the user, that they arrive while the app is open or when the system lets it check in the background, and that the text is hidden while App Lock is on. Turning it off SHALL stop the looks for messages from Hermes. Turning it on again, or turning the general notification setting on again while it is on, SHALL start from a new record so that messages delivered meanwhile are not announced. The switch position SHALL be persisted across launches.

#### Scenario: Default

- **WHEN** the user opens the Notifications dialog on a fresh install
- **THEN** "Messages from Hermes" is on

#### Scenario: Off

- **WHEN** the user turns the switch off and a profile delivers a message
- **THEN** no notification is posted for it

#### Scenario: Back on

- **WHEN** the user turns it on again after messages were delivered meanwhile
- **THEN** those messages are not announced

#### Scenario: Notifications off

- **WHEN** the general "Notify me" switch is off
- **THEN** the "Messages from Hermes" switch cannot be changed

#### Scenario: Notify me back on

- **WHEN** the user turns "Notify me" on again after messages were delivered while it was off
- **THEN** those messages are not announced
