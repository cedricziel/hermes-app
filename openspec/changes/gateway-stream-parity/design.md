# Design

## Context

The gap analysis behind this change, with file:line citations, covers the server protocol, upstream's own clients (with 102 edge-case rules taken from `apps/desktop` tests) and our client. The protocol facts this design relies on, all present at the pinned `7b3c7aef`:

- Every session event frame carries `params.seq`, rising per runtime session id. The server keeps the last 512 events (4 MiB) per session in a ring. `session.events.since {session_id, last_seen}` returns `{events, latest_seq, truncated, epoch, open_requests}`, and `gateway.ready.payload.replay_epoch` changes when the backend restarts.
- A new socket is attached to a live session only by `session.resume` (stored id), `session.activate` or `prompt.submit`. `session.events.since` does not attach. On the live path, `session.resume` returns `running: true` and `inflight.assistant` (all deltas so far). It runs on a worker pool, so events can arrive before its answer.
- `message.complete` is sent before the server clears its running flag. `session.info {running:false, stored_session_id}` follows; it is the "settled" signal. Some failures send only `error`.
- `prompt.submit` answers `streaming | queued | steered | redirected`. `queued: true` makes the busy path queue the prompt, never redirect it.
- Approvals are answered by id, on any connection (`server_requests.py:253-280`).

Today's code: `hermes_gateway_transport.dart` (1120 lines) holds the event mapping, the send loop, follow-ups, reattach and input requests. `chat_reply.dart` is a pure reducer. `test/hermes_gateway_transport_test.dart` (3030 lines) defines `FakeGateway` inline.

Platforms: all platforms that chat (iOS, Android, macOS, Windows, Linux). The watch only relays through the phone and is not affected. There are no native, entitlement or Xcode changes.

Invariants touched:

- **Telemetry:** the two new log events go through `safely` and never carry message text.
- **Auth:** reconnect mints a fresh ticket per socket (already the case) and never touches tokens.
- **API layering:** the REST fallback reuses `HermesChatRepository`'s existing history read. No hand-rolled Dio call is added.

## Goals / Non-Goals

**Goals:**

- Every requirement in the delta has a test that failed first.
- The work can be done by several small agents at once without merge conflicts.

**Non-Goals:**

- No rewrite of the transport's public `ChatTransport` shape beyond the additions listed in D1.
- No change to Bot Mode group rooms, which use `groups.*` and their own replay.

## Decisions

### D1. A foundation PR that fixes every shared contract first

Parallel agents conflict on shared types and on the 3030-line test file. A first, behaviour-neutral PR therefore lands everything they share:

