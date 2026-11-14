# chat-activity Specification

## Purpose
Defines how a chat presents agent activity outside the transcript, sorted by what it asks of the user, so that only activity with something to report takes space from the conversation.

## Requirements

### Requirement: Activity is sorted into three tiers

The app SHALL assign every kind of chat activity it presents outside the transcript to exactly one tier:

- **Needs you**: activity that waits on the user: billing verification details for a pending request; a connector operation the user can still act on (unsettled, with current authority and at least one offered action); a reclaimed session that can be reopened.
- **Working**: live activity of the session: transient status lines (`status.update`, including memory recall), goal, loop and heartbeat control state, the todo plan, background process output, mixture-of-agents progress and session resume progress.
- **For reference**: activity worth knowing but never urgent: session usage, side results (`/btw`, `/background`), session notices and keyed notifications, the identity-free session acknowledgement, connection-wide read-only connector activity, settled or read-only connector operations, and the billing grant result.

An activity that changes state SHALL move to the tier of its new state, for example a connector operation that settles moves from Needs you to For reference.

#### Scenario: A connector operation settles

- **WHEN** a connector operation that offered Skip and Continue reports a settled snapshot
- **THEN** it is no longer Needs you and is presented as For reference

#### Scenario: A connection-wide account update arrives

- **WHEN** a connection-wide read-only connector update arrives without profile authority
- **THEN** it is For reference and is never presented as Needs you

### Requirement: Empty and unknown states draw nothing

The app SHALL NOT draw a row, card or label for an activity kind whose state is empty, unknown or unsupported by the server. In particular it SHALL NOT show "Plan unavailable" when no plan state was ever received, an unsupported-usage row when `session.usage` is not offered, or a billing-unavailable row when `billing.step_up` is not offered. When every activity kind of a chat is empty, the chat SHALL take no space for activity between its header and its transcript. A state that had a value before and has become stale or malformed SHALL keep the stale or unavailable label its own capability defines.

#### Scenario: A chat on an older server

- **WHEN** a chat's server has answered `session.usage` and `billing.step_up` with method-not-found and has sent no plan or other activity
- **THEN** the transcript starts directly below the chat header

#### Scenario: Known usage goes stale

- **WHEN** usage was shown and the connection then closes
- **THEN** the last values stay visible with their stale label

### Requirement: No new backend contract

The tiers SHALL be derived only from the existing dashboard `/api/ws` JSON-RPC frames and methods the agent-visibility capabilities already consume (OpenRPC baseline Hermes Agent commit `71d34bad1045610252eda02ee79549436896e784`, recorded in `openrpc/HERMES_REF`). No backend route, protocol extension or minimum Hermes version SHALL be introduced. A server that sends none of these frames SHALL show no activity other than the user-invoked entries whose support is still unknown: the idle Verify billing access action and the Session usage entry. These remain until the Activity panel offers them.

#### Scenario: A server sends no activity frames

- **WHEN** a turn completes with only message frames
- **THEN** no activity is drawn beyond the idle Verify billing access and Session usage entries, and chat works as before

### Requirement: Activity panel

The app SHALL offer an Activity panel for the open chat with three sections in this order: **Now** (Working items except the plan), **Plan** (the todo plan: its completed count and every supported task with its status), and **This session** (For reference items, plus the Verify billing access action while that action is offered). A section with no content SHALL be left out. When every section is empty the panel SHALL say that there is no activity for this chat. The panel SHALL follow the open chat: switching chats SHALL show the new chat's activity and never another chat's. Panel content SHALL follow the ownership, App Lock and retirement rules of each activity's own capability.

#### Scenario: A chat with a plan and usage

- **WHEN** the user opens the Activity panel on a chat with a plan of five tasks, two done, and a usage snapshot
- **THEN** the panel shows Plan · 2 of 5 with the tasks, and This session with the token total
- **AND** no Now section is drawn

#### Scenario: The user switches chats with the panel open

- **WHEN** the inspector is open and the user selects another chat
- **THEN** the inspector stays open and shows only the newly selected chat's activity

### Requirement: Activity panel placement per form factor

The Activity panel SHALL open as a bottom sheet in a phone layout (an Apple detent sheet that opens at medium height and can be dragged to full height on iOS; a Material modal bottom sheet on Android) and as an inspector on the right side of the chat in a window at least 760 logical pixels wide (a full-screen iPad, macOS, Windows, Linux). Below 760 logical pixels in a desktop or iPad layout the inspector SHALL be drawn over the chat instead of beside it. The inspector SHALL keep the chat column usable: beside the chat it SHALL NOT narrow the chat column below its readable minimum, and over the chat it SHALL close with Escape or a tap outside.

#### Scenario: Opening on an iPhone

- **WHEN** the user opens the Activity panel on an iPhone
- **THEN** a sheet rises at medium height above the chat

#### Scenario: A narrow Mac window

- **WHEN** the inspector is open and the Mac window is resized below 760 points
- **THEN** the inspector is drawn over the chat and Escape closes it

### Requirement: Activity button

The chat header SHALL show an Activity button whenever a chat is open, in every layout; on macOS it SHALL be a toolbar button. It SHALL open the panel, and in an inspector layout close it again, showing whether the inspector is open. On macOS, View > Inspector (⌥⌘I) SHALL toggle the inspector of the key window's chat, in the main window and in conversation windows. The quick panel SHALL NOT offer the Activity panel.

#### Scenario: Toggling from the menu bar

- **WHEN** a conversation window is key and the user chooses View > Inspector
- **THEN** that window's Activity inspector opens and the main window's is unchanged

#### Scenario: The quick panel

- **WHEN** the quick panel shows a chat
- **THEN** it offers no Activity button and no inspector

### Requirement: Reference activity lives only in the Activity panel

For reference items SHALL be shown only in the Activity panel's This session section and SHALL NOT take space between the chat header and the transcript. Settled and read-only connector operations, connection-wide connector activity, session usage, side results, session notices and keyed notifications, the session acknowledgement and the billing grant result SHALL appear there. Keyed notices SHALL keep their replacement, withdrawal and expiry rules inside the panel.

#### Scenario: A side answer arrives during a turn

- **WHEN** btw.complete arrives while the main reply streams
- **THEN** nothing is added above the transcript and the answer is listed under This session

#### Scenario: A keyed notice expires while the panel is closed

- **WHEN** a notice with a positive ttl expires before the user opens the panel
- **THEN** the panel does not list it
