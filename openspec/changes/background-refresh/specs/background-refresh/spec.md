# Spec Delta

## Purpose

Describes the app's periodic background runs on iOS and Android:

- when the app schedules them;
- how a run looks for open requests and notifies about new ones without repeating itself;
- how a run refreshes the surface snapshot and its readers;
- the time budget, and the limits of running when the system decides.

## ADDED Requirements

### Requirement: Scheduling background runs

On iOS and Android, while someone is signed in, the app SHALL ask the system for periodic background runs, no more often than every 15 minutes and only with a network connection. It SHALL cancel them when the user signs out, the session expires or the server is changed. The system decides when, and whether, a run happens, and the app SHALL NOT promise any timing. A refusal by the system SHALL NOT affect the app. Other platforms SHALL NOT schedule background runs.

#### Scenario: Signed in

- **WHEN** the user signs in on iOS
- **THEN** a periodic background run is requested

#### Scenario: Signed out

- **WHEN** the user signs out
- **THEN** no further background runs are made

#### Scenario: Background App Refresh off

- **WHEN** the user turned Background App Refresh off for Hermes in iOS Settings
- **THEN** no runs happen and the app otherwise works as before

### Requirement: Open requests in the background

Each run SHALL list every profile's live sessions on the gateway and read the pending approvals of each session that waits for the user.

- For each approval not announced before, it SHALL post a notification on that chat with the body "Waiting for your approval".
- For a waiting session without a pending approval, it SHALL post "Waiting for you in Hermes", once per wait.

The device SHALL remember announced requests, so a later run does not announce them again. An approval or question notification SHALL use the same notification category and actions as one posted in front. Notifications SHALL follow the lock-screen rules of the notifications spec, and SHALL NOT be posted while notifications are off.

#### Scenario: Approval raised after the user left

- **WHEN** the agent asks for approval in chat A while the app is suspended and a background run happens
- **THEN** one notification "Waiting for your approval" is shown for chat A, without the command

#### Scenario: Next run

- **WHEN** the next background run sees the same approval still pending
- **THEN** no new notification is posted

#### Scenario: Notifications off

- **WHEN** notifications are turned off in the app and a run finds an approval
- **THEN** nothing is posted

### Requirement: Snapshot refresh in the background

Each run SHALL rebuild and store the surface snapshot with:

- every profile's recent chats;
- the open requests the run found across all profiles, replacing the previous list;
- Kanban and schedules.

The snapshot's privacy rules apply. With App Lock on, the stored snapshot SHALL omit chat titles and snippets (counts stay) and the Spotlight index SHALL be cleared instead of refreshed. When the run could not read the requests, the previous open requests SHALL be kept. The readers registered for snapshot writes, such as the Spotlight index, SHALL be run.

#### Scenario: Widget after a run

- **WHEN** a run finds an approval in profile `work`
- **THEN** the stored snapshot lists it as pending in `work`

#### Scenario: App Lock on

- **WHEN** App Lock is on and a run refreshes the snapshot
- **THEN** the snapshot holds counts but no chat title or snippet, and Spotlight holds no Hermes chats

#### Scenario: Requests unreadable

- **WHEN** the gateway cannot be reached during a run but REST answers
- **THEN** the snapshot's chats, Kanban and schedules are updated and its open requests stay as before

### Requirement: Opening the oldest request from the snapshot

A `hermes://requests` link SHALL open the chat of the oldest open request in the stored snapshot, in any profile. When the snapshot lists none, it SHALL fall back to the chats the app has loaded.

#### Scenario: Request in another profile

- **WHEN** the snapshot's oldest open request is in profile `work` while the app shows `default`, and the user opens `hermes://requests`
- **THEN** the app switches to `work` and opens that chat

### Requirement: Budget and failure isolation

A run SHALL finish within about 25 seconds, as iOS allows about 30. The run's checks SHALL be independent, so one failing or slow check does not stop the others. A run SHALL handle each outcome of headless work explicitly: when signed out, it SHALL post nothing and cancel further runs; when locked or unreachable, it SHALL do nothing and leave runs scheduled. It SHALL NOT sign the user out. A run SHALL report success to the system, whatever its outcome.

#### Scenario: Nobody signed in

- **WHEN** a run finds no stored session
- **THEN** nothing is posted and the app cancels further background runs

#### Scenario: Phone not unlocked since restart

- **WHEN** a run happens before the first unlock after a restart
- **THEN** nothing is posted, the snapshot is unchanged, and later runs stay scheduled

#### Scenario: Server down

- **WHEN** the server is unreachable during a run
- **THEN** nothing is posted, the snapshot is unchanged and the user stays signed in

### Requirement: Telemetry without content

Each run SHALL record its `background.task` span with the task `refresh`, the outcome, the count of new requests and the count of failed checks, and SHALL send the span before the run ends. A refused schedule request SHALL be logged as `background.refresh.schedule_failed`, with the error type and the platform. No title, id, profile name or text SHALL be recorded.

#### Scenario: Run with telemetry on

- **WHEN** a run announces one approval
- **THEN** its span says `requests.new: 1` and holds no chat id or title

### Requirement: Backend contract

Background runs SHALL rely on these gateway methods:

- `session.active_list`: params `profile`; result `sessions[]` with `id`, `session_key`, `title`, `last_active` and `status`, one of `idle`, `starting`, `waiting`, `working`, `streaming`, `resuming`;
- `approval.pending`: params `session_id`, `profile`; result `approvals[]` with `request_id`.

They SHALL also rely on the REST routes of the surface snapshot. They SHALL need no Hermes route or RPC method beyond those, and no Hermes version older than the one whose gateway contract lists these methods.

#### Scenario: Hermes without approval.pending

- **WHEN** the server answers `approval.pending` with a method-not-found error
- **THEN** waiting sessions are announced as "Waiting for you in Hermes" and the other checks run as usual
