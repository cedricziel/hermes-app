# chat-activity Specification

## Purpose
Defines how a chat presents agent activity outside the transcript, sorted by what it asks of the user, so that only activity with something to report takes space from the conversation.

## Requirements

### Requirement: Activity is sorted into three tiers

The app SHALL assign every kind of chat activity it presents outside the transcript to exactly one tier:

- **Needs you**: activity that waits on the user: billing verification details for a pending request; a connector operation the user can still act on (unsettled, with current authority and at least one offered action, or kept display-only while the connection is lost); a reclaimed session that can be reopened; a session whose restore failed.
- **Working**: live activity of the session: transient status lines (`status.update`, including memory recall), goal, loop and heartbeat control state, the todo plan, background process output, mixture-of-agents progress and session resume progress.
- **For reference**: activity worth knowing but never urgent: session usage, side results (`/btw`, `/background`), session notices and keyed notifications, the identity-free session acknowledgement, connection-wide read-only connector activity, settled or read-only connector operations, and the billing grant result.

An activity that changes state SHALL move to the tier of its new state, for example a connector operation that settles moves from Needs you to For reference.

#### Scenario: A connector operation settles

- **WHEN** a connector operation that offered Skip and Continue reports a settled snapshot
- **THEN** it is no longer Needs you and is presented as For reference

#### Scenario: A connection-wide account update arrives

- **WHEN** a connection-wide read-only connector update arrives without profile authority
- **THEN** it is For reference and is never presented as Needs you

#### Scenario: A restore fails

- **WHEN** session resume progress reports a failed status
- **THEN** the session is Needs you and the card offers Reopen

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

The app SHALL offer an Activity panel for the open chat with three sections in this order: **Now** (Working items except the plan), **Plan** (the todo plan: its completed count and every supported task with its status), and **This session** (For reference items, closed process cards and the session status of a finished turn, plus the Verify billing access action while that action is offered). A section with no content SHALL be left out. When every section is empty the panel SHALL say that there is no activity for this chat. The panel SHALL follow the open chat: switching chats SHALL show the new chat's activity and never another chat's. Panel content SHALL follow the ownership, App Lock and retirement rules of each activity's own capability.

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

### Requirement: Needs-you items dock above the composer

The app SHALL show Needs-you items as a single card docked directly above the composer of the open chat, inside the chat column, in the main chat window in every layout, in macOS conversation windows and in the expanded quick panel (the compact one-line panel shows none and the item waits until it is expanded). The card SHALL move with the composer and SHALL be counted in the transcript's bottom padding. Needs-you items SHALL NOT also be drawn between the chat header and the transcript.

#### Scenario: A reclaimed session in the quick panel

- **WHEN** a reclaimed session is reported for the chat open in the quick panel
- **THEN** the expanded quick panel shows the card above its composer with Reopen inside its fixed height

### Requirement: Only the dock's body scrolls

The card SHALL NOT scroll with the transcript. Only its body SHALL scroll, within 40% of the height the chat column has left, so that its title and actions stay visible with the keyboard open.

#### Scenario: The keyboard opens on a small phone

- **WHEN** a connector card with three targets is docked and the keyboard opens
- **THEN** the body shrinks and scrolls and the title and actions stay visible above the composer

### Requirement: Several Needs-you items are paged oldest first

When more than one item waits, the card SHALL show the oldest first, with its position ("1 of 2") and Previous and Next controls. The shown position SHALL survive a re-render. When the shown item leaves, the next item SHALL take its place. Pointer targets SHALL be at least 28 pt and touch targets at least 44 pt (48 dp on Android).

#### Scenario: Two items wait

- **WHEN** a billing verification arrives while a connector sign-in already waits
- **THEN** the card shows the connector sign-in with "1 of 2" and the billing details are reachable with Next

#### Scenario: The shown item settles

- **WHEN** the connector operation on the card reports a settled snapshot
- **THEN** the card shows the billing details without paging and the settled operation is listed under This session in the Activity panel

### Requirement: Each Needs-you item offers its own actions

The card SHALL offer Copy code and Open verification page for billing details; the browser, Skip and Continue actions a connector operation offers under its capability rules, with its deadline; Reopen for a reclaimed session and for one whose restore failed. Skip SHALL be per target: one Skip in the action row when exactly one target can be skipped, otherwise one under each skippable target. An item SHALL leave the card when it is resolved, settles, expires, or its owning scope retires. No action of the card SHALL be a filled destructive button.

#### Scenario: A connector sign-in expires

- **WHEN** the deadline of the shown operation passes
- **THEN** the card no longer offers its actions and the operation is listed under This session as awaiting its final status

### Requirement: An answer is confirmed or reported unconfirmed within 10 seconds

