## Why

Since 2026-09-14 (Hermes PRs #110521 and #110522), the Hermes gateway no longer sends `approval.request`, `clarify.request`, `secret.request` and `sudo.request` as event notifications answered by `*.respond` calls. It sends them as JSON-RPC requests from the server to the client and expects a response frame with the same id. A client that never says it can answer them (`client.capabilities` with `server_requests: true`) is treated as an older build: the gateway does not send the frame, and it withdraws an approval with the reason "update the Hermes app".

This app never says so. Against a Hermes updated in the last week, approvals are withdrawn, clarify questions are skipped and secret or sudo prompts never reach the user, so an agent that needs an answer stalls or proceeds without one. Servers older than that change still use the events, so both forms must keep working.

## What Changes

- The gateway connection tells the server, once per connection, that the app answers server-to-client requests. A server that does not know the method answers with an error, which is ignored.
- Server-to-client requests for an approval, a clarify question, a secret and a sudo password are shown as the same cards as their event forms. Answering an approval or a single clarify question sends a response frame with the request's id; answering one question of a batch uses `clarify.lock`.
- A request the server withdraws (`request.cancel`) locks its card as expired, the same as the per-kind expire events.
- Any other server-to-client request (vault prompts, desktop bridges, tours and so on) is answered at once with the JSON-RPC error "method not found", so the agent stops waiting for it instead of idling until its deadline.
- The event forms keep working unchanged for servers that predate the change.

Non-goals: no replay of requests already open when a session is resumed (`open_requests`); no in-app answer for secrets, sudo passwords or vault prompts; no new card kinds; no change to which Hermes version the contract test runs against.

Security and privacy impact: the sudo request carries the redacted command it is for, and the secret request a prompt, a variable name and metadata; none of these is read or shown, as before. Nothing the user types for a secret or a password is collected. The response frames carry only the user's approval choice or clarify answer.

Telemetry: None added. The `client.capabilities` call is one more gateway request and is timed by the existing per-request spans; server-to-client requests are not recorded.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: gateway session handling (the capability announcement and the server-to-client request form), the requests the app cannot answer (both forms), and the backend contract (methods, frames and events used).

## Impact

`lib/src/chat/gateway/gateway_rpc_client.dart` and `hermes_gateway_transport.dart`, and their tests. No native, API-route or generated-client change. Every platform is affected equally.
