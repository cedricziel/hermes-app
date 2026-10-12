## ADDED Requirements

### Requirement: Auxiliary windows stop at the session boundary

On macOS, loss of protected session access SHALL invalidate auxiliary-window requests and start closing conversation/quick-panel processes before asynchronous credential cleanup completes. Suspended or retired windows SHALL NOT receive credentials, expose the current profile, select main-window targets, or complete native creation into a newer session. New windows SHALL wait until preceding native teardown completes.

No backend route, response shape, RPC method, minimum Hermes Agent version, or native entitlement change SHALL be required. The main process SHALL remain the sole native-window credential/refresh owner.

#### Scenario: Credential cleanup is slow
- **WHEN** protected access is suspended while stored-token deletion is held
- **THEN** native windows begin closing immediately and old native requests/actions are rejected

#### Scenario: A late native operation completes
- **WHEN** a creation, header lookup, or saved-state write completes after suspension/departure
- **THEN** it cannot open or authenticate old-owner content, overwrite newer-owner restoration state, or close a newly restored window

#### Scenario: An owner returns after expiry
- **WHEN** a usable verified owner returns after expiry
- **THEN** matching saved conversation targets can restore after old native teardown, without persisting native-window drafts
