## Why

The app drops live usage events and gives users no session token or context counters. A compact session usage view makes long conversations and context compression understandable.

## What Changes

- Show server-reported session token counts, model, context usage, and optional cost.
- Consume live `session.usage` snapshots and final `message.complete.usage`, with an explicit refresh through the existing usage RPC.
- Show unavailable or stale states without inventing zero usage or per-turn totals.

## Capabilities

### New Capabilities

- `session-usage`: Scoped session usage inspection and live updates.

### Modified Capabilities

None.

## Impact

Affects chat gateway mapping, chat state, and a compact usage disclosure. Uses existing authenticated `/api/ws` contracts; no backend change. Target one `feat(chat)` PR of roughly 500 lines or fewer.

## Non-goals

Per-turn arithmetic, billing account management, provider quota dashboards, forecasts, and new Watch UI are outside this change.

## Security and privacy

Usage stays in the selected connection and profile. Authentication tokens remain in secure storage. Telemetry excludes profile names, session IDs, model names, message text, and usage payloads.

## Observability

Record an RPC fetch span with inherited `hermes.*` server attributes and fixed outcome. Record a fixed usage-fetch failure event for unsupported, malformed, or transport outcomes. Add a fixed disclosure-open breadcrumb. Existing event transport telemetry covers live updates; do not log every tick.
