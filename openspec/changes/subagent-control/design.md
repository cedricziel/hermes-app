# Design

## Context

What the app does today:

- `subagent.spawn_requested|start|progress|tool|thinking|complete` frames become `SubagentUpdated` events (`gateway/gateway_event_mapper.dart`), upserted into the reply's `ChatMessage.subagents` (`chat_reply.dart`) and drawn in the transcript as `SubagentGroupCard` (`widgets/subagent_card.dart`): goal, state, last tool, tool count, time, summary. Nothing reaches the Activity panel, and nothing can be done to an agent.
- `agent.terminal.output` and `terminal.close` become `ProcessOutputCard`s under the panel's This session (`process_output_state.dart`): process id, "Output received" or "Closed", a 64 KiB tail. No command, no state, no stop.
- The Activity panel (`activity/bound_activity_panel.dart`, `activity/widgets/activity_panel.dart`) is a sheet on phones (`showKanbanDetentSheet`) and an inspector from 760 pt (`InspectorLayout`) in the main window (`chat_screen_layout.dart`) **and in Mac conversation windows** (`windows/conversation_window_screen.dart`). The quick panel has none. (The roadmap note that conversation windows lack a panel is out of date.)
- Session-scoped gateway calls resolve the chat's runtime id on the shared connection with `_commandRuntime` (resume when needed), as `undoLastTurn` and `stopReply` do (`gateway/hermes_gateway_transport.dart`).

Platforms: iOS, iPadOS, Android, macOS, Windows, Linux. No native code, entitlement, manifest or Xcode project change. The watch, widgets, Live Activities and the surface snapshot are untouched.

Invariants touched: telemetry never breaks the app and carries no content; API layering is unaffected (gateway only, no REST); auth is unaffected (calls ride the existing authenticated socket).

## Server surface verified

Read at Hermes `d923a5eb` (`openrpc/HERMES_REF`), in `/home/user/nousresearch/hermes-agent`. All are dashboard `/api/ws` JSON-RPC methods; all are in `openrpc/hermes-gateway.openrpc.json`.

### In this change

