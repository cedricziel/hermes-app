## 1. Contract and state behavior

- [x] 1.1 Write failing mapper and transport tests using pinned-contract payload fixtures for todo.updated; session.resume.todo_state; implement safe optional decoding and owning-session routing without backend or generated-client changes.
- [x] 1.2 Write a failing regression test for "Todo snapshots replace the current plan"; implement the behavior specified in agent-todo-state, including its unavailable fallback.
- [x] 1.3 Write a failing regression test for "Todo rendering requires verified item fields"; implement the behavior specified in agent-todo-state, including its unavailable fallback.
- [x] 1.4 Write a failing regression test for "Resume restores available plan state"; implement the behavior specified in agent-todo-state, including its unavailable fallback.

## 2. Presentation and integration

- [x] 2.1 Write a failing widget test for compact, expanded, empty, unavailable, and accessibility states; add Widgetbook use cases before wiring the card into chat.
- [x] 2.2 Write failing integration tests for event delivery during an active turn, between turns, after reconnect, and after profile or connection replacement; wire the capability into the existing presentation and lifecycle without changing main-turn settlement.
- [x] 2.3 Write a failing contract-inventory test for the newly supported events; update gateway_contract_test.dart classifications and payload samples for exactly the events this PR handles. Keep safe unknown-event behavior.

## 3. Observability and verification

- [x] 3.1 Write failing privacy and failure-isolation tests; add gateway.visibility_outcome logs at the event reducer or invalidation consumer and chat.visibility_action breadcrumbs at applicable user actions, using feature, outcome, action, and count only. Reuse existing connection spans and hermes.* attributes. Verify telemetry cannot break handling.
- [x] 3.2 Update existing project-local verify-in-app skill instructions if this capability makes them stale; review legacy .claude/skills guidance only if present. Add a narrow reusable verification helper only if an actual repeated workflow needs one.
- [ ] 3.3 Verify dart format, flutter analyze, relevant flutter test suites, and an isolated verify-in-app run covering the spec scenarios. For REST reads, use FakeHermesServer with the real generated client. Validate this OpenSpec change strictly and review the diff as one feat(chat) PR targeting roughly 500 implementation lines or fewer.

