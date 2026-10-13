## Context

This change depends on `agent-inspection-learned-memory`. The bundled OpenAPI has existing PUT and DELETE routes with typed request bodies, optional profile query, and unspecified success bodies. The learning routes in `hermes_cli/web_routers/status.py` and `agent/learning_mutations.py` were checked at bundled Hermes revision `167e9fdb84248cd0fff80762dc57b6a914b6e930`. They use `body.profile or profile`, return `{ok, message}`, map non-ok mutations to HTTP 400, and reject stale memory IDs. Fixtures in `test/memory/memory_fixtures.dart` record that compatibility baseline.

## Goals / Non-Goals

Goals: deliberate save and permanent deletion of memory entries, scoped identity, and honest uncertain outcomes.

Non-goals: skill mutations, undo, persistent drafts, backend revisions, and atomic compare-and-swap guarantees.

## Decisions

Use `authController.api!.raw` existing generated update/delete methods with typed LearningNodeEdit and LearningNodeRef. Set body and query profiles to the same captured value. Validate `{ok: true}` before showing success. No new routes, generated-file edits, or OpenAPI regeneration are necessary.

Add an editor and delete confirmation to the inspection detail. Capture original content and exact opaque ID. Run a generated-client detail read before mutation and compare original full content. A mismatch blocks submission and offers refresh while preserving the draft. This reduces accidental overwrite but does not make read-then-write atomic. Respect backend rejection rather than inventing revision headers.

Refresh graph and detail after success; edited memory IDs can change with content. Close stale detail and return to the refreshed list rather than manufacturing a replacement ID. Treat memory deletion as permanent. Skill deletion has different archive behavior and remains outside this UI.

Disable duplicate submissions. During an uncertain result retain the draft and expose reconciliation reads. Never automatically repeat mutations. Absence of the old ID is not proof of a successful save; refresh may show a changed entry but the user must select it again before another mutation. During a pending request, a scope switch confirms that the original request may still complete and discards scoped UI state. Sign-out clears drafts immediately and late responses remain generation-guarded.

Affected platforms: iOS, Android, macOS, Windows, and Linux. watchOS unchanged. No entitlement, manifest, or Xcode project change. Reuse App Lock, secure token storage, and concurrent-401 handling. Keep drafts and responses out of preferences and logs.

Record `memory.mutate` at the generated-client write boundary with fixed save/delete operation, outcome, and inherited `hermes.*` connection attributes. Record `memory.mutation_outcome` through AppEventLogger with fixed confirmed/failed/uncertain category. Record `memory.edit.open` and `memory.delete.confirm` through Breadcrumbs with fixed names only. Do not record server message strings or memory content. Telemetry remains opt-in and failure-tolerant.

## Risks / Trade-offs

- No atomic client conflict guard. Preflight comparisons and exact server IDs reduce risk; backend rejection remains authoritative.
- A response can be lost after the server commits. Reconcile and keep uncertainty; never auto-repeat writes.
- Backend memory limits can reject content. Preserve the draft and show the user-facing error without logging its string.
- Source inspection revision differs from the bundled contract. Verify pinned mutation fixtures and stale-ID rejection before release. If exact pinned support is absent, leave mutation controls unavailable without a backend change.

## Migration Plan

Ship after inspection as an additive editor. Rollback removes mutation controls; completed changes remain on the server and deletion cannot be reversed by app rollback.
