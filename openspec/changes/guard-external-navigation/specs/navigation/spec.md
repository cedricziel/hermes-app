## Purpose

Keep navigation to linked app content safe while an editor or busy operation protects the current screen.

## ADDED Requirements

### Requirement: Deep links respect route dismissal guards

The system SHALL dismiss routes above the signed-in shell using their existing Back behavior before applying a deep link. It SHALL NOT change the destination, selected chat, profile, composer, or dictation because of that link until those routes have closed. If a route refuses dismissal, the latest link SHALL remain pending until the route closes. A newer link SHALL replace an older pending link without opening another discard confirmation.

#### Scenario: Keep editing
- **WHEN** a deep link arrives over a dirty editor and the user chooses Keep editing
- **THEN** the editor and its draft remain intact and the link stays pending
- **AND** the underlying destination and chat are unchanged

#### Scenario: Discard and continue
- **WHEN** the user allows the guarded editor to close
- **THEN** the app dismisses any remaining routes through their Back behavior and applies the latest pending link once

#### Scenario: Save after keeping the editor open
- **WHEN** the user saves the editor successfully after choosing Keep editing
- **THEN** the editor closes and the latest pending link is applied

#### Scenario: Save fails while a link waits
- **WHEN** a deep link arrives while an editor save is running and that save fails
- **THEN** the editor retains the draft and error, and the link stays pending until the editor closes

#### Scenario: Busy operation
- **WHEN** a route blocks Back while an operation runs
- **THEN** the link remains pending without forcing the route closed

### Requirement: Delayed links revalidate navigation conditions

Before delivering a delayed link, the system SHALL recheck App Lock and the destination's availability. A link SHALL remain held while App Lock covers the app. A destination no longer offered SHALL be ignored. Disposing the signed-in shell SHALL cancel its queued navigation work. Existing link target validation and backend routes/RPC methods SHALL remain unchanged; this feature SHALL require no additional Hermes version or API contract.

#### Scenario: Lock covers the app while editing
- **WHEN** the app becomes locked before the guarded route closes
- **THEN** the link starts no chat work or dictation until unlock

#### Scenario: Destination disappears
- **WHEN** a pending Kanban or Schedules link becomes unavailable before delivery
- **THEN** it is ignored without selecting that destination

#### Scenario: Shell is disposed
- **WHEN** authentication teardown disposes the shell while a link waits
- **THEN** its pending action is never delivered to a replacement shell
