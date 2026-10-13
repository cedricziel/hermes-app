# Agent process output specification

## Purpose

Defines background process output in the Hermes app so users can inspect backend-reported activity without changing the agent protocol.

## Requirements

### Requirement: Output is grouped by process identity

The app SHALL group chunks by process_id within the owning server, profile, and runtime session. A compact card SHALL identify a process as having output and provide a plain-text details tail. The app SHALL not interpret escape sequences as commands, execute markup, or open links automatically. Missing process_id SHALL be ignored safely.

#### Scenario: Two processes emit interleaved chunks

- **WHEN** the events arrive on one session
- **THEN** each details view contains only its own ordered chunks

### Requirement: Output storage is bounded

The app SHALL retain at most 64 KiB of UTF-8 output per process and at most 16 process cards per runtime session. When a limit is exceeded, it SHALL retain the newest tail at valid character boundaries and show that earlier output was omitted. Eviction SHALL prefer closed process cards; active-card eviction SHALL also disclose omission. Replay sequence deduplication SHALL prevent repeated chunks from being appended twice.

#### Scenario: A process produces more than the output limit

- **WHEN** another chunk arrives
- **THEN** the newest bounded tail remains readable and omitted output is disclosed

### Requirement: Closure does not imply success

terminal.close SHALL mark the matching process Closed. The app SHALL not display a success or failure exit result because this payload contains only process_id. A close event arriving before output SHALL create a closed placeholder that later output can populate without reopening it. Session disposal SHALL release retained buffers.

#### Scenario: A close event has no exit code

- **WHEN** terminal.close arrives
- **THEN** the card says Closed and does not claim successful execution

### Requirement: Current ownership releases process buffers

The app SHALL apply chunks and closures only for the currently confirmed physical connection, runtime, profile, and conversation. It SHALL release retained output on connection loss or replacement, runtime reclaim, profile replacement, conversation disposal, and protected activity retirement. Ownership retirement during event handling SHALL prevent application of the pending update. Same-connection takeover of the same runtime and profile SHALL preserve received buffers. Reconnection SHALL show only output actually received again through authorized replay or live delivery.

#### Scenario: An old client delivers a queued chunk

- **WHEN** the runtime ID is reused on a replacement physical connection and an old client chunk arrives
- **THEN** it cannot append to the new connection's process buffer

#### Scenario: Protected activity retires during binding

- **WHEN** a binding notification retires protected activity before a process update is applied
- **THEN** the update is not retained and previous buffers are cleared

### Requirement: Expanded output preserves the conversation viewport

Expanded process output SHALL use a bounded scrolling text viewport. The process-card group SHALL preserve usable space for the conversation transcript and composer. Omission labels SHALL remain available below the output tail and below an evicted-card group.

#### Scenario: A long process tail is expanded

- **WHEN** the user opens process details containing a long output tail
- **THEN** the output scrolls within its bounded details area and the transcript remains usable

### Requirement: Existing backend contract and compatibility

The app SHALL use the existing dashboard `/api/ws` JSON-RPC contract for agent.terminal.output, terminal.close. The current pinned contract SHALL be Hermes Agent commit `71d34bad1045610252eda02ee79549436896e784`, recorded in `openrpc/HERMES_REF`. Commit `167e9fdb84248cd0fff80762dc57b6a914b6e930` SHALL remain the retained fixture baseline; these event schemas are unchanged. A minimum semantic release containing every required field is not established. Older backends SHALL keep ordinary chat usable when these optional events or methods are absent. Unsupported actions SHALL be unavailable, and malformed optional payloads SHALL not break the event stream. No backend route, protocol extension, or token-storage change SHALL be required.

The event shapes are:

- `agent.terminal.output`: `TerminalOutputPayload`, required `process_id`, `chunk`.
- `terminal.close`: `TerminalClosePayload`, required `process_id`.

#### Scenario: Optional capability is absent

- **WHEN** an older backend omits this capability or refuses an optional method as unsupported
- **THEN** ordinary chat remains usable and the app reports unavailable functionality without inventing state or submitting speculative requests
