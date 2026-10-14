## 1. Scoped mutation behavior

- [x] 1.1 Verify PUT/DELETE success, rejection, stale-ID, blank-edit, and explicit-profile fixtures against bundled Hermes revision `167e9fdb84248cd0fff80762dc57b6a914b6e930`. Confirm generated LearningNodeEdit and LearningNodeRef bodies plus matching profile query. No new or changed API routes are planned.
- [x] 1.2 Write failing FakeHermesServer HTTP tests with the real generated client for exact bodies, profile identity, `ok: true`, malformed responses, and server rejection, then implement validated mutation calls after the inspection change.
- [x] 1.3 Write failing tests for preflight conflicts, duplicate submissions, lost responses, no automatic retry, and scope-change guards, then implement pending and uncertain states with read-only reconciliation.

## 2. Editor and deletion

- [x] 2.1 Write failing widget tests and add Widgetbook cases for dirty editor, blank content, conflict, server rejection, pending save, uncertain save, and permanent-delete confirmation, then build editor and confirmation components.
- [x] 2.2 Write failing integration tests for full-content editing, cancellation without DELETE, refreshed IDs after success, and deliberate draft discard, then wire actions only for memory detail and reuse App Lock boundaries.
- [x] 2.3 Write failing telemetry tests for secret-content exclusion and telemetry failure, then add mutation spans, fixed outcome events, and edit/delete breadcrumbs described in design.md.

## 3. Verification

- [x] 3.1 Review verification skills and update only stale `.agents/skills` or legacy `.claude/skills` guidance. Add reusable throwaway memory mutation scenarios if needed. Keep this `feat(memory)` PR near 500 lines, split before implementation if larger, and require inspection to land first.
- [ ] 3.2 Run dart format, flutter analyze, flutter test, and isolated verify-in-app using throwaway memories for save, permanent deletion, conflict, uncertain outcome, and profile switching.
