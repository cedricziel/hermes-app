# Spec Delta

## ADDED Requirements

### Requirement: Needs-you items dock above the composer

The app SHALL show Needs-you items as a single card docked directly above the composer of the open chat, inside the chat column, in the main chat window in every layout, in macOS conversation windows and in the quick panel. The card SHALL move with the composer and SHALL be counted in the transcript's bottom padding. Needs-you items SHALL NOT also be drawn between the chat header and the transcript.

#### Scenario: A reclaimed session in the quick panel

- **WHEN** a reclaimed session is reported for the chat open in the quick panel
- **THEN** the quick panel shows the card above its composer with Reopen and grows to fit it

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
- **THEN** the card shows the billing details as "1 of 1" and the settled operation is listed under This session in the Activity panel

### Requirement: Each Needs-you item offers its own actions

The card SHALL offer Copy code and Open verification page for billing details; the browser, Skip and Continue actions a connector operation offers under its capability rules, with its deadline; Reopen for a reclaimed session and for one whose restore failed. An item SHALL leave the card when it is resolved, settles, expires, or its owning scope retires. No action of the card SHALL be a filled destructive button.

#### Scenario: A connector sign-in expires

- **WHEN** the deadline of the shown operation passes
- **THEN** the card no longer offers its actions and the operation is listed under This session as awaiting its final status

### Requirement: An answer is confirmed or reported unconfirmed within 10 seconds

After Skip or Continue the card SHALL disable both, show "Sending your answer…" and a progress indicator, and end that state within 10 seconds. A confirmed answer SHALL follow the operation's own settlement. An answer that is refused, fails, or is not confirmed within 10 seconds SHALL show a warning line with an icon and the words "Couldn't confirm your answer", say that it may have gone through, and offer Skip and Continue again. The app SHALL NOT resend an answer by itself.

#### Scenario: The answer is lost

- **WHEN** no confirmation arrives within 10 seconds of Continue
- **THEN** the card shows "Couldn't confirm your answer" and Continue is offered again
- **AND** no second response was sent

#### Scenario: The confirmation arrives late

- **WHEN** the operation settles after the card showed "Couldn't confirm your answer"
- **THEN** the item leaves the card

### Requirement: Needs-you items stay while the connection is lost

While the gateway connection is lost and reconnecting, an item that was Needs-you SHALL stay on the card with its server actions (Skip, Continue, Open on a connector, Reopen) disabled and the line "Offline. These actions come back when you're connected." Copy code and the billing Open verification page SHALL stay available while the details are held. The item SHALL leave for every retirement its own capability defines, and the app SHALL NOT offer an action on authority it no longer holds.

#### Scenario: The network drops with a sign-in waiting

- **WHEN** the connection is lost while a connector sign-in is shown
- **THEN** the card stays with Skip and Continue disabled and the Offline line
- **AND** after the reconnect restores the operation the actions are offered again

### Requirement: Needs-you items are announced

When an item reaches the card, the app SHALL announce it to assistive technology by its kind (for example "Billing access needs approval"), without reading a verification code, URL, target name or server-supplied reason, once per item. The card's actions SHALL be reachable by keyboard and screen reader in the order they are drawn.

#### Scenario: A screen-reader user gets a billing verification

- **WHEN** billing verification details arrive
- **THEN** VoiceOver or TalkBack announces that billing access needs approval
- **AND** the code is read only when the user moves to it

### Requirement: The Activity button marks waiting items

While at least one Needs-you item waits in the open chat, the Activity button (including the macOS toolbar button) SHALL show a marker, and its accessible label SHALL include how many items need the user. The marker SHALL disappear when the last item leaves.

#### Scenario: The last item is resolved

- **WHEN** the only waiting billing request reports its result
- **THEN** the marker disappears and the label no longer mentions waiting items

## MODIFIED Requirements

### Requirement: Activity is sorted into three tiers

The app SHALL assign every kind of chat activity it presents outside the transcript to exactly one tier:

- **Needs you**: activity that waits on the user: billing verification details for a pending request; a connector operation the user can still act on (unsettled, with current authority and at least one offered action, or one that was so until the connection was lost); a reclaimed session that can be reopened; a session whose restore failed.
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