After Skip or Continue the card SHALL disable both, show "Sending your answer…" and a progress indicator, and end that state within 10 seconds. A confirmed answer SHALL follow the operation's own settlement. An answer that fails or is not confirmed within 10 seconds SHALL show a warning line with an icon and the words "Couldn't confirm your answer", say that it may have gone through, and offer Skip and Continue again. The app SHALL NOT resend an answer by itself.

#### Scenario: The answer is lost

- **WHEN** no confirmation arrives within 10 seconds of Continue
- **THEN** the card shows "Couldn't confirm your answer" and Continue is offered again
- **AND** no second response was sent

#### Scenario: The server refuses

- **WHEN** the server answers Continue with a status other than ok
- **THEN** the card shows "The server refused your answer." and offers Skip and Continue again

#### Scenario: The confirmation arrives late

- **WHEN** the operation settles after the card showed "Couldn't confirm your answer"
- **THEN** the item leaves the card

### Requirement: A connector sign-in stays while the connection is lost

While the gateway connection is lost and its scope is not retired, a connector sign-in that was Needs-you SHALL stay on the card as a display-only item with Skip, Continue and Open disabled and the line "Offline. These actions come back when you're connected." The app SHALL NOT offer an action on authority it no longer holds.

#### Scenario: The network drops with a sign-in waiting

- **WHEN** the connection is lost while a connector sign-in is shown
- **THEN** the card stays with Skip, Continue and Open disabled and the Offline line
- **AND** after the reconnect restores the operation the actions are offered again

### Requirement: Billing details follow the connection, Reopen reconnects

Billing verification details SHALL leave the card when the connection is lost. Reopen SHALL stay enabled while the connection is lost, and a reclaimed or failed-restore card SHALL NOT show the Offline line, because selecting the chat reconnects it. Every item SHALL leave for the retirements its capability defines.

#### Scenario: The network drops with billing details shown

- **WHEN** the connection is lost while billing details are shown
- **THEN** the details are discarded and the item leaves the card

### Requirement: Needs-you items are announced

When an item becomes the one the card shows, the app SHALL announce it to assistive technology by its kind (for example "Billing access needs approval"), without reading a verification code, URL, target name or server-supplied reason, once per item. An item the user reaches by paging SHALL NOT be announced again. Items waiting behind the shown one, items a chat already held when it opened, and any item while the dock is not drawn (the compact quick panel) SHALL NOT be announced. The card's actions SHALL be reachable by keyboard and screen reader in the order they are drawn.

#### Scenario: A second item waits behind the first

- **WHEN** a billing verification arrives while a connector sign-in is the shown item
- **THEN** only the connector sign-in has been announced and the billing item is announced when it becomes the shown one

#### Scenario: A screen-reader user gets a billing verification

- **WHEN** billing verification details arrive
- **THEN** VoiceOver or TalkBack announces that billing access needs approval
- **AND** the code is read only when the user moves to it

### Requirement: The Activity button marks waiting items

While at least one Needs-you item waits in the open chat, the Activity button (including the macOS toolbar button) SHALL show a marker, and its accessible label SHALL include how many items need the user. The marker SHALL disappear when the last item leaves.

#### Scenario: The last item is resolved

- **WHEN** the only waiting billing request reports its result
- **THEN** the marker disappears and the label no longer mentions waiting items

### Requirement: Working activity folds into one line

Outside macOS and outside the quick panel, while the open chat has a Working item that reports a sentence, the app SHALL show one activity line directly below the chat header (above a Bot Chat banner) and nowhere else. The line SHALL show the newest Working sentence, truncated at its end (on one line; from a text scale of 2 it MAY use two lines). Activating the line SHALL open the Activity panel. The line SHALL disappear when no Working item is left or the turn settles, and while the Activity inspector is docked beside the chat or drawn over it; on a phone the sheet covers the chat and the line stays beneath it.

#### Scenario: Memory recall during a planned turn

- **WHEN** status.update reports a memory recall while a plan with two of five tasks done is known
- **THEN** the line reads the recall sentence with a "2/5" plan counter

#### Scenario: The turn settles

- **WHEN** the reply completes, is interrupted, fails or is stopped
- **THEN** the line disappears, even if a plan task is still open or a process card is still open

#### Scenario: Opening details from the line

- **WHEN** the user taps the line on a phone
- **THEN** the Activity panel opens as a sheet

#### Scenario: Only a plan is open

- **WHEN** a reply is in flight, a plan has an open task and no other Working item reports a sentence
- **THEN** the line reads "Working on the plan" with the plan counter

### Requirement: Working is scoped to the turn

