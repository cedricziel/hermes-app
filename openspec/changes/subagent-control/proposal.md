# Proposal

## Why

Hermes hands parts of a reply to delegated agents (subagents) and starts background programs, and the app already shows both: a "Used 3 agents" card in the transcript and "Process … · Output received" cards in the Activity panel. The user can watch but cannot act. When an agent heads the wrong way or a program runs away, the only lever is stopping the whole reply, which throws away the work that was fine. Hermes' gateway now lets an owning client list a session's agents, read an agent's recent output, stop one agent, and send one agent a note without stopping it (`subagent.list|tail|interrupt|steer`), and list and stop the session's own background programs (`process.list|kill`). This change gives those levers to the user, inside the Activity panel they already open for live work (roadmap item 4.4).

## What Changes

- **Agents in the Activity panel.** Each delegated agent of the open chat becomes a row in the panel: running ones under **Now** (Working tier), ended ones under **This session** (For reference). A row shows what the agent was asked to do, its state in words and icon, what it is doing now, and how long it has run. The rows are fed by the `subagent.*` frames the app already maps, and filled in by `subagent.list` (agents that started before this device attached, after a reconnect, and recently failed background delegations) while the panel is on screen.
- **Agent detail.** Tapping a row opens the agent's detail inside the panel (a page in the phone sheet, the inspector's content on wide layouts, with a back control to the list). It shows the goal, state, tool count, run time, the last part of its live output from `subagent.tail` (at most 16 KiB, plain text, refreshed every 2 s while visible), and, once it ended, what it delivered.
- **Stop an agent.** A destructive Stop, confirmed first, that says what happens: the agent stops after its current step with the agents it started, what it already did stays, and the reply goes on without the rest; programs it started keep running. Sent with `subagent.interrupt`; a lost answer is re-read with `subagent.list`, never resent. Stop is a secondary action after the output; reading is the detail's main job.
- **Agents this device cannot control.** Hermes lists agents a chat owns through its history (for example after the server rebuilt the session), but stops and redirects only those of the session's current run. When a stop or note is refused for an agent the list still shows running, the app says Hermes doesn't let this device control it, and never that it finished.
- **Redirect an agent.** A separate note field in the agent's detail, addressed to that agent by name and visually unlike the chat composer, sent with `subagent.steer`. The copy says the note goes only to this agent after its current step, and that it is not added to the chat. "Queued" is reported as queued, not delivered; a rejected or unconfirmed note keeps its text and says so.
- **The transcript card links to the detail.** In the transcript's agent card, each agent row opens its detail in the Activity panel where the surface has one (main window, Mac conversation windows). The card stays read-only in the quick panel.
- **An agent that ends while its detail is open** keeps its detail: the state changes, the controls go away with a sentence saying why, the last output read stays (labelled as the last output), the summary appears, and an unsent note stays visible but cannot be sent.
- **Background programs.** The Activity panel's process cards gain the program's command, state and exit code from `process.list` (session-scoped), and a confirmed Stop with `process.kill` that says the agent will not be told the program finished.
- **Old servers.** A gateway that answers method-not-found for any of these methods hides the matching control for that connection; the agent rows still show from frames, as today. Nothing reads as an error.

## Non-goals

- `delegation.pause` and `delegation.status`: they act on the whole server (every user's and every session's spawning) and do not belong in a chat; a later "Server care" change (roadmap 4.7) may offer them with that scope stated.
- `process.stop` (kills every background program on the server) and `agents.list` (server-wide list): never offered from a chat.
- `spawn_tree.list|load|save`: saved snapshots of finished agent trees that the terminal UI writes; reading old trees is history browsing, not control, and is left for a later change.
- `session.steer` and `session.redirect` for the main agent, `prompt.background` and `prompt.btw` (starting side work): the composer already folds a message into a running turn (`redirected`/`steered`), and starting side work is a composer feature for its own change. Their results (`background.complete`, `btw.complete`) already show.
- A Stop all agents action, steering several agents at once, editing or cancelling a queued note (Hermes has no call for it), and notifications about agents.
- An Activity panel for the Mac quick panel.
- The watch, widgets, Live Activities and the surface snapshot: none of them gains agent content.

