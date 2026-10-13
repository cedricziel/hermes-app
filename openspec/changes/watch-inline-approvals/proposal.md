## Why

An approval can pause a watch conversation, but answering requires switching to a notification or phone. A structured approval view keeps the command and exact offered choices together.

## What Changes

- Fetch current approval details through the paired phone only after authentication and lock checks.
- Display the full command, description, and only offered choices.
- Confirm affirmative choices and submit by request identity through the shared answer path.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watch`: An approval can pause a watch conversation, but answering requires switching to a notification or phone. A structured approval view keeps the command and exact offered choices together.

## Impact

lib/src/watch/watch_request_handler.dart, lib/src/notifications/request_answers.dart, lib/src/chat/gateway/hermes_gateway_transport.dart, ios/HermesWatch/Core relay models and ConversationView.swift. After watch-request-guidance, privacy reset, connection identity, and reliable pending-turn recovery. Inline questions reuses this relay foundation.

### Non-goals

Secret/sudo answers, arbitrary Yes/No chat text as approval, adding or broadening approval choices, snapshot command storage.

### Security and privacy

The watch receives no tokens. Sensitive text remains outside telemetry. Logout and identity change clear private watch state. App Lock additionally clears and blocks inline request details and answer drafts. Existing secure-storage and concurrent-401 behavior remain intact. Request detail changes do not expand the surface snapshot.

### Observability

Reuse content-free watch relay start/completion events and native operation/result logs. New relay operations, when present, become fixed operation values in those events. No new exported UI events or breadcrumbs are needed for local presentation. Test that logging failures cannot change results and fields never include text, audio, titles, profile names, addresses, or identifiers.
