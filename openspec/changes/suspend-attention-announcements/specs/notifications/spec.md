## ADDED Requirements

### Requirement: Private chat announcements respect session suspension

While session activity is paused or disposed, the system SHALL NOT start a private chat announcement or a new device notification permission request. An announcement delayed by device permission or platform preparation SHALL NOT be delivered if session activity paused or was disposed during that delay. Resuming activity SHALL permit fresh announcements without reviving invalidated announcements.

A device permission result requested before suspension SHALL still be recorded. Notification taps and launch targets SHALL continue to be handed to the routing owner while session activity is paused.

This change SHALL preserve existing chat event and notification payload contracts. It SHALL add no backend route, RPC method, response field, or minimum Hermes version requirement.

#### Scenario: Session starts paused
- **WHEN** an announcement or device permission request is attempted while session activity is paused
- **THEN** no notification is posted and no permission prompt starts

#### Scenario: Permission result arrives after pause and resume
- **WHEN** an old announcement waits for permission and session activity pauses then resumes before the answer
- **THEN** the old announcement is discarded, the device answer is recorded, and a fresh authorized announcement may be delivered

#### Scenario: Native preparation crosses suspension
- **WHEN** session activity pauses or is disposed while notification preparation is pending
- **THEN** the final platform dispatch rejects the invalidated announcement even if session activity later resumes

#### Scenario: Notification navigation arrives during pause
- **WHEN** a notification tap or held launch target arrives while session activity is paused
- **THEN** the target reaches the routing owner without being silently discarded

#### Scenario: Earlier activity listener attempts notification work
- **WHEN** an earlier listener attempts an announcement or permission request while the activity signal already contains false
- **THEN** the notifier rejects the attempt even before its own activity listener runs

#### Scenario: Earlier activity listener resumes reentrantly
- **WHEN** an earlier listener resumes activity during the pause notification before the notifier observes the intermediate value
- **THEN** old delayed announcements are invalidated and fresh authorized announcements remain available
