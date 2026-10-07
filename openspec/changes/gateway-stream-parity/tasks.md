# Tasks

Five stacked PRs (design D6): **PR1** `refactor(chat)` = group 1; **PR2** `fix(chat)` = groups 2 + 3; **PR3** `feat(chat)` = groups 4 + 5; **PR4** `fix(chat)` = groups 6 + 7; **PR5** `feat(chat)` = groups 8–10. No OpenAPI change (JSON-RPC only). Telemetry: group 10.

## How agents use this file

Each group from 1 to 9 is a self-contained brief for one agent. It runs in its own git worktree, branched from the integration branch after the groups it depends on have merged.

**Rules for every agent:**

- Edit only the files listed under **Owns**. Need another file? Stop and report; do not edit it.
- Write the listed tests first. Run them and keep the failure output for the PR description. Then implement.
- Done means all of these pass:
  - `flutter test <your test file>`
  - `flutter test` (the whole suite)
  - `dart format --output=none --set-exit-if-changed .`
  - `flutter analyze`
- Match the surrounding code: sealed `ChatEvent`s, `switch` expressions, doc comments that explain why. No `print`. Follow the `common:code-comments` skill.
- Tests drive `FakeGateway` (`test/support/fake_gateway.dart`) or `FakeChatTransport`, never a mock of the class under test. Timers use `fake_async`.
- Each test name is the spec scenario it covers, so the reviewer can check the mapping.

**Escalation:** a package not green after two attempts is re-run once on Sonnet (medium) with the failed diff attached. An Opus review (low) checks each wave's merged diff against `specs/chat/spec.md` before the next wave starts.

## 0. Toolchain (orchestrator, before any agent)

- [ ] 0.1 Make `flutter --version` work where the agents run: add Flutter stable to the cloud environment's setup script (the SessionStart hook already runs `flutter pub get`), or run the agents locally. Verify `flutter test test/chat_reply_test.dart` passes on the base branch.
- [ ] 0.2 Create the integration branch `feat/gateway-stream-parity` from `main`. Verify it is pushed.

## 1. Foundation, PR1 (Wave 0, one agent, no behaviour change)

**Owns:**

- `lib/src/chat/chat_transport.dart`
- `lib/src/chat/chat_models.dart`
- `lib/src/chat/chat_message_mapper.dart`
- `lib/src/chat/gateway/gateway_event_mapper.dart` (new)
- `lib/src/chat/gateway/gateway_rpc_client.dart`
- `lib/src/chat/gateway/hermes_gateway_transport.dart`
- `lib/src/chat/chat_controller.dart` (switch branches only)
- `lib/src/chat/chat_reply.dart` (switch branches only)
- any other file `flutter analyze` flags for a non-exhaustive `switch` on `ChatEvent` (no-op branch only)
- `test/support/fake_gateway.dart` (new)
- `test/support/fake_chat_transport.dart`
- `test/hermes_gateway_transport_test.dart`

**Tests:** the whole existing suite stays green with no test edited beyond its imports. That is the test for a refactor.

- [ ] 1.1 Add the new event types and fields to `chat_transport.dart`, with doc comments:
  - `ReplyCompleted({previewed=false, reused=false, transformed=false, partial=false, String? error})`
  - `ReplyCheckpoint(text, {alreadyStreamed=true})`
  - `ReplyErrored(String message)`
  - `SessionSettled({String? storedSessionId})`
  - `ReplyStatus(String text)` (empty text clears)
  - `InputRequestsCancelled(List<String> requestIds)` (empty means every request of the reply)
  - `PromptFolded()`
  - `ReplyRebuilt(String text)`
  - `ThreadNeedsRefetch()`

  Add `bool queued = false` to `ChatTransport.send`. Verify with `flutter analyze`.

- [ ] 1.2 Add to `ChatMessage` in `chat_models.dart`:
  - `String? activity`;
  - `bool settledWithoutCompletion = false`;
  - `bool errorEventSeen = false`, plus `String? pendingError` for the held `error` event.

  In `chat_message_mapper.dart`, set `kMetaThinkingActivity: m.activity ?? 'Thinking…'`. Verify `test/chat_message_mapper_test.dart` passes.