**`subagent.list`** (`tui_gateway/methods_subagents.py`; contract `tui_gateway/contracts/profiles_vault_complete_foreign_subagents.py` `SubagentListResult`). Params `{session_id, profile?}` (runtime id; `profile` is accepted by `SessionParams` but unused). Authority: `_current_session_steer_authority` (`tui_gateway/server.py`) requires the calling connection to be _attached_ to the live session record under that id (membership in the session's transport slot, so any client that resumed the session counts). Lists the exact-owner records plus children owned through the conversation's durable lineage (survives reconnect and compression, Hermes #114909), and `delegations`: failed async delegation tasks of the session from the durable store (last window, at most 20; `tools/async_delegation.py` `failed_delegations_for_session`). Example from `tests/tui_gateway/test_subagent_snapshot.py`:

```json
{
  "subagents": [
    {
      "subagent_id": "child",
      "parent_id": null,
      "depth": 1,
      "goal": "owned task",
      "delegation_id": "deleg-…",
      "model": "test",
      "started_at": 1763120000.5,
      "status": "running",
      "tool_count": 1,
      "last_tool": "read_file",
      "accepting_steer": true
    }
  ],
  "delegations": []
}
```

A failed delegation row: `{"delegation_id", "task_index", "status", "goal", "error", "dispatched_at", "completed_at"}`. Errors: 4001 `session not found or not owned by this transport` (unknown runtime id, or this connection not attached). The context the parent handed the child and other sessions' children never appear (the test checks it).

**`subagent.tail`** (same file). Params `{session_id, subagent_id}`; 4000 without `subagent_id`, 4001 as above. Reads the last 16,384 bytes of the child's live transcript file and decodes it as UTF-8 ignoring errors, so a truncated read can start mid-line. Answers `{"subagent_id", "available", "text", "truncated"}`; `available: false` with empty text while the child has no transcript yet, after it ended (its record is gone), or on a file race. The transcript (`tools/delegation_live_log.py`) is a header (only in the first 16 KiB) and lines `HH:MM:SS role     | text` with roles `user`, `start`, `tool` (`-> name(args…)`, args cut at 220 characters), `result` (cut at 400), `assistant` (cut at 600), `think` (cut at 300), `final`. Every line is passed through Hermes' credential redactor with `force=True`; if the redactor is missing the line reads `[line withheld: redaction unavailable]`. Redaction is best effort, so the app treats the text as sensitive anyway.

**`subagent.interrupt`** (same file). Params `{session_id, subagent_id}`; 4000, 4001. Hard-interrupts the exact owned record (`agent.interrupt_compat.request_hard_interrupt`): the child stops at its next iteration boundary, the flag reaches in-flight tools and grandchildren. Answers `{"found": true|false, "subagent_id"}`; `found: false` when it already ended. The child then completes with `status: interrupted` and its last real assistant text as the summary (`tools/delegate_tool_child_run.py`), which the parent agent receives as the tool result and goes on with its turn. Background programs the child started keep running (`tools/delegate_tool_registry.py`: "child-started background processes routinely outlive the child").

**`subagent.steer`** (`tui_gateway/methods_session.py`; contract `billing_delegation_pets.py` `SubagentSteerResult`). Params `{session_id, subagent_id, text}`; 4000 without id, 4002 blank text, 4001 when the runtime session is unknown (`_sess_nowait`). Answers `{"status": "queued"|"rejected", "subagent_id", "text"}`. `queued` means `AIAgent.steer()` (`agent/interrupt_control.py`) appended the text to the child's pending note, delivered as its own user row after the current tool batch; several notes concatenate. `rejected` for an unknown or ended child, one no longer accepting notes (`accepting_steer` false once it starts closing), or an ownership mismatch. A note queued after the child's last tool batch never lands: the parent's result entry gets `missed_steer` and the summary gains `[steer did not land — the subagent finished before it could be delivered: <text>]`. The note goes into the child's own conversation, not the chat's stored messages.

**`process.list`** (`tui_gateway/methods_tools.py`, `_session_processes` in `server.py`; contract `tools_commands.py` `ProcessListResult`). Params `{session_id, profile?}`, resolved with `_sess` (waits for the agent build); 4001 unknown session; 5010 on a body error. Programs whose registry `session_key` is this session's, each with `output_tail` (last 4,000 characters of the buffer) added. No transport-attachment check. Row example: `{"session_id": "proc_ab12", "command": "npm test", "cwd": "/repo", "pid": 4242, "status": "running", "uptime_seconds": 42, "output_preview": "…", "output_tail": "…", "exit_code": null}`.

**`process.kill`** (same files, `ProcessKillResult`). Params `{session_id, process_id}`; 4012 without id, 4044 `no such process` when it is not the session's. Answers the registry's kill snapshot `{"status": "killed"|"already_exited"|"not_found"|"error", "command", "exit_code", "completion_reason", "termination_source", "output", "error"}`. An explicit kill consumes the completion notification, so the agent is not told the program finished. `process_id` here is the same registry id `agent.terminal.output` carries as `process_id` (`tui_gateway/session_notifications.py`).

### Read and left for later

- **`delegation.status`** (`methods_session.py`): every live child of the whole gateway (`list_active_subagents`, private fields stripped but other sessions' goals included), the global spawn pause flag and limits. Not session-scoped: wrong for a chat panel and leaks other chats' goals.
- **`delegation.pause {paused}`**: blocks _new_ spawns for the whole gateway, every user and session. A server-care setting (roadmap 4.7), not a chat control.
- **`spawn_tree.save|list|load`**: snapshot files of finished trees written by the terminal UI under the spawn-trees root; `load` takes a server path. History browsing, later.
- **`process.stop`**: kills every program in the registry (`kill_all`), whatever session started it. Never from a chat. **`agents.list`**: registry-wide summary; same reason.
- **`session.steer` / `session.redirect`**: notes to the main agent's running turn. The composer already gets this behaviour from `prompt.submit` answering `steered`/`redirected`; an explicit control would be a composer change.
- **`prompt.background` / `prompt.btw`**: start side work (`_spawn_side_agent`); results already show as side results. Side agents are not in the subagent registry and have no stop call. A composer change.

## Goals / Non-Goals

**Goals:**

- The user can find any agent of the open chat in one place, read what it is doing, stop it or redirect it, without stopping the reply.
- A destructive or text-sending action is never sent twice by the app and never sent without the user.
- Output never leaves memory, never outlives what is on screen, and is never logged.

**Non-Goals:**

- Anything server-wide (see above); agents of other chats; notifications or system surfaces about agents.

## Decisions

### 1. Transport calls on the connection that holds the session

Hermes honours these calls only from a connection attached to the session. The app already has the rule it needs: `_runtimeOf[(profile, threadId)]` knows the runtime id on the current connection, and `_commandRuntime` resumes when it does not. A new narrow interface, `AgentWorkTransport` (implemented by `HermesGatewayTransport`, delegated by `SessionChatTransport`, faked in `FakeChatTransport`), carries raw-map calls:

```dart
abstract interface class AgentWorkTransport {
  /// Null when the session is not attached on the current connection (no resume).
  Future<Map<String, Object?>?> readAttached(String threadId, {String? profile,
      required String method, Map<String, Object?> params, required Duration timeout});
  /// Attaches with session.resume when needed, then sends once.
  Future<Map<String, Object?>> act(String threadId, {String? profile,
      required String method, Map<String, Object?> params, required Duration timeout});
}
```

Reads (`subagent.list|tail`, `process.list`) use `readAttached`: never a resume, so opening the panel on an idle chat costs nothing on the server. Actions (`subagent.interrupt|steer`, `process.kill`) use `act`. Both go through `requestKeepingConnection` semantics (a timeout abandons the call, never the socket, 10 s). A 4001 on a read makes the roster treat the session as not attached for that connection (it stops list reads until the connection changes or an action attaches the session); the transport's own runtime map is left alone, since sends and the follow-up listener own it. A 4001 on an action is reported, not repeated. The transport adds `session_id` itself, so no caller can address another session. Alternative considered: a dedicated socket per panel, as the Bot Screen viewer does. Rejected: Hermes would need a resume on it, which rebuilds nothing but adds a second attached viewer and its fan-out traffic for every open panel.

### 2. Repository with lenient parsing and sealed results

`SubagentRepository` (`lib/src/chat/subagents/`) wraps `AgentWorkTransport` and returns:

```dart
sealed class AgentWorkResult<T> {}
final class WorkOk<T>        // value
final class WorkNotAttached  // read only: session not on this connection
final class WorkUnsupported  // -32601 for this method
final class WorkLost         // timeout or connection closed after sending: "may have happened"
final class WorkFailed       // kind: rejected (4000/4002/4012), notOwned (4001/4044), server (5xxx), other
```

Parsers never throw: rows without an id are skipped; numbers accept int, double or numeric strings; `started_at` is Unix seconds; statuses map `queued` → starting, `running` → running, `completed` → finished, `interrupted` → stopped, `failed|error|timeout` → failed, anything else → ended. Tail text is cut to the last 16 KiB at a UTF-8 boundary and, when `truncated`, the partial first line is dropped. `SteerOutcome` is `queued | rejected`; `StopOutcome` is `stopped | alreadyEnded`; `KillOutcome` mirrors the four process statuses. Fixtures recorded from the Hermes tests above, plus one recorded from `scripts/dev-backend.sh` in task 1.1, live in `test/chat/subagents/subagent_fixtures.dart`.

### 3. One roster per chat, merged from frames and the list

`SubagentRoster` (a `ChangeNotifier`, `ChatController.subagentsIn(thread)`, created and retired with the thread's other activity controllers and following the same ownership rules: connection, runtime, profile) holds one `AgentRow` per `subagent_id`: the frame-fed `Subagent` from every reply of the thread, plus the last list snapshot and the failed delegations. Merge rules:

- A frame always wins over a list answer older than it (each list read records the frame sequence it started after; an answer that started before a newer frame for that id does not overwrite it).
- Terminal states are sticky.
- A non-terminal row the list no longer contains, with no completion frame, becomes `ended` (shown as "Ended", never "Finished").
- A failed delegation is keyed `delegation_id#task_index` and skipped when a frame-fed row already has that delegation and index.
- This session keeps the 20 newest ended rows and counts the rest.

The roster reads the list while `demand > 0` (the panel or a detail is on screen; same `watch()` counting as `BotScreenController`), the app is foreground, unlocked, and the session is attached: once on demand, then every 5 s while any row is running or starting, with `PollBackoff` after failures. A `WorkUnsupported` stops list reads for the connection. Alternative considered: always poll while a reply runs. Rejected: frames already carry live state; the list is only a gap filler.

### 4. A detail controller per open detail

`SubagentDetailController` is created when a detail opens and disposed when it closes. It holds the tail (≤16 KiB), the note in flight, "Your notes" sent this time (memory only), the stop state (`idle → confirming → sending → stopping | alreadyEnded | unconfirmed | failed`) and the note state (`idle → sending → queued | rejected | unconfirmed | failed`). It reads `subagent.tail` on open and every 2 s while visible (`Visibility.of` and `TickerMode`), foreground and unlocked, one read in flight; it stops reading when the roster reports the agent ended, and keeps the last text as "Last output". On `WorkLost` for a stop it asks the roster to read the list at once; it never resends. The "missed" note outcome is read from the completion summary containing `steer did not land` (Hermes' wording at `d923a5eb`); when the wording changes the detail just shows the summary, which still says so in Hermes' words.

### 5. Detail inside the panel, not a new place

`ActivityPanel` gains an optional `detail` and `onBack`. `BoundActivityPanel` takes an `ActivitySelection` (a small `ValueNotifier<AgentKey?>`, owned by `ChatScreen` and `ConversationWindowScreen` per window and cleared on chat switch, profile switch and panel close) and draws the agent's detail instead of the sections when set. On the phone the sheet expands to its full detent and the detail slides in with the platform's push transition (none with reduced motion); Back returns to the list at its scroll offset. In the inspector the content swaps; Escape (a `DismissIntent` handled by the panel while a detail is shown) goes back first. `SubagentGroupCard` gains `onShowDetails: ValueChanged<String>?`; `ChatScreen` and conversation windows pass one that sets the selection and opens the panel (`_toggleActivity(source: 'transcript')`, opening only); the quick panel passes none.

Alternatives considered: a route pushed over the chat (as the Bot Screen viewer does) — rejected, the brief and the HIG put inspector content in the inspector, and a route hides the chat the user is steering; a popover on the Mac — rejected, the output needs height and must survive the agent ending.

### 6. Plain-model widgets

`lib/src/chat/subagents/widgets/`: `AgentRow` (model `AgentRowModel`), `AgentDetailView` (model `AgentDetailModel` + callbacks `onStop`, `onSendNote`, `onCopyNote`, `onBack`), `AgentOutputView` (text, truncated, following), `AgentNoteField`, `confirmStopAgent(context)`, and for processes `ProcessCardModel` additions and `confirmStopProgram(context, command)`. Confirmations use `showConfirmDialog` (Cupertino alert on Apple platforms, Material dialog elsewhere; destructive action plain red, Cancel default). Rows use `RowActions` for the iOS swipe (Stop… destructive) and the Mac context menu (Show Details, Stop Agent…). See `docs/design-briefs/subagent-control.md` for copy and layout.

### 7. Background programs

`ProcessOutputState` gains optional `command`, `status`, `exitCode`, `uptime`, merged from `process.list` by id under the same ownership rules; list reads share the roster's demand, gates and backoff (one timer per chat panel reads both lists). `process.kill` goes through `act`. Its `output` is appended through the existing bounded `apply` path, so the 64 KiB bound holds.

### 8. Old servers

Support is per method per connection (`AgentWorkSupport`, reset on a new connection): `subagent.list` unsupported → rows from frames only; `subagent.tail` unsupported → no Recent output section; `subagent.interrupt` / `subagent.steer` / `process.kill` unsupported → control removed after one sentence in the detail where it was pressed; `process.list` unsupported → process cards as today, no Stop (no list means no way to know the program still runs). The app never probes: the first real read or action learns it. `subagent.unsupported {method}` is logged once per connection. Nothing is drawn as an error.

### 9. Secrets

Output, goals, summaries, errors, notes and commands live only in `SubagentRoster`, `SubagentDetailController` and `ProcessOutputState`, in memory. They are cleared on detail close (tail, unsent note, "Your notes"), on App Lock (`unlocked` false drops the tail; the roster keeps only what rows show today), and on sign-out, server change, profile switch, connection replacement and chat retirement (everything). `toString` of these models prints counts only. No `Text` with output is ever handed to `Semantics` live regions (only the state word is announced). App switcher: App Lock's cover already hides the app; without App Lock the panel shows what the user had on screen, as the transcript does.

### 10. Telemetry

| Signal                     | Where                                                                                      | Attributes                                                                                                                                                                                                                                                  |
| -------------------------- | ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| span `subagent.rpc`        | `SubagentRepository`, each call, on the connection's `HermesRepositories.telemetry` tracer | `method` (`list`, `tail`, `interrupt`, `steer`, `process_list`, `process_kill`), `outcome` (`ok`, `not_attached`, `unsupported`, `lost`, `rejected`, `not_owned`, `server`, `other`), `tail_kib` bucket (`0`, `1-4`, `5-16`) on tail, `rows` bucket on list |
| log `subagent.stop`        | `SubagentDetailController` after a confirmed stop's answer                                 | `outcome`: `stopped`, `already_ended`, `unconfirmed`, `rejected`, `error`                                                                                                                                                                                   |
| log `subagent.redirect`    | same, after a note's answer, and `missed` when the completion says it did not land         | `outcome`: `queued`, `rejected`, `unconfirmed`, `error`, `missed`                                                                                                                                                                                           |
| log `subagent.unsupported` | `AgentWorkSupport`, once per method per connection                                         | `method`                                                                                                                                                                                                                                                    |
| log `process.stop`         | process card controller                                                                    | `outcome`: `killed`, `already_exited`, `not_found`, `unconfirmed`, `error`                                                                                                                                                                                  |
| breadcrumbs                | panel and detail                                                                           | `subagent.detail.opened` (`source`: `panel`, `transcript`), `subagent.detail.closed`, `subagent.stop.pressed`, `subagent.stop.confirmed`, `subagent.redirect.sent`, `process.stop.pressed`                                                                  |

None carries a goal, note, output, summary, error text, tool name, command, model, id or profile. Polls do not log per tick; their spans exist only while the panel is open.

## Risks / Trade-offs

- [Hermes' attachment rule changes or a connection silently detaches] → reads answer 4001 and the roster falls back to frames; actions re-attach through `session.resume` first. Covered by a test with the fake gateway that detaches the session between list and stop.
- [Polling cost: 5 s list, 2 s tail] → only while on screen, foreground and unlocked, one in flight, backoff on failure; the desktop dashboard polls at the same rates.
- [The user confuses the note field with the composer] → the field lives in the agent's detail, says "To: <goal>", has its own button label and helper text, and the composer stays visible and untouched; a test checks the composer draft is unchanged.
- [Stopping an agent loses work the user wanted] → the confirmation says exactly what stays and what stops; the agent's partial result still reaches the reply.
- [Redaction misses a secret in the output] → never logged or stored, bounded, dropped on lock and close; the app cannot do better than show what Hermes sends.
- [Clock skew makes `started_at` run times wrong] → frame time wins; `started_at` is used only for agents first seen in a list, and negative durations clamp to 0.
- [The "missed note" wording is matched by text] → only adds a sentence; the summary still shows Hermes' own words.

## Migration Plan

None. The feature appears on servers that answer the methods, hides itself on others, and stores nothing.

## Open Questions

1. **Should the transcript's agent card also get Stop?** Recommendation: no. One place to act (the panel) keeps the transcript a record; the card's rows open the detail.
2. **Should the roster read `subagent.list` when the chat is idle but its background delegations still run?** Recommendation: only when this device holds the session attached (the usual case after a reply), as specified; never resume just to look. Revisit if users report missing async agents.
3. **Should "Your notes" persist across closing the detail?** Recommendation: no; they are part of the agent's own conversation on the server, and keeping them on the device would mean storing typed text.
4. **Should the quick panel get an "Open in Hermes" link from an agent row?** Recommendation: not in this change; the quick panel's Open in Hermes (⌘O) already moves the chat to a window that has the panel.
