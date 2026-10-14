## Why

Preserving drafts during same-account sign-in requires a stable chat transport that can suspend activity without reusing a terminally closed gateway. This change supplies that lifecycle boundary before retained screens are introduced.

## What Changes

- Add a renewable transport proxy that rejects new work while suspended and fences stale completions.
- Cancel active streams before closing the old delegate; resume with a fresh delegate.
- Expose gateway RPC access through a capability interface.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: Define the suspended transport boundary used by retained chat sessions.

## Impact

Affected code is the transport contract, proxy, gateway capability declaration, and focused tests. No new backend methods, response shapes, minimum Hermes version, or dependencies are required.

Non-goals: application wiring, authentication policy, retained navigators, editor drafts, auxiliary-window snapshots, and desktop history. Those remain subsequent changes.

Security and privacy: no token storage or telemetry payload changes. New requests are rejected while suspended; already dispatched server effects cannot be undone.

Observability: none added in this contract-only change. Existing delegates retain their request and connection instrumentation; lifecycle integration will own user-visible transitions.
