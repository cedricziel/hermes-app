## Purpose

Allow users to correct or permanently remove a selected profile memory through deliberate actions and existing authenticated backend routes.

## ADDED Requirements

### Requirement: Exact scoped mutation contract

The app SHALL use authenticated `PUT /api/learning/node` with `LearningNodeEdit` body `{id, content, profile}` and `DELETE /api/learning/node` with `LearningNodeRef` body `{id, profile}`. Each request SHALL also send the same explicit `profile` query value. Only a selected detail with `kind: memory` SHALL expose these actions. The baseline SHALL be bundled Hermes commit `167e9fdb84248cd0fff80762dc57b6a914b6e930`; earliest release support is unverified. A mutation success SHALL require a valid `{ok: true}` response, with optional `message`; HTTP errors, malformed bodies, and `ok: false` SHALL not count as success.

#### Scenario: Save selected memory

- **WHEN** the user explicitly saves non-blank edited full content
- **THEN** the request carries the selected opaque ID and captured profile in both body and query
- **AND** no skill entry or other profile is changed by a client-selected substitute identity

### Requirement: Editing and concurrent changes

The app SHALL preserve the user's unsaved text during a recoverable error, prevent duplicate submissions, and require an explicit discard decision before leaving a dirty editor. It SHALL refetch the selected detail before save or delete and refuse the mutation if the entry disappeared, changed kind, or no longer matches the inspected content. It SHALL not promise atomic conflict detection because the endpoints expose no revision or compare-and-swap field.

#### Scenario: Entry changes while editing

- **WHEN** the preflight read differs from the editor's original content or rejects its ID
- **THEN** the app explains the conflict, preserves the user's unsaved text, and requires refresh and a new explicit save decision
- **AND** it does not rebind the old action to another list position

#### Scenario: Blank edit

- **WHEN** the edited content contains only whitespace
- **THEN** Save is unavailable and the app offers the separate Delete action

### Requirement: Permanent deletion confirmation

The app SHALL require an explicit confirmation for the currently selected memory before DELETE. It SHALL explain permanent removal and SHALL not claim Undo or restoration. Cancellation SHALL issue no mutation request.

#### Scenario: Confirm deletion

- **WHEN** the user confirms deleting the selected memory and the server returns `ok: true`
- **THEN** the app removes the stale detail and refreshes the list
- **AND** it does not show a restore action

### Requirement: Uncertain mutation outcome

The app SHALL distinguish confirmed rejection from an uncertain transport outcome. After a timeout or lost response, it SHALL refetch the graph and selected detail before offering another mutation, preserve uncertainty when reads cannot establish the result, and SHALL never automatically repeat PUT or DELETE.

#### Scenario: Lost save response

- **WHEN** the connection closes after Save submission
- **THEN** the app preserves the draft, marks the outcome uncertain, and refreshes available state
- **AND** it does not infer success solely because the old ID disappeared or automatically save to a newly selected ID

#### Scenario: Lost delete response

- **WHEN** a delete response is lost and refresh finds the old entry absent
- **THEN** the app shows the entry is no longer present without claiming which actor removed it
- **AND** another deletion requires a new selection and confirmation

### Requirement: Mutation privacy and scope changes

The app SHALL keep drafts only in memory, clear them on sign-out, and discard them after a confirmed profile or connection switch. Late responses SHALL not alter the newly selected profile. Existing App Lock and authentication handling SHALL apply. Telemetry SHALL omit memory text, IDs, labels, profile names, and backend message strings.

#### Scenario: Profile changes during mutation

- **WHEN** a response arrives after a confirmed profile switch
- **THEN** it does not update the new profile's detail or list
- **AND** the app explains before switching that an already submitted request can still finish in its original profile
