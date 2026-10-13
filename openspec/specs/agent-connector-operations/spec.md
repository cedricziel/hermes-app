# Agent connector operations specification

## Purpose

Defines connector operation cards in the Hermes app so users can inspect backend-reported activity without changing the agent protocol.

## Requirements

### Requirement: Operation snapshots retain ordered target state

The app SHALL identify operations by owner and op_id within their server and profile, and accept newer seq snapshots only. It SHALL show target name, action, state, and available detail or instructions in expandable details. A connection.update received before connection.request SHALL still render its complete snapshot. Settled operations SHALL disable responses. Unknown target kinds SHALL be shown as unavailable for action.

#### Scenario: A stale operation update arrives

- **WHEN** seq 3 follows accepted seq 4
- **THEN** the seq 4 snapshot remains authoritative

### Requirement: Only supported responses are offered

The app SHALL offer an explicit browser-open action only for a valid HTTPS connect_url with no embedded credentials. It SHALL not claim connected because the browser opened or returned. For targets that support the existing response contract, Skip SHALL send the corresponding skipped target outcome through connection.respond, and Continue SHALL use settled_by continue. The app SHALL disable duplicate submissions while awaiting the RPC result and display refusal without optimistic settlement. Targets requiring env values or unsupported installation actions SHALL show that this app cannot complete them.

#### Scenario: A browser connection is opened

- **WHEN** the user returns without a connected update
- **THEN** the target keeps its reported state and is not marked connected

### Requirement: Pending operations recover without invented authority

The app SHALL restore session.resume.pending_connection using its op_id, seq, deadline_at, timeout_seconds, targets, and optional tool_call_id, with the session owner derived from the attached runtime. Later update.owner SHALL remain authoritative. A reached deadline SHALL disable actions and label the card Awaiting final status until settlement is reported, rather than invent settled_by. The app SHALL not send env values or credentials.

#### Scenario: The client misses the initial request

- **WHEN** resume includes pending_connection
- **THEN** the operation card is restored with the original deadline and target states

### Requirement: Actions require current operation authority

Browser and response actions SHALL require a currently confirmed physical connection, runtime owner, and known profile. Missing or mismatched authority SHALL produce read-only details with connect URLs omitted and no browser, Skip, or Continue controls. Genuine global account updates SHALL appear only as clearly labeled connection-wide read-only activity until app-origin profile authority is established; they SHALL NOT acquire the selected conversation or profile as their owner. The app SHALL release operation details and deadline timers on connection/runtime/profile/account retirement, reclaim, conversation removal or retarget, and protected activity loss.

#### Scenario: An account update has no profile provenance

- **WHEN** a global account connection update arrives without trustworthy profile authority
- **THEN** the app shows connection-wide read-only activity with no connect URL or response action
- **AND** the selected conversation does not own that operation

#### Scenario: Scope retires before a response is sent

- **WHEN** a pending notification or request instrumentation callback retires the operation's current authority
- **THEN** no response bytes are sent and no later result can settle a replacement operation

#### Scenario: A stale displayed card is activated

- **WHEN** the user activates a card after its snapshot or attachment has been replaced
- **THEN** the old card cannot open a browser or respond for the replacement scope

### Requirement: Existing backend contract and compatibility

The app SHALL use the existing dashboard `/api/ws` JSON-RPC contract for connection.request, connection.update; session.resume.pending_connection; connection.respond. The checked-in gateway schema SHALL remain pinned to Hermes Agent commit `71d34bad1045610252eda02ee79549436896e784` in `openrpc/HERMES_REF`. The retained source audit and synthetic connector payload fixtures use commit `167e9fdb84248cd0fff80762dc57b6a914b6e930`; these automated fixtures do not establish native verification against the current schema pin or a minimum semantic release containing every required field. Older backends SHALL keep ordinary chat usable when these optional events or methods are absent. Unsupported actions SHALL be unavailable, and malformed optional payloads SHALL not break the event stream. No backend route, protocol extension, or token-storage change SHALL be required.

`connection.respond` takes required `owner`, `op_id`, and `result`, plus optional `profile`. Session owners are `{type: session, session_id}`; account owners are `{type: account}`. Result targets contain `name` and `status`; this change sends only `status: skipped`, never `env`. Explicit Continue sends `settled_by: continue`. The RPC returns `{status: ok, settled: bool}`. `session.resume.pending_connection` contains a nullable ConnectionRequestPayload.

The event shapes are:

- `connection.request`: `ConnectionRequestPayload`, required `op_id`, `seq`, `deadline_at`, `timeout_seconds`, `targets`; optional `tool_call_id`.
- `connection.update`: `ConnectionUpdatePayload`, required `op_id`, `seq`, `deadline_at`, `settled`, `targets`, `owner`; optional `settled_at`, `settled_by`, `target`, `from`, `to`, `actor`, `detail`.

#### Scenario: Optional capability is absent

- **WHEN** an older backend omits this capability or refuses an optional method as unsupported
- **THEN** ordinary chat remains usable and the app reports unavailable functionality without inventing state or submitting speculative requests
