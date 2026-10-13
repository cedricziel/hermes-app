## Purpose

Make server-reported session token and context usage visible without inventing per-turn totals or missing provider data.

## Requirements

### Requirement: Scoped session usage contract

The app SHALL request authenticated `/api/ws` RPC `session.usage` with a confirmed runtime `session_id` and the resolved `profile`. A nullable profile SHALL be accepted only when the current owned runtime was confirmed on that exact connection and the runtime-scoped resolver has no ambient-profile fallback. It SHALL consume the `SessionUsageResult` shape and live `session.usage` payload `{usage: Usage}`. The supported contract baseline SHALL be repository-pinned Hermes commit `167e9fdb84248cd0fff80762dc57b6a914b6e930`; earliest released version support is unverified. A method-not-found response SHALL disable usage inspection without disabling chat.

#### Scenario: Open usage inspection

- **WHEN** a user opens Session usage in a selected conversation
- **THEN** the app requests that session and profile and shows the returned model, input, output, reasoning, total, and calls when valid
- **AND** missing data is unavailable rather than synthesized as zero

### Requirement: Snapshot semantics

The app SHALL label counters as session usage. It SHALL replace snapshots rather than sum usage ticks. A valid `message.complete.usage` SHALL supply the final snapshot for the current turn's completion without converting session totals into per-turn totals.

#### Scenario: Repeated live ticks and final usage

- **WHEN** repeated ticks precede a final completion snapshot
- **THEN** values update once per snapshot and the completion snapshot replaces the live values
- **AND** no repeated payload increases counts by addition

#### Scenario: Completion without usage

- **WHEN** a completion payload omits usage or sets it to null
- **THEN** the app retains the last snapshot with its freshness state and does not present it as a new authoritative snapshot

### Requirement: Optional context and cost

The app SHALL display valid `context_used`, `context_max`, `context_percent`, `compressions`, and `cost_usd` only when supplied. It SHALL preserve `context_estimated` and SHALL not treat reasoning as an extra additive component of total tokens or calculate cost from model prices.

#### Scenario: Partial provider data

- **WHEN** the server reports token counts but no cost or context capacity
- **THEN** the app shows available counts and hides unavailable metrics
- **AND** estimated context has an explicit estimated label

### Requirement: Freshness and isolation

The app SHALL obtain usage only from an already confirmed owned runtime. Opening inspection SHALL NOT create or resume a session or guess a runtime from a stored conversation ID. The bounded optional read SHALL NOT drop the chat connection on timeout or method-not-found. The app SHALL reject stale fetch results after session, profile, or connection changes. It SHALL clear usage on sign-out or connection change, mark disconnected values stale, and refresh the selected session after reconnect.

#### Scenario: Switch during fetch

- **WHEN** a usage response arrives after the user switches profiles or sessions
- **THEN** the response does not appear in the new conversation

#### Scenario: Disconnected or malformed usage

- **WHEN** usage is unavailable, malformed, or the connection closes
- **THEN** chat remains usable according to its connection state and usage shows unavailable or stale without replacing known values with fabricated zeros
