## MODIFIED Requirements

### Requirement: Opening a thread from a notification

The system SHALL open the thread named by a tapped notification, or by the notification that launched the app, when it belongs to the profile the chat is showing. A tap SHALL NOT close a screen opened above the chat, and SHALL close the thread drawer when it is open. A tap made while the thread list is loading SHALL be held and applied after it loads.

#### Scenario: Tap opens the thread

- **WHEN** a notification for a listed thread is tapped
- **THEN** that thread is opened

#### Scenario: Other profile

- **WHEN** the notification carries another profile than the chat's
- **THEN** nothing changes except that "Could not open that chat." is shown
- **AND WHEN** it carries no profile
- **THEN** it still matches on the thread id alone

#### Scenario: Thread not listed

- **WHEN** the thread is not in the list
- **THEN** a tap changes nothing and shows "Could not open that chat."; a launch falls back to the first thread and shows the same message

#### Scenario: Tap while the list loads

- **WHEN** a notification is tapped before the thread list has loaded
- **THEN** its thread is opened once the list has loaded