- [ ] 1.3 Add a no-op branch for every new event wherever a `switch` over `ChatEvent` must be exhaustive (`chat_reply.dart`, `chat_controller.dart`, the attention policy, any other file `flutter analyze` names). Verify `flutter analyze` is clean.
- [ ] 1.4 Move `_toChatEvent` and its private helpers (`_plainText`, `_args`, `_toolResult`, `_seconds`, `_toApproval`, `_toClarify`, `_toQuestion`, `_unsupported`, `_subagentEvent`, `toolResultStatus` use) verbatim into `gateway/gateway_event_mapper.dart` as `ChatEvent? mapGatewayEvent(GatewayEvent event)`. Helpers the transport still uses become public top-level functions there. Verify the whole suite still passes.
- [ ] 1.5 Add `final int? seq` to `GatewayEvent`, read from `params['seq']` (an `int` only, else null). Verify the suite still passes.
- [ ] 1.6 Send `queued: true` in `prompt.submit` only when `send(queued: true)`, and pass the flag through `FakeChatTransport.send` (record it on `FakeSend.queued`). Add a test in `test/hermes_gateway_transport_test.dart` that `queued` is absent by default and true when asked. That test is the one exception to "imports only".
- [ ] 1.7 Move `FakeGateway` verbatim from `test/hermes_gateway_transport_test.dart` to `test/support/fake_gateway.dart`, then add these knobs (all off by default, so existing tests are unchanged):
  - `stampSeq`: puts `seq` (per session, from 1) in every event's `params` and keeps every sent event in a per-session list.
  - `sendReady` + `epoch`: sends `{method:'event', params:{type:'gateway.ready', payload:{replay_epoch: epoch}}}` on connect.
  - Answers `session.events.since {session_id, last_seen}` with `{events: [params of the session's events with seq > last_seen], latest_seq, truncated: truncateReplay, count, epoch, open_requests: openRequests}`.
  - Answers `gateway.ping` with `{ok: true}`, or with error -32601 when `pingUnknown`.
  - `submitStatus` (default `'streaming'`) is the `status` of the `prompt.submit` answer.
  - `emitSessionInfo`: after `turn` runs, sends `session.info {running: false, stored_session_id: storedAfterTurn ?? the created stored id}`.
  - `resumeResult` may carry `running`, `inflight`, `open_requests`.
  - `beforeResumeAnswer`: a callback run after a `session.resume` request arrives and before it is answered (for "events before the resume answer").
  - `drop()` closes the socket, and the fake accepts a new connection through a `connect` factory that keeps the same ring and seq counters (one server, several sockets).

  Verify the whole suite passes.

## 2. Reply reducer, PR2 (Wave 1, package A)

**Owns:** `lib/src/chat/chat_reply.dart`.
**Tests:** `test/gateway/reply_reducer_parity_test.dart`. Use `applyReplyEvent` on a `ChatMessage` the way `test/chat_reply_test.dart` does.

**Facts.** A "seal" is a `SealedProse` entry in `reply.sealedProse`. `reply.content` is the text streamed since the last seal. Today:

- `ReplyCompleted` with non-empty text sets `content = text`.
- `ReplyCheckpoint` seals its text and clears `content`.

- [ ] 2.1 Tests first, then implement. Each **WHEN → THEN**:
  - `previewed` final equal to the last sealed text, with `content` empty → `content` stays empty, and the reply is `sent`.
  - `reused` final equal to `content` → unchanged, `sent`.
  - `previewed` final whose text appears nowhere → `content = text`.
  - `transformed` final "B" after content "A" → `content == "B"`.
  - Failed final with `partial: true`, text "answer" and error "boom" → `content == "answer"`, `error == "boom"`, status `error`.
  - Failed final without `partial`, with text "oops" → as today (`error == "oops"`).
