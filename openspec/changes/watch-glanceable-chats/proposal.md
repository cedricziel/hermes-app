## Why

The chat list lacks waiting state and profile context, and saved chats do not show when they were fetched. Users need to distinguish current state from cached information.

## What Changes

- Show the active profile for new chats.
- Add fresh known Running, Approval, and Question indicators with Unknown fallback.
- Mark updates not yet read on this watch and show saved-data freshness.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watch`: The chat list lacks waiting state and profile context, and saved chats do not show when they were fetched. Users need to distinguish current state from cached information.

## Impact

lib/src/watch/watch_request_handler.dart, ios/HermesWatch/Core/Models.swift, ChatCache.swift, ThreadListModel.swift and ThreadListView.swift. Depends on identity-scoped cache invalidation. Known waiting status depends on reliable pending-turn correlation, not on inline request details.

### Non-goals

Cross-device unread synchronization, changing server chat order or 20-thread cap, watch profile switching, continuous polling.

### Security and privacy

The watch receives no tokens. Sensitive text remains outside telemetry. Logout and identity change clear private watch state. App Lock additionally clears and blocks inline request details and answer drafts. Existing secure-storage and concurrent-401 behavior remain intact. Request detail changes do not expand the surface snapshot.

### Observability

Reuse content-free watch relay start/completion events and native operation/result logs. New relay operations, when present, become fixed operation values in those events. No new exported UI events or breadcrumbs are needed for local presentation. Test that logging failures cannot change results and fields never include text, audio, titles, profile names, addresses, or identifiers.
