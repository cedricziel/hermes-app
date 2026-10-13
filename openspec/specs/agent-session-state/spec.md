## Purpose

Defines session control and recovery status in the Hermes app so users can inspect backend-reported activity without changing the agent protocol.

## Requirements

### Requirement: Control state remains distinct from reply state

The app SHALL show goal, loop, and heartbeat values from SessionControlSnapshot in a compact session status card with expandable details. Null sections SHALL disappear. Goal turns_used and max_turns, loop ticks_fired and next_due_at, and heartbeat fire_count SHALL use reported values. The app SHALL treat revision as an opaque identity, not a sortable counter. It SHALL NOT mark a reply complete because a control section changes.

#### Scenario: A goal pauses during a turn

- **WHEN** session.control.update reports paused_reason
- **THEN** the status card explains the pause while reply state remains governed by turn events

### Requirement: Transient status explains waits

The app SHALL show nonempty status.update.text for status, lifecycle, goal, loop, heartbeat, and process kinds, while preserving compacting presentation. Empty text SHALL clear the matching transient line. Unknown kinds SHALL use neutral styling and SHALL NOT change control state or reply success. Persistent control remains visible when transient text clears.

#### Scenario: A transient process wait clears

- **WHEN** an empty status.update arrives for that kind
- **THEN** the wait disappears while the persisted goal card remains

### Requirement: Reclaim and hydration follow the owning session

The app SHALL route session.reclaimed using its payload session_id and stored_session_id even when its event envelope is broadcast. It SHALL invalidate the matching live binding, retire pending local requests, stop accepting actions against that runtime, and show the reported reason as untrusted text. It SHALL offer the existing reopen flow without replaying submitted prompts. Resume progress SHALL show phase and loading, complete, or failed status without inventing a percentage.

#### Scenario: Another client reclaims a session

- **WHEN** the matching reclaim broadcast arrives
- **THEN** the old runtime actions are disabled and reopening does not resubmit the last prompt

### Requirement: Control restoration tolerates older servers

After a runtime is attached, the app SHALL use session.control.read with its session_id and owning profile to restore control. A method-not-found response SHALL leave control unavailable without failing chat. A delayed read SHALL NOT overwrite a control event observed after that read began. Hydration failure SHALL offer the existing retry or reopen flow and retain already loaded history.

#### Scenario: An older gateway lacks control.read

- **WHEN** the app attaches to a thread
- **THEN** chat remains usable without a fabricated control snapshot

### Requirement: Existing backend contract and compatibility

The app SHALL use the existing dashboard `/api/ws` JSON-RPC contract for status.update, session.control.update, session.reclaimed, session.resume_progress; session.control.read; session.resume. The tested baseline SHALL be Hermes Agent commit `167e9fdb84248cd0fff80762dc57b6a914b6e930`, recorded in `openrpc/HERMES_REF`; a minimum semantic release containing every required field is not established. Older backends SHALL keep ordinary chat usable when these optional events or methods are absent. Unsupported actions SHALL be unavailable, and malformed optional payloads SHALL not break the event stream. No backend route, protocol extension, or token-storage change SHALL be required.

`session.control.read` takes required `session_id` and optional `profile`, returning `{control}`. Control contains nullable `goal`, `loop`, and `heartbeat`, string `revision`, and numeric `updated_at`. `session.resume` returns the attached `session_id`, optional `stored_session_id`, optional `hydrating`, and existing session information. This proposal does not call `session.control` mutations.

The event shapes are:

- `status.update`: `StatusUpdatePayload`, required `kind`, `text`.
- `session.control.update`: `SessionControlUpdatePayload`, required `control`.
- `session.reclaimed`: `SessionReclaimedPayload`, required `session_id`, `stored_session_id`, `reason`.
- `session.resume_progress`: `SessionResumeProgressPayload`, required `phase`, `status`; optional `message_count`, `message`.

#### Scenario: Optional capability is absent

- **WHEN** an older backend omits this capability or refuses an optional method as unsupported
- **THEN** ordinary chat remains usable and the app reports unavailable functionality without inventing state or submitting speculative requests
