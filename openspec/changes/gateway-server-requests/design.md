## Context

Two forms of the same prompts exist in the wild:

- **Event form** (Hermes before 2026-09-14, and the version the contract test pins): the server emits `approval.request`, `clarify.request`, `secret.request`, `sudo.request` as `event` notifications carrying a `request_id`, and the client answers with `approval.respond` or `clarify.respond`. Expiry is `<kind>.expire {request_id}`.
- **Server-request form** (Hermes from 2026-09-14): the server sends a JSON-RPC request `{id: "srq-…", method: "approval" | "clarify" | "sudo" | "secret" | …, params: {session_id, …}}` and the client answers with `{id, result}` or `{id, error}`. A withdrawn request is announced by the event `request.cancel {id, method, reason}`. The server only sends these to a connection that announced `client.capabilities {server_requests: true}`.

The app implements the event form only.

## Decisions

**Support both, decided per message.** No version negotiation: whichever form arrives is handled. The two forms never describe the same prompt on one connection, because a server sends the server-request form only to connections that announced the capability, and announces nothing in the event form.

**Announce once per connection, and ignore failure.** The announcement is a normal JSON-RPC request sent right after the socket opens, before any session call. A server that predates the method answers with an error; that error is swallowed and the connection carries on in the event form. The announcement is a `GatewayRpcClient`/transport concern and does not appear in `ChatTransport`.

**The card's request id is the frame id.** For the server-request form the `ApprovalRequest`, `ClarifyRequest` and `UnsupportedRequest` get the frame's `id` (`srq-…`) as `requestId`. Everything above the transport (cards, expiry, the chat screen) already keys on `requestId` and needs no change. The approval params' own `request_id` (the approval queue's id) is not used. The transport remembers, per open request, its runtime session and which form it came in, so answering picks the right path.

**Answering.**

- Approval: response frame `{id, result: {choice}}`. The frame path does not say whether the request had already ended, so an answer is reported as accepted; a request that ended earlier was already locked by its `request.cancel`.
- Single clarify question: response frame `{id, result: {answer}}` (`answers` is not used).
- One question of a batch: `clarify.lock {request_id: <frame id>, question_id, answer}`; a result of `status: expired` means not accepted. The lock that answers the last question resolves the request on the server.
- Secret and sudo: never answered.

**Unhandled methods get -32601 at once.** Announcing the capability opts the app into every server-to-client method, including desktop bridges it has no handler for. The documented reply for those is the JSON-RPC error -32601; the server then stops waiting at once. Answering them with an empty value instead would tell the agent the user declined, which is not what happened.

**`request.cancel` maps to the existing expiry event.** It carries the frame id, which is the card's `requestId`, so it becomes `InputRequestExpired(id)`.

**Request frames are matched to the reply's session by `params.session_id`,** like events are matched by their session id, so a request for another runtime session on the same connection is not shown in this reply.

## Platforms and invariants

All platforms are affected equally: it is Dart in the gateway client, with no native, manifest, entitlement or Xcode change. The design touches no auth, token-storage, API-layering or telemetry invariant: the socket is opened exactly as before and no REST call is added.

## Risks

- The server-request form is only known from the Hermes source (`tui_gateway/server_requests.py`, `tui_gateway/contracts/server_requests.py`) and from the pinned contract-test version's event form; it is not exercised against a running gateway of the new form. The tests drive a fake gateway written from that source.
- Requests open when a session is resumed are not replayed. A prompt raised before the app attached is not shown; it stays open until its deadline.