## Capabilities

### New Capabilities

- `subagent-control`: listing a chat's delegated agents with their state, reading an agent's recent output, stopping an agent and sending it a note, on servers that offer it, with the bounds, confirmations and failure handling that go with them.

### Modified Capabilities

- `chat-activity`: delegated agents join the tiers (running agents are Working, ended agents For reference), the panel can show an item's detail in place, and the "no new backend contract" rule names the methods this change relies on.
- `agent-process-output`: process cards show the program's command and state from `process.list`, and can be stopped with `process.kill` after a confirmation.

## Impact

- Gateway transport: new session-scoped calls on `HermesGatewayTransport` and `SessionChatTransport` (through a narrow interface, like `GatewayRequester`) that resolve the chat's runtime session on the connection that holds it, as `undoLastTurn` does; `FakeChatTransport` and the fake gateway gain them.
- New `lib/src/chat/subagents/`: repository with lenient parsing and sealed results, `SubagentControlController` (one per chat thread, owned like the other per-thread activity controllers), plain-model widgets (agent row, detail, stop confirmation, note field), Widgetbook use cases.
- `lib/src/chat/process_output_state.dart` and `ProcessOutputCard` gain command, state and Stop.
- `BoundActivityPanel` and `ActivityPanel` gain the agent rows and an in-panel detail page; `SubagentGroupCard` gains a per-row "details" action; `ChatScreen`, `ConversationWindowScreen` wire it.
- `test/gateway/gateway_contract_test.dart` records the methods the app now calls; the real-backend contract test checks the answer shapes.
- `docs/design-briefs/subagent-control.md` holds the visual brief; `CLAUDE.md` (Chat, Activity) and `design/web` are updated with the screens.
- No REST route, no OpenAPI change, no native, entitlement or manifest change.

## Security and privacy

- An agent's output and goal can hold anything the agent read, including secrets that Hermes' redaction missed. The app keeps the output in memory only, at most 16 KiB per open detail, drops it when the detail closes, the app is locked, the user signs out, the profile changes or the connection changes, and never logs it, sends it to telemetry, stores it, or shows it in notifications, widgets, Live Activities, Spotlight or the surface snapshot. Output is drawn as plain text: no links are opened, no markup is run.
- A note the user types is sent once to the agent and kept only in the field until it is sent or the detail closes. It is never stored or logged.
- Stop and Redirect act only on the agents of the chat's own session on a connection Hermes accepts as that session's (Hermes enforces this; the app never retries on another connection without first attaching it with `session.resume`).
- App Lock: while the app is covered, polling stops and the output is dropped; the agent rows keep only what the panel already shows today.
- No token, credential or secure-storage change.

## Observability

- Span `subagent.rpc` around each `subagent.list|tail|interrupt|steer` and `process.list|kill` call (attributes `method`, `outcome`), on the connection's gateway tracer: a socket round trip whose failures need explaining.
- Log event `subagent.stop` (`outcome`: `stopped`, `already_ended`, `unconfirmed`, `rejected`, `error`) and `subagent.redirect` (`outcome`: `queued`, `rejected`, `unconfirmed`, `error`, `missed`): outcomes worth counting. Log event `process.stop` (`outcome`: `killed`, `already_exited`, `not_found`, `unconfirmed`, `error`).
- Log event `subagent.unsupported` (`method`) once per connection: how many servers lack the calls.
- Breadcrumbs `subagent.detail.opened` (`source`: `panel` or `transcript`), `subagent.detail.closed`, `subagent.stop.pressed`, `subagent.stop.confirmed`, `subagent.redirect.sent`, `process.stop.pressed`: user steps that explain a later crash.
- Attributes are fixed words, counts and buckets only (`running` count bucket, `tail_kib` bucket). Never a goal, note, output, tool name, command, id or profile.
