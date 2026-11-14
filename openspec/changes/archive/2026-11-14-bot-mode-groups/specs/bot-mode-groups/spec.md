## Purpose

Let users create and converse with groups of named Hermes specialists while viewing durable participant messages and controlling server-owned work.

## ADDED Requirements

### Requirement: Group roster and creation

The system SHALL display hosted group rooms in the Bots destination and allow creating a named room with 2–6 distinct bots on the connected server when the verified protocol 2 transport and driver are ready.

#### Scenario: Create and open

- **WHEN** the user creates a group
- **THEN** a searchable checklist offers local bots, validates a nonblank name and 2–6 unique members, and explains that membership is fixed for this room
- **AND** saving opens the returned hosted room; retries preserve its room identity; an empty or failed roster offers a useful action or Retry
- **AND** the creation flow explains that hosted interactive requests cannot be answered in the room and may leave a member waiting until stopped

#### Scenario: Existing groups and management

- **WHEN** the user returns to Bots
- **THEN** hosted rooms appear with names, member count, latest incorporated activity, and real pending-attention state
- **AND** the user can rename or explicitly confirm disbanding a room; a tombstoned room is removed and late replies cannot restore it

### Requirement: Attributed room conversation

The system SHALL render room history and activity from durable hosted events, and send text through the backend driver.

#### Scenario: Send, mention, and replies

- **WHEN** the user sends room text or selects a participant @mention
- **THEN** the composer sends text and the selected discussion thread identity, preserves unknown @tokens, and offers only unambiguous room-member handles
- **AND** server `message.user` and `message.member` events render with author and thread attribution; turn started/settled/failed/cancelled and room activity remain distinguishable from participant prose
- **AND** room members' backend-driven replies to one another are visible without the app invoking `message_agent` in a member session

#### Scenario: Recovery and unavailable interactions

- **WHEN** the app reconnects, resumes, or the room driver becomes unavailable
- **THEN** replay resumes without duplicate messages, history remains readable, unsent text is retained, and execution availability is explained
- **AND** unsupported attachments and membership editing are not offered; no clarify, sudo, or secret input form appears in the room

### Requirement: Room work controls

The system SHALL provide Stop, exact pending approval controls, and explicit task retry according to the server's advertised and observed contract.

#### Scenario: Working or blocked

- **WHEN** the server reports active work or an exact pending approval
- **THEN** the view names the responsible participant and offers Stop or Allow once/Deny as appropriate
- **AND** controls disable while their request is pending and stale approval coordinates are discarded after refresh

#### Scenario: Pending retry action

- **WHEN** the server advertises a pending retry action for an indeterminate or deferred task
- **THEN** the user sees the task state and confirms retry of that exact task; the app never automatically creates another prompt for it

#### Scenario: Unsupported interactive request

- **WHEN** the server reports active or blocked work without an actionable room request
- **THEN** the room explains that a member may be waiting for an interactive request that cannot be answered here and keeps Stop available
- **AND** stopping refreshes the server state and durable log without claiming the request was answered or refused

### Requirement: Group UI backend compatibility

The system SHALL use the `bot-mode-group-protocol` contract. Hermes 0.21.4 commit `35fdb4608aa8af455d2597664cff1754a3722cd1` supplies hosted protocol version 2 transport; earlier released-version compatibility is unverified. The first release SHALL enable executable groups on a ready protocol 2 driver with the required advertised transport methods and features, while showing the known interactive-input limitation.

#### Scenario: Unsupported server

- **WHEN** `groups.capabilities` lacks the required transport methods or features, reports an unsupported protocol, or has no ready driver
- **THEN** Bots remains usable for direct bot conversations, existing hosted room history stays readable, and group creation and sending show an update-required explanation
- **AND** no fallback starts a client-owned multi-agent room

#### Scenario: Hosted boundaries

- **WHEN** a compatible server provides rooms
- **THEN** listing, creation, sending, replay/status, rename, stop, approval, retry, and disband use the specified `groups.*` payloads and responses
- **AND** legacy Desktop metadata rooms are not presented as hosted rooms without an explicit migration contract
