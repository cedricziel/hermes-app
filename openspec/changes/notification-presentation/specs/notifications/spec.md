# Spec Delta

## ADDED Requirements

### Requirement: Grouping per chat

On iOS, macOS and Android the system SHALL group notifications by chat, identified by its profile and thread id together, and notifications of a scheduled task by its profile and job id, so that notifications of one chat stack together and those of different chats, or of chats with the same id in different profiles, do not.

#### Scenario: Two chats

- **WHEN** chat A and chat B each have a notification
- **THEN** the notification centre shows them in two separate groups

### Requirement: Time-sensitive requests

On iOS and macOS, notifications posted under a request category (`hermes.request.approval.<choices>`, `hermes.request.approval`, `hermes.request.question`, `hermes.request.question.<hash>` or `hermes.request.questions`), and notifications for a secret or sudo request and any other input the agent waits for SHALL use the time-sensitive interruption level, so that they are delivered during a Focus that allows time-sensitive notifications. Reply and scheduled-task notifications SHALL use the default level.

#### Scenario: Approval during a Focus

- **WHEN** a Focus that allows time-sensitive notifications is on and the agent asks for approval
- **THEN** the approval notification is delivered immediately

#### Scenario: Reply during a Focus

- **WHEN** the same Focus is on and a reply completes
- **THEN** the "Reply ready" notification is held like any other app's notification

### Requirement: Open-request badge

On iOS, on macOS (the Dock icon) and on Android launchers that support badges, the app icon SHALL show the number of requests waiting for the user (approvals, questions and other input) across all profiles, as known from the latest list of pending requests the app built. The badge SHALL be removed when the number is zero, when nobody is signed in, after sign-out, and while Hermes notifications are turned off. The badge SHALL be updated whenever the pending list changes, including when it is rebuilt in the background, and SHALL NOT be changed when the number is unchanged. On launchers or platforms without badge support nothing SHALL happen and no error SHALL reach the user.

#### Scenario: Two requests waiting

- **WHEN** one approval in profile `default` and one question in profile `work` are waiting
- **THEN** the app icon shows 2

#### Scenario: Request answered

- **WHEN** the user answers one of them in the app
- **THEN** the app icon shows 1

#### Scenario: Sign-out

- **WHEN** the user signs out
- **THEN** the badge is removed

#### Scenario: Notifications off

- **WHEN** the user turns Hermes notifications off while two requests wait
- **THEN** the badge is removed

### Requirement: Telemetry for notification presentation

The system SHALL record a `notification.badge` breadcrumb with `count` (`0`, `1`, `2-5` or `6+`) when the badge's bucket changes. It SHALL NOT record request text, chat titles, profile names or ids.

#### Scenario: Badge crumb

- **WHEN** the badge goes from 0 to 3
- **THEN** a `notification.badge` crumb with `count: 2-5` is added and nothing else about the requests
