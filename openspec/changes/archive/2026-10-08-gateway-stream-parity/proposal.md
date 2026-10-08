# Proposal

## Why

A comparison with upstream Hermes (server at the ref our contract test pins, `7b3c7aef`, and at main, `65bc6727`; reference client `apps/desktop` + `apps/shared`) found that our `/api/ws` chat client handles the normal path correctly but diverges from the protocol where it matters most:

- A reply can spin forever, because some failed turns end with only an `error` event.
- A queued prompt can be folded into a turn that is just ending.
- A dropped socket silently loses streamed text, tool results and approvals.
- A final already shown as an interim renders twice.

Every protocol feature these fixes need already exists at the pinned ref, so this is client work only.

## What Changes

- **Turn settling.** A turn ends on `message.complete`, an `error` event, or `session.info {running: false}`, whichever comes first. A live turn that goes 45 s without any frame is checked with `session.active_list`. No reply is left spinning.
- **Submit outcome.** The `status` of `prompt.submit` (`streaming`, `queued`, `steered`, `redirected`) is read. A prompt the server folded into a running turn (`redirected`, `steered`) does not leave an empty bubble.
- **Queue drain.** The local queue sends its next prompt only after the session has settled (`session.info {running:false}`), and marks it `queued: true`, so the server never redirects it into the turn that just ended.
- **Final text flags.** `message.complete` honours `response_previewed` and `response_reused` (no second copy), `response_transformed` (replaces the streamed text) and `partial` on an error (the answer text stays and the error shows beside it). `message.interim` honours `already_streamed`.
- **Lossless reconnect.** Every session event's `seq` is tracked. After a drop the client reconnects with backoff, rebinds with `session.resume`, and replays the missed events with `session.events.since`, ignoring any it already has. When the replay is truncated or the server restarted (new `replay_epoch`), the transcript is re-read over REST and `inflight` fills the reply. Open requests come back from `open_requests`.
- **Heartbeat.** `gateway.ping` every 15 s. A socket that has sent nothing for 45 s is treated as dead.
- **Ordering races.** Events are buffered before `session.resume` is sent, since the server can push them before it answers. A turn whose `message.start` was missed is still picked up. Turns nobody submitted (crash auto-continue, goal continuations) are shown.
- **Smaller signals.** `session.info.stored_session_id` re-keys a thread that compression moved to a new stored session. `approval.cancelled` withdraws the listed cards (Hermes main only). `status.update` of kind `compacting`, and provider waits, show as the reply's status line. `thinking.delta` is not transcript.
- **Contract test.** `test/real_backend_contract_test.dart` gains a mid-turn drop with replay against a live backend.

## Non-goals

- No steering UI (`session.steer`) and no editing a prompt into a running turn. The app keeps its own queue.
- No multi-socket fan-out or cross-socket dedupe. The app keeps one socket per transport.
- No rendering of `inflight.corrections` offsets: our client never redirects.
- No change to the REST history paging or to Bot Mode group rooms (`groups.*`).
- No `idempotency_key` on `session.create`: Hermes at the pinned ref rejects it (4000).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: Streaming the reply, Reply error handling, Gateway session handling, Backend contract and Queued messages change. New requirements cover turn settling, the submit outcome, reconnect and replay, the heartbeat, turns the user did not submit, threads moved by compression, withdrawn approvals and the reply status line.

## Impact

- **Code:**
  - `lib/src/chat/gateway/` (rpc client, transport, plus a new event mapper and a replay ledger split out of the transport);
  - `lib/src/chat/chat_transport.dart` (new event fields and types);
  - `lib/src/chat/chat_reply.dart`;
  - `lib/src/chat/chat_controller.dart` (queue drain, unsolicited turns, re-keyed threads).
- **Tests:** `test/hermes_gateway_transport_test.dart`'s `FakeGateway` moves to `test/support/fake_gateway.dart` and learns `seq`, `session.events.since`, `gateway.ping` and submit statuses. New test files go under `test/gateway/`.
- **Backend:** no new REST routes. New RPC methods are `session.events.since`, `gateway.ping` and `session.active_list` (already used for statuses), and `prompt.submit` gains the `queued` param. The minimum Hermes stays the pinned `7b3c7aef`.
- **Delivery:** five PRs (see tasks.md). The project rule asks for one PR per change, but the slices share one contract and one test fake, so splitting them into separate changes would duplicate the design. The PR boundaries are what keep each review under about 500 lines.
- **Security and privacy:** none. No new storage, and no tokens or prompt text in logs. Replayed events stay in memory only.
- **Telemetry:** through `flutter_otel`, three log events with no message content:
  - `gateway.reconnect` (`attempt`, `outcome`: `replayed` | `rest_refetch` | `ended` | `failed`, `replayed_count`, `truncated`, `epoch_changed`);
  - `gateway.turn_settled` (`via`: `complete` | `error_event` | `session_info` | `silence_probe`);
  - `gateway.event_unmapped` (`event.type`, plus `server_request: true` for an unhandled server→client request method). It is sent once per type per connection, so we learn which protocol frames Hermes sends that the app ignores. The type is cut to 64 characters, and after 20 distinct types on one connection the rest are counted as `other`, so a misbehaving server cannot flood telemetry. Payloads are never recorded.
