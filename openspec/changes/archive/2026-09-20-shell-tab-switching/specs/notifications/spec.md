## MODIFIED Requirements

### Requirement: Tapping a notification opens its chat

The system SHALL open the chat a notification was posted for when the user taps it while the app is running. When the Chat and Kanban destinations are shown, the system SHALL select Chat on every tap, including a tap whose chat cannot be opened, so that the user is not left on the Kanban board. When the tap started the app, the system SHALL open that chat once the chat list has loaded. A tap that arrives while the chat list is still loading SHALL be held and applied when the list has loaded, and SHALL take precedence over the notification that launched the app. A notification carries the chat's thread id and, when known, its profile; a notification without a profile SHALL match on the thread id alone (so a notification posted by an earlier build, whose payload is a bare thread id, still works). If the target chat cannot be opened, because it belongs to a different profile than the one currently shown or is not in the loaded list, the selection SHALL NOT change (for a launch, the first chat in the list SHALL be selected instead) and the system SHALL tell the user with the message "Could not open that chat." Opening a chat from a notification SHALL close the chat list drawer when it is open, and SHALL NOT close or pop any other screen the user has open.

#### Scenario: Tap while running

- **WHEN** the user taps a notification for chat s2 while chat s1 is open
- **THEN** chat s2 opens

#### Scenario: Tap while Kanban is shown

- **WHEN** the user taps a notification for chat s2 while the Kanban destination is selected
- **THEN** the Chat destination is selected
- **AND** chat s2 is open

#### Scenario: Tap for an unknown chat

- **WHEN** the tapped notification names a chat that is not in the list
- **THEN** the open chat stays as it was
- **AND** the message "Could not open that chat." is shown

#### Scenario: Tap made under another profile

- **WHEN** the notification's profile differs from the profile currently shown
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
