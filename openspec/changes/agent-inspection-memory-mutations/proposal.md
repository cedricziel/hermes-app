## Why

Inspection alone cannot correct a false memory or remove unwanted retained information. Existing node update and delete endpoints let the app support deliberate memory changes without backend work.

## What Changes

- Add Edit and Delete actions to memory detail after `agent-inspection-learned-memory`.
- Save complete text through existing `PUT /api/learning/node` and delete through existing `DELETE /api/learning/node`.
- Require explicit save and destructive confirmation, preserve scoped identity, and reconcile uncertain outcomes before retry.
- Refetch list and detail after confirmed changes because memory identity can change with its content.

## Capabilities

### New Capabilities

- `learned-memory-mutations`: Deliberate profile-scoped memory editing and permanent deletion.

### Modified Capabilities

None.

## Impact

Depends on `agent-inspection-learned-memory`. Reuses its scoped memory state, detail UI, and validated generated-client response handling. Existing request schemas are `LearningNodeEdit` and `LearningNodeRef`; no backend changes. Target one `feat(memory)` PR near 500 lines.

## Non-goals

Skill mutation, bulk deletion, memory reset, creation, provider setup, automatic rewrite, persistent editor drafts, and server-side atomic compare-and-swap are outside this change.

## Security and privacy

Memory changes affect future agent behavior. Delete permanently removes a memory entry and has no restore promise. Keep unsaved content in memory only; discard it after a confirmed scope change or sign-out. Tokens remain in secure storage. Telemetry excludes IDs, content, labels, server error messages, and profile names.

## Observability

Record `memory.mutate` spans for fixed save/delete operation and outcome, with inherited `hermes.*` server attributes. Record `memory.mutation_outcome` events for success, failure, or uncertain result. Record fixed edit-open and delete-confirm breadcrumbs. These expose failed changes without recording memory values.
