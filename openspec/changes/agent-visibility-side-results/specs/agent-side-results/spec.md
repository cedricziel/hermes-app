## Purpose

Defines side agent answers in the Hermes app so users can inspect backend-reported activity without changing the agent protocol.

## ADDED Requirements

### Requirement: Side results remain separate from the main answer

The app SHALL show background.complete and btw.complete using task_id and text, preserving optional question on a btw card. It SHALL identify the result type and expose answer details without appending the result to the main assistant answer. A side completion SHALL NOT finish, restart, or fail the main turn. The combined activity header SHALL remain bounded and scrollable when several cards are expanded, leaving the conversation and composer usable.

#### Scenario: A side question completes during the main turn

- **WHEN** btw.complete arrives with answer text
- **THEN** a separate answer card appears and the main turn keeps streaming

#### Scenario: Expanded activity in a short chat window

- **WHEN** usage, a todo plan, and a side answer are expanded together in a short window
- **THEN** details remain reachable by scrolling without overflow and the chat and composer remain usable

### Requirement: Replay does not duplicate side results

The app SHALL identify a side result by owning server, profile, session, event kind, and task_id. Repeated delivery SHALL update the same card. Missing or empty task_id SHALL be ignored safely. An empty text SHALL use a neutral empty-result label rather than imply failure. Only results actually received or present in the durable transcript SHALL appear after reopening.

#### Scenario: A completion replays after reconnect

- **WHEN** the same task_id and kind arrive again
- **THEN** one side result card remains

### Requirement: Results arriving between turns remain visible

The app SHALL render a side completion for a session it is already following while no main reply is active. It SHALL associate the result with that session and SHALL NOT start a synthetic main turn or dispatch a queued prompt because the event arrived.

#### Scenario: A background task finishes after the main reply

- **WHEN** background.complete arrives on the followed session
- **THEN** the side result appears without changing queue delivery or main reply status

### Requirement: Current ownership protects side details

The app SHALL accept side results only for a currently confirmed owning connection, runtime, profile, and conversation. It SHALL clear received details on connection loss or replacement, runtime reclaim, profile replacement, conversation removal, or protected activity retirement. A notification that retires ownership during event handling SHALL prevent application of the result. Same-connection takeover of the same runtime and profile SHALL preserve received results. Reconnection SHALL display only results actually received again through authorized replay or live delivery.

#### Scenario: A queued old frame arrives after ownership replacement

- **WHEN** an old physical connection's side result arrives after the owning connection or profile changes
- **THEN** it cannot replace the current conversation's side results

#### Scenario: Protected activity retires during binding

- **WHEN** an ownership notification locks or retires the protected conversation during side-result handling
- **THEN** the result is not applied and previously received details are cleared

### Requirement: Existing backend contract and compatibility

The app SHALL use the existing dashboard `/api/ws` JSON-RPC contract for background.complete, btw.complete. The tested baseline SHALL be Hermes Agent commit `167e9fdb84248cd0fff80762dc57b6a914b6e930`, recorded in `openrpc/HERMES_REF`; a minimum semantic release containing every required field is not established. Older backends SHALL keep ordinary chat usable when these optional events or methods are absent. Unsupported actions SHALL be unavailable, and malformed optional payloads SHALL not break the event stream. No backend route, protocol extension, or token-storage change SHALL be required.

The event shapes are:

- `background.complete`: `SideAgentCompletePayload`, required `task_id`, `text`; optional `question`.
- `btw.complete`: `SideAgentCompletePayload`, required `task_id`, `text`; optional `question`.

#### Scenario: Optional capability is absent

- **WHEN** an older backend omits this capability or refuses an optional method as unsupported
- **THEN** ordinary chat remains usable and the app reports unavailable functionality without inventing state or submitting speculative requests
