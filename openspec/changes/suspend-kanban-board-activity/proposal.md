## Why

The retained Kanban board can continue reading, streaming, or writing after authenticated activity pauses. The board needs a suspension boundary so reauthentication can retain local context without accepting work from the previous activity period.

## What Changes

- Add an optional activity signal to the board controller; callers without a signal keep existing behavior.
- Stop board event delivery, debounce and reconnect timers immediately on suspension, and prevent new protected reads or board actions.
- Ignore results from work started before suspension, including after activity resumes, and perform fresh reads on resume while retaining board selection, filters and selected task ids.
- Keep ordinary screen visibility separate from authenticated activity.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `kanban`: Bound retained board work to the current activity period.

## Impact

Changes are limited to `KanbanBoardController`, focused controller regressions and these planning artifacts. Existing generated Kanban REST calls and event stream contracts remain unchanged.

Non-goals: session-owner identity decisions, owner/UI wiring, task-detail and create-form suspension, drafts, sign-out/server-departure cleanup, native changes, and rollback of commands already sent. The owner must dispose retained state on explicit sign-out or server departure.

Security and privacy: suspended board work cannot issue new protected requests or accept stale results. No token, secure-storage or preference format changes are needed.

Observability: none added. Existing `live`, `loading`, retained model state, HTTP telemetry and reconnect logs cover this controller boundary; session suspension reasons belong to its owner. No user content is added to telemetry.
