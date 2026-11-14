# Spec Delta

## MODIFIED Requirements

### Requirement: Activity is sorted into three tiers

The app SHALL assign every kind of chat activity it presents outside the transcript to exactly one tier:

- **Needs you**: activity that waits on the user: billing verification details for a pending request; a connector operation the user can still act on (unsettled, with current authority and at least one offered action); a reclaimed session that can be reopened.
- **Working**: live activity of the session: transient status lines (`status.update`, including memory recall), goal, loop and heartbeat control state, the todo plan, background process output, mixture-of-agents progress, session resume progress, and delegated agents that are running.
- **For reference**: activity worth knowing but never urgent: session usage, side results (`/btw`, `/background`), session notices and keyed notifications, the identity-free session acknowledgement, connection-wide read-only connector activity, settled or read-only connector operations, the billing grant result, and delegated agents that have ended (finished, failed, stopped, or no longer listed by the server) or whose background delegation failed.

An activity that changes state SHALL move to the tier of its new state, for example a connector operation that settles moves from Needs you to For reference, and a delegated agent that finishes moves from Working to For reference.

#### Scenario: A connector operation settles

- **WHEN** a connector operation that offered Skip and Continue reports a settled snapshot
- **THEN** it is no longer Needs you and is presented as For reference

#### Scenario: A connection-wide account update arrives

- **WHEN** a connection-wide read-only connector update arrives without profile authority
- **THEN** it is For reference and is never presented as Needs you

#### Scenario: A delegated agent finishes

- **WHEN** a running agent listed under Now receives `subagent.complete` with status `completed`
- **THEN** its row leaves Now and is listed under This session as Finished

### Requirement: No new backend contract

The tiers SHALL be derived only from the existing dashboard `/api/ws` JSON-RPC frames and methods the agent-visibility capabilities already consume (OpenRPC baseline recorded in `openrpc/HERMES_REF`), plus the session-scoped `subagent.list` read that the subagent-control capability defines. No backend route, protocol extension or minimum Hermes version SHALL be introduced; a method a server does not offer SHALL leave the tiers derived from frames alone. A server that sends none of these frames SHALL show no activity other than the user-invoked entries whose support is still unknown: the idle Verify billing access action and the Session usage entry. These remain until the Activity panel offers them.

#### Scenario: A server sends no activity frames

- **WHEN** a turn completes with only message frames
- **THEN** no activity is drawn beyond the idle Verify billing access and Session usage entries, and chat works as before

#### Scenario: A server without subagent.list

- **WHEN** `subagent.list` answers method-not-found and a reply delegates two agents
- **THEN** both agents are listed under Now from their `subagent.*` frames and nothing reports the missing method

## ADDED Requirements

### Requirement: Activity items can open a detail in the panel

An Activity panel item with more to show than its row SHALL open that detail inside the panel: a page pushed within the phone sheet, or the inspector's content on wide layouts, with a back control labelled "Activity" returning to the list at its scroll position. Switching chats or closing the panel SHALL close the detail. Escape SHALL return to the list before it closes an inspector. A detail SHALL NOT open a window, a route over the chat, or a sheet on the Mac.

#### Scenario: Opening an agent's detail on an iPhone

- **WHEN** the Activity sheet is open at medium height and the user taps an agent row
- **THEN** the agent's detail is pushed within the sheet, the sheet grows to full height, and a back control labelled Activity returns to the list

#### Scenario: Escape in a Mac inspector

- **WHEN** an agent's detail is shown in an inspector drawn over a narrow Mac window and the user presses Escape
- **THEN** the panel returns to the list and stays open; a second Escape closes it

#### Scenario: Switching chats while a detail is open

- **WHEN** an agent's detail is open in the inspector and the user selects another chat
- **THEN** the inspector shows the new chat's activity list, not the detail
