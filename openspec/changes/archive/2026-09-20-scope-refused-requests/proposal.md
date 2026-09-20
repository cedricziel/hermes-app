## Why

Since #145 the app answers every server-to-client request it has no handler for (vault prompts, desktop bridges such as `terminal.read`, tours) with the JSON-RPC error "method not found", so the agent stops waiting at once. The gateway sends a session's requests to every client attached to that session, and the first response settles the request for all of them. The app stays attached to a session after a send, so it could refuse a request meant for another client, for example a desktop app's `terminal.read`, and break that client's feature.

## What Changes

- An unhandled request is refused only when it belongs to a session this app has a reply in flight for. Requests for any other session are left alone, so the client they are meant for can answer them.
- Nothing changes for the four requests the app handles, or while a reply of this app is streaming.

Non-goals: no change to which methods are handled; no answer for a handled request that no reply claims (the gateway waits for its deadline, as before); no detaching from a session after a reply.

Security and privacy impact: None.

Telemetry: None.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: the backend contract, for which server-to-client requests are refused.

## Impact

`hermes_gateway_transport.dart` and its test. No native, route or generated-client change; all platforms.
