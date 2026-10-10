# Spec Delta

## ADDED Requirements

### Requirement: Request detail in the expanded notification

On iOS, an approval notification and a clarifying-question notification SHALL carry the request's detail out of sight of the banner: for an approval its command and, when Hermes gives one, its description; for a question the first question's text, followed by "and N more questions" for a batch. The detail SHALL be cut at 1000 characters with an ellipsis. When the user long-presses or expands such a notification on an unlocked device, the expanded view SHALL show the detail below the notification's title and generic body. On a locked device the expanded view SHALL show "Unlock your iPhone to see what Hermes asks." instead. The banner, the Lock Screen text, the notification's body and the paired watch SHALL keep showing only the generic text the notification body requirement defines. Secret, sudo and unsupported-input notifications SHALL carry no detail. The detail SHALL exist only as long as the notification does: it SHALL NOT be written to the App Group, preferences or any file.

#### Scenario: Approval expanded while unlocked

- **WHEN** the agent asks for approval to run `rm -rf build` and the user long-presses the notification on an unlocked iPhone
- **THEN** the expanded view shows `rm -rf build` under "Waiting for your approval"

#### Scenario: Approval expanded while locked

- **WHEN** the user expands the same notification on a locked iPhone
- **THEN** the expanded view says "Unlock your iPhone to see what Hermes asks." and does not show the command

#### Scenario: Banner stays generic

- **WHEN** the approval notification is shown as a banner or on the Lock Screen
- **THEN** its text is "Waiting for your approval" and does not mention the command

#### Scenario: Batch of questions

- **WHEN** the agent asks three clarifying questions at once and the user expands the notification while unlocked
- **THEN** the expanded view shows the first question followed by "and 2 more questions"

#### Scenario: Secret request

- **WHEN** the agent asks for the secret `SERVICE_API_KEY`
- **THEN** the notification carries no detail and its expanded view shows only the generic text

### Requirement: Grouping per chat

On iOS, macOS and Android the system SHALL group notifications by chat, identified by its profile and thread id together, and notifications of a scheduled task by its profile and job id, so that notifications of one chat stack together and those of different chats, or of chats with the same id in different profiles, do not.

#### Scenario: Two chats

- **WHEN** chat A and chat B each have a notification
- **THEN** the notification centre shows them in two separate groups

### Requirement: Time-sensitive requests

On iOS and macOS, notifications for an approval, a clarifying question, a secret or sudo request and any other input the agent waits for SHALL use the time-sensitive interruption level, so that they are delivered during a Focus that allows time-sensitive notifications. Reply and scheduled-task notifications SHALL use the default level.

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

The system SHALL record a `notification.badge` breadcrumb with `count` (`0`, `1`, `2-5` or `6+`) when the badge's bucket changes. It SHALL NOT record the request detail, chat titles, profile names or ids, and the expanded view SHALL record nothing.

#### Scenario: Badge crumb

- **WHEN** the badge goes from 0 to 3
- **THEN** a `notification.badge` crumb with `count: 2-5` is added and nothing else about the requests