- [ ] 2.2 Tests first, then implement:
  - `ReplyCheckpoint("X", alreadyStreamed: false)` after content "A" → sealed `["A", "X"]` in that order, `content` empty.
  - `alreadyStreamed: true` after content "A" → sealed `["X"]` (today's behaviour).
- [ ] 2.3 Tests first, then implement:
  - `ReplyErrored("bad")` → sets `pendingError = "bad"` and `errorEventSeen`; status unchanged.
  - Then `SessionSettled()` on a pending reply → status `error`, `error == "bad"`, content kept.
  - Then a failed `ReplyCompleted` with text "real" → one error, `"real"`.
  - `SessionSettled()` on a pending reply with no held error → status `sent`, content kept, running tools settled as completed, open input requests expired, `settledWithoutCompletion = true`.
  - `SessionSettled()` on a finished reply → no change.
  - `ReplyCompleted` on a reply with `settledWithoutCompletion` → its text is applied by the same rules as 2.1, and the flag is cleared.
- [ ] 2.4 Tests first, then implement:
  - `ReplyStatus("Compacting the conversation…")` → `activity` set.
  - Any `ReplyDelta`, `ReasoningUpdated`, `ToolPreparing`, `ToolStarted`, `ReplyCompleted`, `ReplyErrored` → `activity` null.
  - `ReplyStatus("")` → `activity` null.
- [ ] 2.5 Tests first, then implement:
  - `ReplyRebuilt("full")` after content "par" → `content == "full"`, sealed unchanged.
  - `InputRequestsCancelled(["r1"])` → only `r1` expired.
  - `InputRequestsCancelled([])` → all expired.

## 3. Event mapper, PR2 (Wave 1, package B)

**Owns:** `lib/src/chat/gateway/gateway_event_mapper.dart`.
**Tests:** `test/gateway/event_mapper_test.dart`. Call `mapGatewayEvent(GatewayEvent(type:, sessionId: 's', payload:))` directly.

- [ ] 3.1 Tests first, then implement, `message.complete`:
  - `{text, status: 'complete', response_previewed: true}` → `previewed`; likewise `reused`, `transformed`.
  - `{status: 'error', partial: true, error: 'boom', text: 'ans'}` → `failed`, `partial`, `error: 'boom'`.
  - Missing flags → false. Non-bool flags → false.
- [ ] 3.2 Tests first, then implement:
  - `message.interim {text: 'X', already_streamed: false}` → `ReplyCheckpoint('X', alreadyStreamed: false)`.
  - The flag missing → `alreadyStreamed: true`.
- [ ] 3.3 Tests first, then implement:
  - `error {message: 'm'}` → `ReplyErrored('m')`.
  - `session.info {running: false, stored_session_id: 'st2'}` → `SessionSettled(storedSessionId: 'st2')`.
  - `session.info {running: true}` → null.
  - `session.info` without `running` → null.
- [ ] 3.4 Tests first, then implement:
  - `status.update {kind: 'compacting', text: 'x'}` → `ReplyStatus('Compacting the conversation…')`.
  - Other kinds → null.
  - `thinking.delta {text: '⏳ waiting on local-model — 30s with no output yet'}` → `ReplyStatus` with that text (trimmed).
  - `thinking.delta {text: '◉_◉ cogitating...'}` → `ReplyStatus('')`.

  Port the regex verbatim:

  ```
  ^(?:⏳|⚠|↻|⚙)\s*(?:(?:still\s+)?waiting on|loading|processing prompt|no (?:output|response)|model returned|rate limited|provider (?:overloaded|temporarily unavailable))
  ```

  It is case-insensitive.

- [ ] 3.5 Tests first, then implement:
  - `approval.cancelled {request_ids: ['a', 'b']}` → `InputRequestsCancelled(['a', 'b'])`.
  - Missing `request_ids` → `InputRequestsCancelled([])`.

## 4. RPC client heartbeat and frames, PR3 (Wave 1, package C)

**Owns:** `lib/src/chat/gateway/gateway_rpc_client.dart`.
**Tests:** `test/gateway/rpc_client_heartbeat_test.dart`, using a `StreamChannelController<String>` as the server end, like `FakeGateway`, and `fake_async`.

- [ ] 4.1 Tests first, then implement: `GatewayRpcClient(channel, heartbeat: true, pingEvery: 15s, deadAfter: 45s)`. With `heartbeat: false` (the default), nothing changes.
  - It sends `gateway.ping` every 15 s.
  - Any inbound frame (reply, event, server request, even non-JSON) resets the last-frame clock.
  - No frame for 45 s → the client closes itself (`isClosed`, pending requests fail with `GatewayConnectionClosed`).
  - An answered ping, even with an error, keeps it open.
- [ ] 4.2 Tests first, then implement:
  - A `gateway.ready` event's `payload.replay_epoch` is exposed as `String? epoch`; null until one arrives.
  - The `gateway.ready` event is still emitted on `events`.
- [ ] 4.3 Tests first, then implement:
  - An event with empty `params.session_id` whose `payload.session_id` is a string gets that as `GatewayEvent.sessionId`.
  - An event with a non-empty `params.session_id` keeps it.

## 5. Replay units, PR3 (Wave 1, package D)

**Owns:** `lib/src/chat/gateway/gateway_replay.dart` (new; pure Dart, no Flutter imports).
**Tests:** `test/gateway/replay_units_test.dart`.

- [ ] 5.1 Tests first, then implement `ReplayLedger`:
  - `observe(sid, seq)` returns true when `seq > watermark[sid]` (or there is no watermark yet) and raises the watermark; otherwise false.
  - `seq == null` → always true and the watermark is unchanged.
  - `lastSeen(sid)` returns 0 when unknown.
- [ ] 5.2 Tests first, then implement `ReplayDecision merge({required String sid, required Map<String, Object?> result, required List<GatewayEvent> parked, required String? connectionEpoch})`:
  - Normal case → `Deliver(events)`: the replay `events` (as `GatewayEvent`s), then `parked`, each passed through `observe`, in order, without duplicates.
  - Example: watermark 7, replay seqs 8–12, parked 11–13 → delivers 8, 9, 10, 11, 12, 13.
  - `truncated == true` → `Refetch` and the watermark jumps to `latest_seq`.
  - `epoch` differs from `connectionEpoch` (both non-null) → `Refetch`, and every watermark is cleared.
  - Malformed elements (not a map, no `type`) are skipped.
- [ ] 5.3 Tests first, then implement `Duration reconnectDelay(int attempt, Random random, {Duration base = 300ms, Duration cap = 15s})`: full jitter, so `random.nextDouble() * min(cap, base * 2^attempt)`. Test with a seeded fake `Random` that returns 1.0 (just under): attempt 0 → ≤300 ms, attempt 6 → ≤15 s cap, attempt 20 → ≤15 s.
- [ ] 5.4 Tests first, then implement `bool settles({required bool started, required DateTime submittedAt, required DateTime now})`:
  - true when `started`;
  - false when not started and `now - submittedAt < 15s`;
  - true otherwise.

## 6. Controller: queue drain, folded prompts, late completions, re-keying, PR4 (Wave 1, package E)

**Owns:** `lib/src/chat/chat_controller.dart`.
**Tests:** `test/gateway/controller_settle_test.dart`, driven with `FakeChatTransport` (`FakeSend` feeds the send stream; `followUpStreams[threadId]` feeds follow-ups), the way `test/chat_queue_test.dart` does.

**Facts:**

- The send stream closes right after `ReplyCompleted`.
- `SessionSettled` arrives later, on `followUps`.
- Today `_streamReply.end()` calls `sendQueued` at once (`chat_controller.dart:1125`), and `_followUps` drops every event while no reply is open except `ThreadTitled` (`:1186-1193`).

- [ ] 6.1 Tests first ("Sent only once the session settled"), then implement:
  - A queued message is not sent on `ReplyCompleted`.
  - It is sent when `SessionSettled` arrives on follow-ups, or after 2 s with `fake_async`, whichever is first, and only once.
  - The `FakeSend` for it has `queued == true`.
  - A direct send (not from the queue) has `queued == false`.
- [ ] 6.2 Tests first ("Folded into the running turn"), then implement: `PromptFolded` on a send stream → the placeholder for that send is removed from the transcript (not marked failed), the user's message stays, and nothing is announced as failed.
- [ ] 6.3 Tests first ("Settled without a completion", the controller half): after a reply ended through `SessionSettled` on its send stream, a `ReplyCompleted("final")` arriving on follow-ups with no reply open is applied to that last reply; no second bubble appears.
- [ ] 6.4 Tests first ("Missed start of a chained turn"): on follow-ups with no reply open, a `ReplyDelta`, `ToolPreparing`, `ToolStarted` or `ReasoningUpdated` opens a placeholder and is applied to it, as `ReplyStarted` would.
- [ ] 6.5 Tests first ("Compression rotates the stored id"): `SessionSettled(storedSessionId: 'stored-2')` on a thread with id `stored-1` → the thread's id becomes `stored-2` (use the existing `_bindThread` path), its place, title and messages are kept, and the next `FakeSend.threadId == 'stored-2'`.
- [ ] 6.6 Tests first: `ThreadNeedsRefetch` on either stream → `refreshThread(thread)` runs once the reply is no longer pending. Use the existing refresh path; assert through the fake repository's history calls.

## 7. Transport: submit outcome, early events, settling, PR4 (Wave 2, package T1)

**Owns:** `lib/src/chat/gateway/hermes_gateway_transport.dart`.
**Tests:** `test/gateway/transport_settle_test.dart`, using `FakeGateway` from `test/support/`.

- [ ] 7.1 Tests first ("Folded into the running turn", "Queued by the server", "The reply arrives before the submit answer"):
  - `submitStatus: 'redirected'` or `'steered'` → the send stream yields `PromptFolded()` and closes.
  - `'queued'` → the stream waits for `message.start` and streams as usual.
  - Events pushed by `turn` before the submit answer are yielded in order (keep this green).
- [ ] 7.2 Tests first ("Events that arrive before the resume answer"): with `beforeResumeAnswer` pushing `message.delta` for the resumed runtime id, that delta is yielded after the resume completes. Implement by subscribing to the connection's events before sending `session.resume`, buffering them all, then keeping those whose `sessionId` equals the returned runtime id.
- [ ] 7.3 Tests first ("Settled without a completion", "Stale report before the turn began", "Error event without a completion"):
  - Forward `ReplyErrored` and `SessionSettled` from the watch.
  - The send stream ends after a `SessionSettled` when `settles(...)` from `gateway_replay.dart` is true. When it is false, ignore that `SessionSettled`.
  - The watch is parked for follow-ups exactly as after `ReplyCompleted`.
- [ ] 7.4 Tests first ("A silent live turn"): the transport takes `silenceProbe: 45s`. While a reply is in flight with no frame for that long, it requests `session.active_list`:
  - The thread's stored id missing, or not `working`/`waiting`/`starting` → end the stream as broken (`GatewayConnectionClosed`).
  - Otherwise wait another 45 s.

  Use `fake_async`.

- [ ] 7.5 Construct `GatewayRpcClient` with `heartbeat: true` in the transport's connect path. Test ("Dead socket"): a fake that stops answering for 45 s closes the connection, and a reply in flight goes to the reconnect path (today's `_reattach`).

