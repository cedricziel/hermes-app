## ADDED Requirements

### Requirement: Notifications respect protected screens

The system SHALL keep a notification's target unapplied until routes above the signed-in shell allow dismissal. This SHALL cover session taps, unsent-question prompts, scheduled-job notifications, and initial launch notifications. A protected editor SHALL retain its draft and error if saving fails. Keeping the editor open SHALL retain the latest target without repeatedly prompting; successful save or explicit dismissal SHALL release it once.

#### Scenario: Tap while editing
- **WHEN** a notification arrives while a dirty editor is open
- **THEN** the existing discard confirmation is used and the underlying chat/destination remains unchanged until dismissal

#### Scenario: Save fails
- **WHEN** a notification waits behind an editor whose save fails
- **THEN** the editor retains its draft and error, and the target remains pending

#### Scenario: Unsent question
- **WHEN** a notification carrying an unsent question arrives over a protected screen
- **THEN** no new chat or draft is created until that screen allows dismissal

#### Scenario: Scheduled job
- **WHEN** a job notification arrives over a protected screen
- **THEN** Schedules and the job detail are not opened before dismissal

### Requirement: Notification ordering preserves the latest intent

The system SHALL deliver only the latest pending external navigation request after a guard closes. An older launch notification resolving after a warm tap SHALL NOT supersede that tap. A newer notification or link SHALL invalidate older navigation requests held for destination discovery.

#### Scenario: Several taps while editing
- **WHEN** two notification targets arrive while the editor remains open
- **THEN** closing the editor delivers only the later target

#### Scenario: Delayed launch notification
- **WHEN** a warm tap arrives before an older launch lookup completes
- **THEN** the warm target is retained and the launch target does not change selection

#### Scenario: Availability-held request is superseded
- **WHEN** a newer notification or link arrives while an older request waits for destination discovery
- **THEN** later discovery does not deliver the older request

### Requirement: Notification delivery rechecks navigation conditions

The system SHALL hold notification delivery while App Lock covers the app, including during launch, and resume after unlock. It SHALL cancel queued work when the signed-in shell is disposed. Schedule targets SHALL wait while availability is unknown and SHALL be ignored when Schedules is known to be unavailable. Ordinary session notifications SHALL retain existing profile matching and SHALL NOT fetch sessions absent from the loaded list.

The backend contract SHALL remain the existing chat and scheduled-task contracts, including GET /api/sessions, GET /api/sessions/{id}/messages, and GET /api/cron/jobs/{id} with existing profile scoping and response shapes. No additional RPC, response shape, or minimum Hermes version SHALL be required.

#### Scenario: App Lock
- **WHEN** a notification arrives while locked or the app locks before delivery
- **THEN** it changes no chat/profile/draft until unlock

#### Scenario: Unavailable schedules
- **WHEN** availability is confirmed false before a queued job target is delivered
- **THEN** the app ignores it without selecting Schedules

#### Scenario: Shell disposal
- **WHEN** the signed-in shell is disposed before delivery
- **THEN** its queued notification work is cancelled

#### Scenario: Missing session
- **WHEN** an accepted ordinary session notification names a chat outside the loaded list or another profile
- **THEN** the existing failure behavior is preserved without fetching that session
