# Spec Delta

## Purpose

Defines how a chat presents agent activity outside the transcript, sorted by what it asks of the user, so that only activity with something to report takes space from the conversation.

## ADDED Requirements

### Requirement: Activity is sorted into three tiers

The app SHALL assign every kind of chat activity it presents outside the transcript to exactly one tier:

- **Needs you**: activity that waits on the user: billing verification details for a pending request; a connector operation the user can still act on (unsettled, with current authority and at least one offered action); a reclaimed session that can be reopened.
- **Working**: live activity of the session: transient status lines (`status.update`, including memory recall), goal, loop and heartbeat control state, the todo plan, background process output, mixture-of-agents progress and session resume progress.
- **For reference**: activity worth knowing but never urgent: session usage, side results (`/btw`, `/background`), session notices and keyed notifications, the identity-free session acknowledgement, connection-wide read-only connector activity, settled or read-only connector operations, and the billing grant result.

An activity that changes state SHALL move to the tier of its new state, for example a connector operation that settles moves from Needs you to For reference.

#### Scenario: A connector operation settles

- **WHEN** a connector operation that offered Skip and Continue reports a settled snapshot
- **THEN** it is no longer Needs you and is presented as For reference

#### Scenario: A connection-wide account update arrives

- **WHEN** a connection-wide read-only connector update arrives without profile authority
- **THEN** it is For reference and is never presented as Needs you

### Requirement: Empty and unknown states draw nothing

The app SHALL NOT draw a row, card or label for an activity kind whose state is empty, unknown or unsupported by the server. In particular it SHALL NOT show "Plan unavailable" when no plan state was ever received, an unsupported-usage row when `session.usage` is not offered, or a billing-unavailable row when `billing.step_up` is not offered. When every activity kind of a chat is empty, the chat SHALL take no space for activity between its header and its transcript. A state that had a value before and has become stale or malformed SHALL keep the stale or unavailable label its own capability defines.

#### Scenario: A chat on an older server

- **WHEN** a chat is opened on a server that offers neither `session.usage` nor `billing.step_up` and sends no plan
- **THEN** the transcript starts directly below the chat header

#### Scenario: Known usage goes stale

- **WHEN** usage was shown and the connection then closes
- **THEN** the last values stay visible with their stale label

### Requirement: No new backend contract

The tiers SHALL be derived only from the existing dashboard `/api/ws` JSON-RPC frames and methods the agent-visibility capabilities already consume (OpenRPC baseline Hermes Agent commit `71d34bad1045610252eda02ee79549436896e784`, recorded in `openrpc/HERMES_REF`). No backend route, protocol extension or minimum Hermes version SHALL be introduced. A server that sends none of these frames SHALL show no activity at all.

#### Scenario: A server sends no activity frames

- **WHEN** a turn completes with only message frames
- **THEN** no activity tier draws anything and chat works as before
