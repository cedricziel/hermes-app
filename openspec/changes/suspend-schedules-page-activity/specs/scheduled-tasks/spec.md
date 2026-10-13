## ADDED Requirements

### Requirement: Retained scheduled-task page work suspends with session activity

When its supplied session activity is inactive, the retained scheduled-task page SHALL stop periodic refresh and SHALL start no protected list, profile, job or run lookup, pause, resume, trigger or delete request. Work retired by any activity notification SHALL neither publish later results nor dispatch follow-up work, even if activity resumes immediately. Suspended or retired command and auxiliary-read outcomes SHALL reject with a typed StateError rather than report success or return an obsolete object. Existing UI callers SHALL quietly drop this cancellation without stale success feedback, navigation or delayed follow-up reads. Existing callers without a supplied activity signal SHALL retain their behavior while alive.

The page SHALL retain its local filter, profile scope and selected job during recoverable inactivity. Resuming authorized activity SHALL freshly read a previously opened page, clear optimistic pending markers and avoid replaying commands or queued external open requests. A destination never opened SHALL remain unloaded on resume. Owner/UI integration SHALL retain drafts only for the same verified account after expiry and SHALL dispose and clear retained state on explicit departure; this component does not implement that integration.

The backend contract SHALL remain the existing generated `GET /api/profiles/active`, `GET /api/profiles`, cron job list/detail/run reads, pause/resume/trigger POSTs and job DELETE. Existing parsed job/profile/run response shapes and the existing minimum Hermes version supporting those routes SHALL remain unchanged.

#### Scenario: Inactive page action
- **WHEN** a paused page receives a command or auxiliary read request
- **THEN** it rejects the outcome and sends no protected request

#### Scenario: Timer suspension and recovery
- **WHEN** a previously opened page suspends and then resumes
- **THEN** no minute polling occurs during inactivity, a fresh read starts on recovery, and local filter, scope and selection remain

#### Scenario: Late completion after immediate recovery
- **WHEN** an old command or lookup completes after suspension and recovery
- **THEN** it cannot alter the fresh page or report an obsolete successful outcome

#### Scenario: Listener suspends before dispatch
- **WHEN** a listener suspends activity during a loading or optimistic-state notification
- **THEN** no protected request starts from the invalidated continuation

#### Scenario: Nested activity delivery
- **WHEN** an earlier activity listener immediately resumes during suspension delivery
- **THEN** work from before the delivered notifications remains retired

#### Scenario: Unopened destination
- **WHEN** activity resumes before the destination has ever been opened
- **THEN** the page sends no list request

#### Scenario: Retired callback completion
- **WHEN** a page callback awaits a command, profile lookup or run-history delay that belongs to a retired activity period
- **THEN** cancellation is handled quietly and no stale feedback, navigation or follow-up request occurs
