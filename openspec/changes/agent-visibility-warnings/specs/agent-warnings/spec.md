## Purpose

Defines agent warnings and notices in the Hermes app so users can inspect backend-reported activity without changing the agent protocol.

## ADDED Requirements

### Requirement: Tool risk stays with its tool

The app SHALL associate tool.output_risk with tool_id within the owning server, profile, and runtime session. It SHALL show the risk label and redacted flag in a compact tool card, with findings available in details. It SHALL treat findings as untrusted text and SHALL NOT reconstruct redacted output. A risk arriving before its tool SHALL wait for that identity rather than attach to another tool.

#### Scenario: A risk arrives before tool.start

- **WHEN** the matching tool later appears
- **THEN** the risk is attached exactly once to that tool and no other

### Requirement: Keyed notices can be replaced and withdrawn

The app SHALL show notice.message as an in-app session notice. It SHALL show notification.show.text with the supplied level and maintain keyed notices by session and key. A later show with the same nonempty key SHALL replace that notice. notification.clear SHALL remove only the matching key. Unknown levels SHALL use neutral styling. Unkeyed notices SHALL remain independent.

#### Scenario: Two notices share a key

- **WHEN** the replacement and then notification.clear arrive
- **THEN** only that keyed notice is removed

### Requirement: Notice lifetime follows the declared kind

The app SHALL expire kind ttl after a positive ttl_ms, using a cancellable timer that restarts on replacement. Missing or invalid ttl_ms SHALL require local dismissal rather than invent an expiry. Sticky and agent notices SHALL remain until cleared, replaced, locally dismissed, or their session connection is discarded. These events SHALL NOT create operating-system notifications or change reply success.

#### Scenario: A replaced warning has an old timer

- **WHEN** the old timer fires
- **THEN** the replacement stays visible until its own expiry or withdrawal

### Requirement: Existing backend contract and compatibility

The app SHALL use the existing dashboard `/api/ws` JSON-RPC contract for tool.output_risk, notice, notification.show, notification.clear. The tested baseline SHALL be Hermes Agent commit `167e9fdb84248cd0fff80762dc57b6a914b6e930`, recorded in `openrpc/HERMES_REF`; a minimum semantic release containing every required field is not established. Older backends SHALL keep ordinary chat usable when these optional events or methods are absent. Unsupported actions SHALL be unavailable, and malformed optional payloads SHALL not break the event stream. No backend route, protocol extension, or token-storage change SHALL be required.

The event shapes are:

- `tool.output_risk`: `ToolOutputRiskPayload`, required `tool_id`, `name`, `risk`, `findings`, `redacted`.
- `notice`: `NoticePayload`, required `message`.
- `notification.show`: `NotificationShowPayload`, required `text`, `level`, `kind`; optional `ttl_ms`, `key`, `id`.
- `notification.clear`: `NotificationClearPayload`, required `key`.

#### Scenario: Optional capability is absent

- **WHEN** an older backend omits this capability or refuses an optional method as unsupported
- **THEN** ordinary chat remains usable and the app reports unavailable functionality without inventing state or submitting speculative requests
