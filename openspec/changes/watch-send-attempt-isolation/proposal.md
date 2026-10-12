## Why

Stopping a wait currently invalidates the local attempt, but a late successful reply can still replace the thread identity and append an answer. The next send can therefore display an answer from an abandoned local wait.

## What Changes

- Reject every stale send response before it changes conversation state.
- Keep Stop waiting local. It stops polling without cancelling the server turn.
- Cover completion, failure, and waiting replies that arrive after a new attempt starts.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watch`: Add local send-attempt isolation.

## Impact

Touches `ios/HermesWatch/Core/ConversationModel.swift` and its Swift tests. Depends on the implemented waiting behavior in `actionable-request-notifications`, whose unarchived delta differs from the main watch spec. This additive requirement does not replace its waiting contract.

Non-goals: server cancellation, persistent recovery, voice review, and approval controls.

Security and privacy: no new storage or tokens. Stale replies cannot restore conversation metadata after local invalidation.

Observability: none. This bounded state guard has deterministic tests and existing request diagnostics already describe transport outcomes.
