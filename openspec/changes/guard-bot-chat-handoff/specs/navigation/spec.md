## ADDED Requirements

### Requirement: Bot chat handoffs respect root guards and current intent ownership

Opening a bot from its roster or menu SHALL keep the canonical target and Chat selection unapplied until protected root routes allow dismissal and App Lock permits navigation. Keeping an editor open SHALL preserve its draft and current destination. Successful save or explicit dismissal SHALL release only the current handoff.

A bot opening SHALL belong to its arrival order and captured session owner. A newer root notification, link, share, schedule handoff, Show in Main request, or bot opening SHALL supersede older unresolved bot work. A completed lookup SHALL NOT become a newer intent merely because it finished later. Loss of authorization or departure from the captured owner SHALL prevent later shell lookups, target publication, and stale failure feedback. Already dispatched canonical operations SHALL NOT be rolled back.

Existing canonical bot context, profile identity, root ID, stored compression tip, roster peers, and protocol flag SHALL be preserved. The backend contract SHALL remain the authenticated gateway's profiles.list and session.list/create/title methods and existing session/profile REST reads. Existing response shapes, bot protocol capability detection, and Hermes 0.21.4 source-verified compatibility SHALL remain unchanged; no additional minimum version is required.

#### Scenario: Bot opening arrives over a dirty editor
- **WHEN** a bot opening resolves while an editor protects the main stack
- **THEN** the editor and its draft remain, and Chat is unchanged until the guard allows dismissal
- **AND** delivery preserves the canonical bot context

#### Scenario: Owner departs during roster lookup
- **WHEN** authorization or the captured owner retires before the roster lookup completes
- **THEN** the shell starts no subsequent canonical lookup and publishes no target or stale failure

#### Scenario: A newer root intent arrives during bot resolution
- **WHEN** a notification or link arrives after a bot opening while its lookup remains pending
- **THEN** only the newer intent is applied after the protected route closes
- **AND** completing the older bot lookup cannot replace it
