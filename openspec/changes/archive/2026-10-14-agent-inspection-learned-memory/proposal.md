## Why

Users cannot inspect the profile memories that influence Hermes responses. Existing learning APIs already expose memory entries, so the app can add inspection without new backend routes.

## What Changes

- Add a profile-scoped Memory list and full-content detail in the app.
- Use existing generated REST operations for `/api/learning/graph` and `/api/learning/node`.
- Handle empty, unsupported, malformed, deleted, and stale-profile responses explicitly.
- Establish the read model reused by the separate memory edit and deletion change.

## Capabilities

### New Capabilities

- `learned-memory-inspection`: Profile-scoped learned-memory list and full-content inspection.

### Modified Capabilities

None.

## Impact

Adds one small settings destination, memory data parsing, and generated-client integration. No backend changes. Target one `feat(memory)` PR around 500 changed lines. Editing and deletion follow in `agent-inspection-memory-mutations` so each change remains reviewable.

## Non-goals

Provider configuration, memory reset, skill editing, a relationship graph visualization, Watch support, and local memory export are outside this change.

## Security and privacy

Memory can contain sensitive user content. Keep fetched entries in memory only, clear them on profile or connection changes and sign-out, and avoid automatic export. Auth tokens remain in secure storage. No memory IDs, labels, content, profile names, or response bodies enter telemetry.

## Observability

Record `memory.fetch` spans for list and detail with fixed operation and outcome, plus inherited `hermes.*` connection attributes. Record `memory.fetch_failed` events with fixed failure categories and `memory.open` breadcrumbs with fixed list/detail kind. These signals explain failed requests without recording memory content.