## 8. Transport: lossless reconnect, PR5 (Wave 2, package T2, after T1)

**Owns:** `lib/src/chat/gateway/hermes_gateway_transport.dart`.
**Tests:** `test/gateway/transport_reconnect_test.dart`, with `FakeGateway(stampSeq: true, sendReady: true)` and its reconnect factory.

- [ ] 8.1 Tests first ("Replay fills the gap"):
  - The turn sends deltas with seq 1–7, then `drop()`.
  - While disconnected, the fake records seqs 8–12.
  - On reconnect the transport calls `session.resume`, then `session.events.since {session_id: rt, last_seen: 7}`, and yields 8–12 exactly once, then the live 13.

  Implement with `ReplayLedger` (observe every yielded event's `seq`) and `merge`.

- [ ] 8.2 Tests first ("Live events overlap the replay"): the fake sends live seqs 11–13 before answering `events.since` with 8–12 → yielded order 8, 9, 10, 11, 12, 13, no duplicates.
- [ ] 8.3 Tests first ("Replay truncated or server restarted"):
  - `truncateReplay: true` with resume `running: true, inflight: {assistant: 'abc'}` → yields `ReplyRebuilt('abc')` and continues live.
  - A new epoch on the new socket → the same.
  - `running: false` and no completion in the replay → yields the stored-reply `ReplyCompleted` (today's `_storedReply`), then `ThreadNeedsRefetch()`.
- [ ] 8.4 Tests first ("Requests open across the drop"): the resume result's `open_requests: [{id: 'srq-1', method: 'approval', params: {...}}]` → yields one `ApprovalRequested` keyed `srq-1`. The same id again from `events.since` → not yielded again.
- [ ] 8.5 Tests first ("Backoff"):
  - Reconnect attempts wait `reconnectDelay(attempt)`. Inject `Random` and a `sleep` function for tests.
  - After 5 failed attempts or 60 s, the stream errors with `GatewayConnectionClosed`.

  Replace the no-delay `_maxReattempts` loop in both `send` and `_relay`.

- [ ] 8.6 Fix the comment at `_respond`/`_connected`: the gateway matches server-request answers by id on any connection. Test: an approval answered after a reconnect sends the response frame on the new socket.

## 9. Transport: signals and unsolicited turns, PR5 (Wave 2, package T3, after T2)

**Owns:** `lib/src/chat/gateway/hermes_gateway_transport.dart`.
**Tests:** `test/gateway/transport_signals_test.dart`.

- [ ] 9.1 Tests first ("Approvals cancelled by an interrupt", "Another session"): an `approval.cancelled` broadcast (empty `params.session_id`, `payload.session_id` = the reply's runtime id) yields `InputRequestsCancelled`, and the request ids are dropped from `_awaiting`. Another session's broadcast → nothing.
- [ ] 9.2 Tests first ("Missed start of a chained turn", "Two starts for one continuation"):
  - In `_relay`, a `ReplyDelta`, `ToolStarted`, `ToolPreparing` or `ReasoningUpdated` while not replying is treated as a start (`_beginReply`, `replying = true`) and forwarded.
  - Two `message.start`s yield one `ReplyStarted`.
- [ ] 9.3 Tests first ("Auto-continue after resume"): a send's `session.resume` result with `auto_continue: {attempt: 1}`, and the fake starting a turn the app did not submit, before the submitted one → the unsolicited turn reaches `followUps`, not the send stream. Implement by parking the watch for follow-ups when a `message.start` arrives before the `prompt.submit` answer while `auto_continue` was reported.
- [ ] 9.4 Tests first ("Compacting", "Explained provider wait"): `status.update` and `thinking.delta` events reach the send stream as `ReplyStatus`.

## 10. Contract, telemetry, docs and verification, PR5 (Wave 3, orchestrator or one Sonnet agent)

- [ ] 10.1 Add the telemetry from the proposal, through `safely`: `gateway.reconnect` (`attempt`, `outcome`, `replayed_count`, `truncated`, `epoch_changed`) and `gateway.turn_settled` (`via`). Test with `test/support/recording_tracer.dart` that both are emitted and carry no message text.
- [ ] 10.2 Extend `test/real_backend_contract_test.dart` (runs only with `HERMES_DEV_URL` and `HERMES_DEV_MODEL_CALLS=1`):
  - a turn sends `session.info {running:false}` after `message.complete`;
  - event frames carry `seq`;
  - `session.events.since` after a forced socket close returns the missed seqs;
  - `prompt.submit {queued:true}` right after a completion answers `queued` or `streaming`, never `redirected`.

  Verify it skips without `HERMES_DEV_URL`, and run it once with `scripts/dev-backend.sh start`.

- [ ] 10.3 Update `CLAUDE.md`'s Chat paragraph: settling signals, `seq` replay with `inflight` and REST fallback, the heartbeat, `queued: true` drains. Update the `verify-in-app` skill with a step that kills the dev backend's socket mid-reply (drop the connection, not the server) and checks the reply finishes. Verify the docs name only files that exist.
- [ ] 10.4 Final verification:
  - `dart format --output=none --set-exit-if-changed .`
  - `flutter analyze`
  - `flutter test`
  - the `verify-in-app` loop against `scripts/dev-backend.sh`: send, drop the socket mid-reply, and check the reply completes once with no duplicated text; queue a message and check it is sent after the reply with no folded or hijacked turn.

## Workflow follow-up

- Archive the change after PR5 merges, syncing the delta into `openspec/specs/chat/spec.md`.
- Bump `HERMES_REF` in `real-backend-contract.yml` separately to pick up `approval.cancelled` in the contract test.
