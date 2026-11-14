# Spec Delta

## MODIFIED Requirements

### Requirement: Control state remains distinct from reply state

The app SHALL show goal, loop, and heartbeat values from SessionControlSnapshot as Working activity: while their section is active and a reply is in flight, the goal's title and the loop's and heartbeat's prompts are Working sentences of the activity line (or the macOS toolbar subtitle), and expandable details are in the Activity panel's Now section while the session holds control. Null sections SHALL disappear. Goal turns_used and max_turns, loop ticks_fired and next_due_at, and heartbeat fire_count SHALL use reported values. The app SHALL treat revision as an opaque identity, not a sortable counter. It SHALL NOT mark a reply complete because a control section changes.

#### Scenario: A goal pauses during a turn

- **WHEN** session.control.update reports paused_reason
- **THEN** the Activity panel explains the pause while reply state remains governed by turn events

### Requirement: Transient status explains waits

The app SHALL show nonempty status.update.text for status, lifecycle, goal, loop, heartbeat, and process kinds in the Activity panel's Now section while it belongs to the reply running now (a wait of an earlier reply is listed under This session), while preserving compacting presentation. For status, lifecycle and process kinds and memory recalls, it SHALL also be the newest Working sentence of the activity line (or the macOS toolbar subtitle) while a reply is in flight; goal, loop and heartbeat status text SHALL NOT be line sentences, which come from control state. Empty text SHALL clear the matching transient line. Unknown kinds SHALL use neutral styling and SHALL NOT change control state or reply success. Persistent control remains visible when transient text clears.

#### Scenario: A transient process wait clears

- **WHEN** an empty status.update arrives for that kind
- **THEN** the wait disappears while the persisted goal remains in the Activity panel

#### Scenario: A memory provider reports a recall

- **WHEN** status.update arrives with a memory recall sentence
- **THEN** that sentence is the activity line's text until a newer Working sentence arrives, it clears or the reply ends
