## Why

The watch waits for approvals and questions without explaining where the user can answer them. Stop waiting also sounds like cancellation even though the agent continues.

## What Changes

- Explain that approvals and questions can be answered in the Hermes notification or on iPhone.
- Replace Stop waiting with Leave waiting view and explain that the request remains pending.
- Keep unsupported secret and sudo input on the phone.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watch`: The watch waits for approvals and questions without explaining where the user can answer them. Stop waiting also sounds like cancellation even though the agent continues.

## Impact

ios/HermesWatch/ConversationView.swift and native fixtures. Depends on watch-conversation-usability and the reliability late-response guard; reconciles actionable-request-notifications before archive; inline approvals/questions supersede notification-only handling later.

### Non-goals

Programmatically opening notification UI, inline answers, backend cancellation.

### Security and privacy

The watch receives no tokens. Sensitive text remains outside telemetry. Logout and identity change clear private watch state. App Lock additionally clears and blocks inline request details and answer drafts. Existing secure-storage and concurrent-401 behavior remain intact. Request detail changes do not expand the surface snapshot.

### Observability

Reuse content-free watch relay start/completion events and native operation/result logs. New relay operations, when present, become fixed operation values in those events. No new exported UI events or breadcrumbs are needed for local presentation. Test that logging failures cannot change results and fields never include text, audio, titles, profile names, addresses, or identifiers.
