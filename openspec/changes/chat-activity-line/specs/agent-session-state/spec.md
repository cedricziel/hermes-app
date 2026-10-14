# Spec Delta

## MODIFIED Requirements

### Requirement: Control state remains distinct from reply state

The app SHALL show goal, loop, and heartbeat values from SessionControlSnapshot as Working activity: a compact summary in the activity line (or the macOS toolbar subtitle) and expandable details in the Activity panel's Now section. Null sections SHALL disappear. Goal turns_used and max_turns, loop ticks_fired and next_due_at, and heartbeat fire_count SHALL use reported values. The app SHALL treat revision as an opaque identity, not a sortable counter. It SHALL NOT mark a reply complete because a control section changes.

#### Scenario: A goal pauses during a turn

- **WHEN** session.control.update reports paused_reason
- **THEN** the Activity panel explains the pause while reply state remains governed by turn events

### Requirement: Transient status explains waits

The app SHALL show nonempty status.update.text for status, lifecycle, goal, loop, heartbeat, and process kinds as the newest Working sentence of the activity line (or the macOS toolbar subtitle) and in the Activity panel's Now section, while preserving compacting presentation. Empty text SHALL clear the matching transient line. Unknown kinds SHALL use neutral styling and SHALL NOT change control state or reply success. Persistent control remains visible when transient text clears.

#### Scenario: A transient process wait clears

- **WHEN** an empty status.update arrives for that kind
- **THEN** the wait disappears while the persisted goal remains in the Activity panel

#### Scenario: A memory provider reports a recall

- **WHEN** status.update arrives with a memory recall sentence
- **THEN** that sentence is the activity line's text until a newer Working sentence arrives or it clears
