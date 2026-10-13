## Why

New messages scroll readers to the composer, and a failed outgoing message disappears. Readers need stable position and a visible way to recover their draft.

## What Changes

- Show failed outgoing messages with Retry, Edit, and Discard.
- Preserve reading position and reveal the beginning of a new answer only when following the current turn.
- Provide an explicit New reply action when an answer arrives during older-message reading.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watch`: New messages scroll readers to the composer, and a failed outgoing message disappears. Readers need stable position and a visible way to recover their draft.

## Impact

ios/HermesWatch/ConversationView.swift and Core/ConversationModel.swift. Depends on reliability send identity, ambiguous delivery, correlated recovery, and attempt guards. Reading-position work is independent of a server upgrade.

### Non-goals

Server cancellation, infinite chat history, automatic resend, cross-device draft synchronization.

### Security and privacy

The watch receives no tokens. Sensitive text remains outside telemetry. Logout and identity change clear private watch state. App Lock additionally clears and blocks inline request details and answer drafts. Existing secure-storage and concurrent-401 behavior remain intact. Request detail changes do not expand the surface snapshot.

### Observability

Reuse content-free watch relay start/completion events and native operation/result logs. New relay operations, when present, become fixed operation values in those events. No new exported UI events or breadcrumbs are needed for local presentation. Test that logging failures cannot change results and fields never include text, audio, titles, profile names, addresses, or identifiers.