- **New `ChatEvent` fields and types** (`chat_transport.dart`), with no behaviour behind them yet:
  - `ReplyCompleted` gains `previewed`, `reused`, `transformed`, `partial` and `error` (string).
  - `ReplyCheckpoint` gains `alreadyStreamed` (default `true`, today's behaviour).
  - New: `ReplyErrored(message)`, `SessionSettled(storedSessionId)`, `ReplyStatus(text)` (empty text clears), `InputRequestsCancelled(requestIds)` (empty means all of the session), `PromptFolded()` for `redirected`/`steered`, and `ReplyRebuilt(text)` (inflight text that replaces the streamed text since the last seal).
  - New: `ThreadNeedsRefetch()`, asking the controller to re-read history over REST.
  - Every exhaustive `switch` gets a no-op branch, so `flutter analyze` stays clean.
- **`ChatMessage.activity`** (`String?`): the mapper uses it in place of the hard-coded "Thinking…", which is still the default.
- **`ChatTransport.send(..., queued: false)`**, implemented in `HermesGatewayTransport` (sent only when true) and in `FakeChatTransport`.
- **`GatewayEvent.seq`** (`int?`), read from `params.seq`.
- **The mapper extracted:** `_toChatEvent` moves verbatim into `lib/src/chat/gateway/gateway_event_mapper.dart` as a top-level `ChatEvent? mapGatewayEvent(GatewayEvent event)`.
- **`FakeGateway` moved** to `test/support/fake_gateway.dart`, with new knobs:
  - stamps `params.seq` per session;
  - keeps a ring and answers `session.events.since`, with knobs `truncateReplay` and `epoch`;
  - sends `gateway.ready` with `replay_epoch` on connect, when enabled;
  - answers `gateway.ping`, with a knob `pingUnknown`;
  - answers `prompt.submit` with `submitStatus`;
  - emits `session.info` after a turn, when enabled;
  - returns `inflight` and `open_requests` from `session.resume`;
  - `holdResume`: emits given events before answering `session.resume`.

  The existing tests import it unchanged.

- **New tests go in new files** under `test/gateway/`, one per work package, so no two agents touch the same test file.

_Alternative:_ let each agent extend types as it goes. Rejected: five agents would each edit `chat_transport.dart` and the fake, and every merge would conflict.

### D2. Pure units carry the logic; the transport only wires them

Stateful async code inside the transport is where a small model goes wrong. The rules are therefore pulled into pure, separately tested units, and the transport calls them:

- **`gateway_event_mapper.dart`:** frame to `ChatEvent`, including the provider-wait regex and the `already_streamed` and completion flags.
- **`gateway_replay.dart`** (new), with three parts:
  - `ReplayLedger`: watermark per runtime session, `shouldDeliver(sid, seq)`, epoch tracking, and `merge(replayResult, parked)` returning `Deliver(events) | Refetch(latestSeq)`.
  - `reconnectDelay(attempt, Random)`: 300 ms base, ×2 each attempt, 15 s cap, full jitter.
  - `SettleGate`: decides whether a `SessionSettled` ends a reply, given `started`, `submittedAt` and `now`; the 15 s grace before start lives here.
- **`chat_reply.dart`:** how each new event changes a reply.
- **`gateway_rpc_client.dart`:** the heartbeat, the last-frame clock, `gateway.ready` epoch capture, and lifting `payload.session_id` onto session-less broadcasts (`approval.cancelled`), so the existing per-session filtering routes them.

### D3. Settling: first terminal signal wins, and a late completion lands on the same reply

The transport keeps per-reply state `ended`:

- `ReplyCompleted` ends the reply as today.
- `ReplyErrored` is held. If `SessionSettled` arrives with no completion, a failed completion carrying the error's message is synthesized. If a failed completion arrives instead, its message wins and the held error is dropped, so one card is shown.
- `SessionSettled`, when `SettleGate` allows it, ends the reply with the streamed text kept.

After the stream ends, the session's watch stays parked as today, so a late `ReplyCompleted` reaches `followUps`. The controller applies it to the last reply when that reply was settled without a completion (spec "Settled without a completion"). The 45 s silence probe uses `session.active_list`, which the transport already calls for statuses.

### D4. Reconnect: replay first, then `inflight`, then REST

On a drop while replying:

1. Retry with `reconnectDelay` backoff, at most 5 attempts or 60 s.
2. Open a socket, record its `gateway.ready` epoch, then call `session.resume` while buffering every event of the connection.
3. The resume result gives the runtime id:
   - **Same runtime id and the same epoch:** call `session.events.since(last_seen)` and deliver through `ReplayLedger.merge`, with the live frames buffered so far as `parked`.
   - **Truncated replay or a new epoch, while running:** deliver `ReplyRebuilt(inflight.assistant)` and continue live, gating on the ledger.
   - **Not running:** deliver the replayed tail. If no completion was in it, send `ReplyCompleted` from the stored reply as today and also `ThreadNeedsRefetch`.
4. `open_requests` from either result are mapped like live server requests. The controller drops one whose request id already has a card.

_Alternative:_ always refetch over REST on reconnect, as upstream's desktop does. Rejected for now: our transcript model does not yet graft REST rows onto a streaming reply, and `inflight` covers the running case. REST is used only once the turn has ended.

### D5. The queue drains on `SessionSettled`, with a 2 s fallback

`ChatController` waits for `SessionSettled` on the thread's follow-up stream before sending the next queued prompt, or 2 s after `ReplyCompleted` (an older Hermes, or a missed frame), and sends it with `queued: true`. `PromptFolded` removes the new reply's placeholder.

### D6. Work split for parallel agents

Each package is one agent in its own git worktree, branched from the integration branch. Each agent may edit only the files listed for it. Tests come first: write the test file, run it, and record the failure in the PR description. Then implement until `flutter test <its tests>`, `dart format --set-exit-if-changed` and `flutter analyze` pass.

| Wave | Package              | Owns (edit only these)                                                                                                                                                                                                                                                                                                                                                                                                               | Tests (new file)                              | Depends on |
| ---- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------- | ---------- |
| 0    | F Foundation         | `chat_transport.dart`, `chat_models.dart` (activity), `chat_message_mapper.dart` (activity), `gateway/gateway_event_mapper.dart` (new, verbatim move), `gateway/gateway_rpc_client.dart` (seq only), `hermes_gateway_transport.dart` (call the mapper, `queued` param), `test/support/fake_gateway.dart`, `test/support/fake_chat_transport.dart`, `test/hermes_gateway_transport_test.dart` (import only), exhaustive-switch no-ops | existing suite stays green                    | –          |
| 1    | A Reducer            | `chat_reply.dart`                                                                                                                                                                                                                                                                                                                                                                                                                    | `test/gateway/reply_reducer_parity_test.dart` | F          |
| 1    | B Mapper             | `gateway/gateway_event_mapper.dart`                                                                                                                                                                                                                                                                                                                                                                                                  | `test/gateway/event_mapper_test.dart`         | F          |
| 1    | C RPC client         | `gateway/gateway_rpc_client.dart`                                                                                                                                                                                                                                                                                                                                                                                                    | `test/gateway/rpc_client_heartbeat_test.dart` | F          |
| 1    | D Replay units       | `gateway/gateway_replay.dart` (new)                                                                                                                                                                                                                                                                                                                                                                                                  | `test/gateway/replay_units_test.dart`         | F          |
| 1    | E Controller         | `chat_controller.dart`                                                                                                                                                                                                                                                                                                                                                                                                               | `test/gateway/controller_settle_test.dart`    | F          |
| 2    | T1 Submit and settle | `hermes_gateway_transport.dart`                                                                                                                                                                                                                                                                                                                                                                                                      | `test/gateway/transport_settle_test.dart`     | A–E        |
| 2    | T2 Reconnect         | `hermes_gateway_transport.dart`                                                                                                                                                                                                                                                                                                                                                                                                      | `test/gateway/transport_reconnect_test.dart`  | T1         |
| 2    | T3 Signals           | `hermes_gateway_transport.dart`                                                                                                                                                                                                                                                                                                                                                                                                      | `test/gateway/transport_signals_test.dart`    | T2         |
| 3    | V Contract and docs  | `test/real_backend_contract_test.dart`, `CLAUDE.md`, skills                                                                                                                                                                                                                                                                                                                                                                          | –                                             | T3         |

The five Wave 1 agents run at the same time and share no files. Wave 2 is one file, so T1 to T3 run one after another. Wave 3 is a single integration step.

**Model per package:**

- Haiku runs every package.
- Each brief in `tasks.md` gives exact payloads and expected outcomes, so a package needs no protocol research. The upstream reports are not needed either; the facts are inlined.
- A package whose tests are not green after two attempts is re-run once on Sonnet (medium effort) with the failed attempt's diff attached.
- An Opus reviewer (low effort) checks each wave's merged diff against the spec delta before the next wave starts. A finding goes back to the package's agent, not to the reviewer.

**Toolchain:** the cloud container has no Flutter SDK. Before Wave 0, install Flutter stable into the environment's setup script, or run the agents on a machine with Flutter. Every brief's checks need `flutter test`.

**PRs (each about 500 lines or less):**

1. F
2. A + B
3. C + D
4. E + T1
5. T2 + T3 + V

They are stacked: each PR targets the one before it, so review can start while the next wave runs.

## Risks / Trade-offs

- [The server's ordering differs between the pin and main, and the fake encodes one ordering] → The contract test in Wave 3 drops a socket mid-turn against a live Hermes at the pin, and is run once against main by hand.
- [A synthesized error, or a settle without a completion, hides a late real completion] → D3's late-completion rule, with a test in E and T1.
- [Haiku reads a brief too literally and misses a branch] → Every spec scenario maps to a named test in a brief (tasks.md lists the mapping), and the Opus reviewer checks the mapping, not just green tests.
- [Backoff and heartbeat timers make tests slow or flaky] → All timer tests use `fake_async`. Durations are constructor params, defaulting to the spec values.
- [`approval.cancelled` exists only on Hermes main] → Handled when present. At the pin, interrupts still send `request.cancel`, which already works.

## Migration Plan

Client-only, no stored state. Rolling back is reverting the PRs. No feature flag is needed: each behaviour degrades to today's when the server omits the new fields.

## Open Questions

- Whether to show a passive "Reconnecting…" status in the thinking indicator during D4. The `ReplyStatus` event can carry it later without changing this design.
