# Spec Delta

## ADDED Requirements

### Requirement: Needs-you items dock above the composer

The app SHALL show Needs-you items as a single card docked directly above the composer of the open chat, inside the chat column, in the main chat window in every layout, in macOS conversation windows and in the quick panel. The card SHALL NOT scroll with the transcript. When several items wait, the card SHALL show the oldest first and SHALL offer moving to the previous and next item with its position ("1 of 2"). The card SHALL offer the item's own actions under that item's capability rules: Open verification and Copy code for billing details; the offered browser, Skip and Continue actions for a connector operation, with its deadline; Reopen for a reclaimed session. An item SHALL leave the card when it is resolved, settles, expires, or its owning scope retires; the next waiting item SHALL then take its place. Needs-you items SHALL NOT also be drawn between the chat header and the transcript.

#### Scenario: Two items wait

- **WHEN** a billing verification arrives while a connector sign-in already waits
- **THEN** the card shows the connector sign-in with "1 of 2" and the billing details are reachable with next

#### Scenario: The shown item settles

- **WHEN** the connector operation on the card reports a settled snapshot
- **THEN** the card shows the billing details as "1 of 1" and the settled operation is listed under This session in the Activity panel

#### Scenario: The quick panel

- **WHEN** a reclaimed session is reported for the chat open in the quick panel
- **THEN** the quick panel shows the card above its composer with Reopen

### Requirement: Needs-you items are announced

When an item reaches the card, the app SHALL announce it to assistive technology by its kind (for example "Billing access needs approval"), without reading a verification code, URL or server-supplied reason. The card's actions SHALL be reachable by keyboard and screen reader in the order they are drawn.

#### Scenario: A screen-reader user gets a billing verification

- **WHEN** billing verification details arrive
- **THEN** VoiceOver or TalkBack announces that billing access needs approval
- **AND** the code is read only when the user moves to it

### Requirement: The Activity button marks waiting items

While at least one Needs-you item waits in the open chat, the Activity button SHALL show a marker, and its accessible label SHALL include how many items need the user. The marker SHALL disappear when the last item leaves.

#### Scenario: The last item is resolved

- **WHEN** the only waiting billing request reports its result
- **THEN** the marker disappears and the label no longer mentions waiting items
