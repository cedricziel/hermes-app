## Purpose

Explain mobile notification delivery limits and show account-scoped background check status without promising that the operating system will schedule or display an alert.

## ADDED Requirements

### Requirement: Mobile delivery capability display

On iOS and Android, notification settings SHALL distinguish notification permission from periodic background-refresh capability. Unknown capability SHALL display as unknown, not enabled. iOS SHALL display available, denied, or restricted background-refresh state when the system provides it. Android SHALL display whether periodic work is registered when known and SHALL NOT describe registration as proof that work will run. The settings SHALL explain that checks can run late or never and that opening the app refreshes current agent state. Desktop and watchOS SHALL NOT gain a periodic refresh scheduler through this change.

#### Scenario: iOS refresh disabled

- **WHEN** notifications are permitted but Background App Refresh is denied
- **THEN** settings show those states separately and explain that periodic checks are unavailable

#### Scenario: Android work registered

- **WHEN** Android reports the refresh task registered
- **THEN** settings show registration without promising a check interval

#### Scenario: Native capability unavailable

- **WHEN** a native query cannot return its capability
- **THEN** settings show unknown without signing the user out or displaying a success state

### Requirement: Last check outcomes

Settings SHALL show the last attempted check time, last completed check time, and latest known outcome for the current server and account. Outcomes SHALL distinguish completed, partial, locked, unreachable, signed out, and interrupted-or-incomplete attempts. A completed check SHALL mean the check finished its expected work, not that a notification reached the user. The status record SHALL contain only timestamps, an account identity hash, a content-free generation marker, and fixed outcomes. It SHALL clear on sign-out or server change. Writing or reading status SHALL NOT affect background work when storage fails.

#### Scenario: First use

- **WHEN** no check record exists for the current identity
- **THEN** settings show that no check has been recorded

#### Scenario: Task interrupted

- **WHEN** an attempt was recorded but no terminal outcome was saved
- **THEN** settings display an incomplete check rather than success

#### Scenario: Other account

- **WHEN** the app signs in as another account
- **THEN** the former account's check status is not shown

#### Scenario: Status storage stops answering

- **WHEN** status bookkeeping does not finish within its bounded budget
- **THEN** the background check still runs and returns its existing outcome, and signed-out cancellation does not wait for completion bookkeeping

#### Scenario: Cleanup fails before the same account signs in

- **WHEN** status cleanup fails on sign-out and the same account signs in again
- **THEN** the former generation remains retired until a new active identity is saved, and an old completion cannot restore visible status

### Requirement: Foreground refresh without additional polling

Opening settings and resuming the app SHALL read the latest status and supported native capability state. Those reads SHALL NOT start an extra background check, shorten the existing 15-minute earliest requested interval, or retry authentication independently. No push registration SHALL occur.

#### Scenario: Resume after background work

- **WHEN** the app resumes after a recorded check
- **THEN** settings show its latest outcome without scheduling an immediate extra check

### Requirement: Existing backend compatibility

Status display SHALL rely on local scheduler and run outcomes only, adding no Hermes route, RPC field, or minimum backend version. Existing refresh work SHALL retain its current generated REST client and gateway contracts.

#### Scenario: Backend unreachable

- **WHEN** the backend cannot be reached during a background check
- **THEN** the attempt can be recorded as unreachable without a new status API
