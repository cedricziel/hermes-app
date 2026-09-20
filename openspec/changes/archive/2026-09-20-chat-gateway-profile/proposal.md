## Why

The chat lists, reads and changes sessions per Hermes profile, and passes `profile` on every REST call. The gateway calls do not: `session.create` and `session.resume` are sent without one (issue #102). After the user switches the chat to another profile, a new thread is created in, and a stored thread is resumed from, the dashboard's own launch profile. A session id is only unique within a profile, so a resume can even attach to a different session than the one on screen.

## What Changes

- `session.create` and `session.resume` carry the `profile` the chat is showing, as the gateway's own `profile` parameter.
- `ChatTransport.send` takes an optional `profile`. The chat screen passes the profile the thread was listed under; the watch request handler passes the active profile it already tracks.
- When no profile is known (the dashboard did not report one), the params stay as before and the gateway uses its launch profile.
- A real-backend contract case checks that a session created and resumed under the active profile shows up in that profile's session list.

## Impact

- `lib/src/chat/chat_transport.dart`, `lib/src/chat/gateway/hermes_gateway_transport.dart`, `lib/src/chat/chat_screen.dart`, `lib/src/watch/watch_request_handler.dart`.
- Tests: `hermes_gateway_transport_test.dart`, `chat_screen_profile_test.dart`, `watch_request_handler_test.dart`, `FakeChatTransport`, and the real-backend contract test.
- No change to `openapi/` or `packages/hermes_api`: the socket is not part of the OpenAPI spec.
- Minimum Hermes version: the `profile` param on both methods is present at the `HERMES_REF` the contract workflow pins. A profile the gateway does not know is rejected by the gateway; how it reports that differs by version (see design.md).

## Non-goals

- Passing `profile` on other RPC methods (`prompt.submit`, `approval.respond`, and so on). They address a runtime session id the gateway already bound to the profile at create or resume time.
- Handling a deleted profile specially in the UI. A rejected create or resume fails the send like any other gateway error.
- Changing how the chat picks or switches profiles.

## Security and privacy impact

None on tokens or storage. The profile name is a non-secret identifier the app already sends as a query parameter on REST calls. It now also travels in the JSON-RPC params on the already authenticated socket. It is what keeps a message from being written to, and run with the credentials and configuration of, the wrong profile, so the change narrows the impact of a mix-up.

## Telemetry

None. `GatewayTelemetry` records the RPC method name and request id only, not params, so the profile name is not exported.