The line and the macOS toolbar subtitle SHALL count as working only while a reply is in flight, a session resume is loading, or a mixture-of-agents card is live during a reply. Status, lifecycle, memory-recall, goal, loop, heartbeat and plan sentences, the plan counter and process cards SHALL count only while a reply is in flight. A status that arrived before the previous reply ended SHALL NOT return with a later reply, while one that arrives ahead of a server-started reply SHALL count. A loading resume SHALL stop counting when the connection drops or the session is reclaimed. Because the backend sends no process-exit signal, a process that is still running after the reply ended SHALL NOT be reported by the line. Goal, loop and heartbeat sentences SHALL come from the control state while its section is active, not from their status text.

#### Scenario: A plan is left open

- **WHEN** a reply is interrupted with a plan task still open
- **THEN** the line is gone and the plan stays in the Activity panel

#### Scenario: A status of an earlier turn

- **WHEN** a new reply starts after a reply that ended with a status sentence
- **THEN** the earlier status is not the line's sentence

#### Scenario: A resume is cut off

- **WHEN** the connection drops while a session resume is loading
- **THEN** the line no longer says the chat is being restored

### Requirement: Only Working sentences feed the line

The Bot screen card, Needs-you items and For reference items SHALL NOT feed the line or the macOS toolbar subtitle.

#### Scenario: A usage snapshot arrives

- **WHEN** a session usage snapshot arrives while nothing is working
- **THEN** no line is shown

### Requirement: The line shows only reported counters

The line SHALL show at most two counters at its trailing side, the most recently changed first, when their values are known: the plan's completed and total tasks while a task is open and a reply is in flight, the number of running processes, and mixture-of-agents references done and total. A counter that repeats the sentence SHALL be left out. Counters not shown SHALL stay in the Activity panel. Counters SHALL use only reported values and SHALL be left out when unknown. When the sentence does not fit beside the counters on one row, the counters SHALL become compact (icon and number only, their words kept in the accessible name), and if it still does not fit, one counter SHALL be shown, the one that changed last; a counter SHALL NOT be cut or overflow.

#### Scenario: Three counters are known

- **WHEN** a plan, a process and mixture-of-agents progress all report values
- **THEN** the line shows the two that changed last and the panel shows all three

#### Scenario: A long sentence

- **WHEN** a 90-character sentence and two counters do not fit on one row
- **THEN** the counters are compact, and if the sentence still does not fit one counter remains

#### Scenario: A counter is unknown

- **WHEN** mixture-of-agents progress reports no total
- **THEN** the line shows no references counter

### Requirement: The line is a touch target of constant height

The line SHALL be at least 44 pt tall on Apple platforms and 48 dp on Material and desktop Material, and its height SHALL NOT change while its sentence changes. It SHALL follow the selected text size with no cap; from a text scale of 1.5 it SHALL use two rows, the sentence over the counters, at a constant height for that scale (also when no counter is known), and from a text scale of 2 the sentence MAY use two lines. It SHALL be one button whose accessible name gives the sentence and the known counters, and sentence changes SHALL NOT be announced.

#### Scenario: The largest text size

- **WHEN** the text size is the largest and the sentence is long
- **THEN** the line shows the sentence on one row and its counters on a second row without cutting a counter

### Requirement: macOS shows Working activity in the toolbar

On macOS, in the main window and in conversation windows, the app SHALL NOT show an activity line. While the chat has a Working item that reports a sentence, the toolbar subtitle SHALL append the newest Working sentence, with a progress indicator, after the profile and model; it SHALL truncate before the profile and model do, and when too little room is left for a readable status the progress indicator, separator and status SHALL all be left out. When nothing is working the subtitle SHALL return to profile and model only. The quick panel SHALL show no Working status.

#### Scenario: A process runs in a conversation window

- **WHEN** a background process starts in a chat open in its own window
- **THEN** that window's toolbar subtitle shows the running sentence and the main window's subtitle is unchanged

### Requirement: Only the activity line sits above the transcript

Between the chat header and the transcript the app SHALL draw at most the activity line, and a Bot Chat banner, which is not activity. Working details SHALL be shown in the Activity panel (Now and Plan), Needs-you items in the card docked above the composer, and For reference items in the Activity panel.

#### Scenario: Every tier is busy

- **WHEN** a plan, a process, a usage snapshot and a pending billing verification exist together
- **THEN** only the activity line sits between the header and the transcript, the billing card is above the composer, and the usage snapshot is in the Activity panel

### Requirement: The Activity panel lists process output under Now

The Activity panel SHALL list open background process cards and the omission note under Now with the other Working items. Closed process cards SHALL be listed under This session. The session status SHALL be listed under Now while it holds control, a resume or a wait of the reply running now, and under This session otherwise.

#### Scenario: A process runs

- **WHEN** the panel is opened while a background process card is open
- **THEN** its output card is under Now

#### Scenario: A process card closes

- **WHEN** the backend closes a process card
- **THEN** the card is listed under This session
