## Why

Questions require the same request identity and answer semantics as the phone. Contextual choices and editable text let users answer without turning a question answer into a new chat command.

## What Changes

- Show structured questions with exact offered choices, text input, and multi-select when supported.
- Submit each question answer against its request and question identity.
- Handle multiple questions sequentially with explicit progress and phone fallback for unsupported requests.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watch`: Questions require the same request identity and answer semantics as the phone. Contextual choices and editable text let users answer without turning a question answer into a new chat command.

## Impact

lib/src/watch/watch_request_handler.dart, lib/src/chat/gateway/hermes_gateway_transport.dart, ios/HermesWatch/Core relay models and ConversationView.swift. Depends on watch-inline-approvals relay foundation and watch-session-privacy, watch-context-identity, and reliable delivery/recovery changes. Contextual-actions delegates active questions to this structured view.

### Non-goals

Secret/sudo values, invented options, generic chat Yes/No answers, atomic all-questions backend contract.

### Security and privacy

The watch receives no tokens. Sensitive text remains outside telemetry. Logout and identity change clear private watch state. App Lock additionally clears and blocks inline request details and answer drafts. Existing secure-storage and concurrent-401 behavior remain intact. Request detail changes do not expand the surface snapshot.

### Observability

Reuse content-free watch relay start/completion events and native operation/result logs. New relay operations, when present, become fixed operation values in those events. No new exported UI events or breadcrumbs are needed for local presentation. Test that logging failures cannot change results and fields never include text, audio, titles, profile names, addresses, or identifiers.
