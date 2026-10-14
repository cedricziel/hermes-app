## Purpose

Defines agent todo snapshots in the Hermes app so users can inspect backend-reported activity without changing the agent protocol.

## ADDED Requirements

### Requirement: Todo snapshots replace the current plan

The app SHALL keep one read-only todo snapshot per owning server, profile, and session. todo.updated SHALL replace the snapshot when revision is newer, ignore older or repeated revisions within the same runtime generation, and clear the plan when todos is empty. The app SHALL show a compact summary and expandable supported task entries. It SHALL NOT merge old tasks into a replacement.

#### Scenario: A stale todo update is replayed

- **WHEN** revision 5 follows an already accepted revision 6
- **THEN** revision 6 remains visible without duplicate tasks

### Requirement: Todo rendering requires verified item fields

The app SHALL decode task text and status only from item fields verified against a fixture with an explicit backend source revision. The current contract leaves todos items open. Unsupported item shapes SHALL show a neutral unavailable-details state and SHALL NOT fabricate titles, completion, or counts of completed tasks. Valid siblings SHALL remain visible.

#### Scenario: One task has an unsupported shape

- **WHEN** a snapshot contains valid tasks beside that task
- **THEN** valid tasks remain readable and unsupported details are identified without inferred status

### Requirement: Resume restores available plan state

The app SHALL seed the current plan from session.resume.todo_state and then apply later revisions from the same runtime. A new runtime generation SHALL reset revision comparison. Missing todo_state on a newly adopted binding SHALL mean unavailable rather than prove that no plan exists. A missing or older resume snapshot SHALL preserve a newer live plan already accepted on the same confirmed connection, runtime, and profile binding. A truncated replay SHALL use the existing resume state refresh instead of reconstructing tasks from tool prose.

#### Scenario: The runtime restarts with a lower revision

- **WHEN** resume supplies the new generation snapshot
- **THEN** the restored plan is accepted and comparison restarts for that generation

#### Scenario: A same-binding resume omits plan state

- **WHEN** a live revision 6 has already been accepted and a resume on that same confirmed binding omits todo_state
- **THEN** revision 6 remains visible

### Requirement: Existing backend contract and compatibility

The app SHALL use the existing dashboard `/api/ws` JSON-RPC contract for todo.updated; session.resume.todo_state. The verified task-item fixture baseline SHALL be Hermes Agent commit `167e9fdb84248cd0fff80762dc57b6a914b6e930`, recorded with its source checksum in `test/fixtures/gateway/todo_state.json`. The current bundled contract revision is recorded independently in `openrpc/HERMES_REF`; its todo item fields remain open. A minimum semantic release containing every required field is not established. Older backends SHALL keep ordinary chat usable when these optional events or methods are absent. Unsupported actions SHALL be unavailable, and malformed optional payloads SHALL not break the event stream. No backend route, protocol extension, or token-storage change SHALL be required.

`session.resume.todo_state` is nullable and, when present, contains `todos` as an array of open objects and integer `revision`. The todo.updated event likewise requires todos and revision, but its item schema is unconstrained. No task text or status field is guaranteed by the bundled contract.

The event shapes are:

- `todo.updated`: `TodoUpdatedPayload`, required `todos`, `revision`.

#### Scenario: Optional capability is absent

- **WHEN** an older backend omits this capability or refuses an optional method as unsupported
- **THEN** ordinary chat remains usable and the app reports unavailable functionality without inventing state or submitting speculative requests
