## 1. Contract and state behavior

- [x] 1.1 Write failing mapper and transport tests using pinned-contract payload fixtures for background.complete, btw.complete; implement safe optional decoding and owning-session routing without backend or generated-client changes.
- [x] 1.2 Write a failing regression test for "Side results remain separate from the main answer"; implement the behavior specified in agent-side-results, including its unavailable fallback.
- [x] 1.3 Write a failing regression test for "Replay does not duplicate side results"; implement the behavior specified in agent-side-results, including its unavailable fallback.
- [x] 1.4 Write a failing regression test for "Results arriving between turns remain visible"; implement the behavior specified in agent-side-results, including its unavailable fallback.

## 2. Presentation and integration

- [x] 2.1 Write a failing widget test for compact, expanded, empty, unavailable, and accessibility states; add Widgetbook use cases before wiring the card into chat.
- [x] 2.2 Write failing integration tests for event delivery during an active turn, between turns, after reconnect, and after profile or connection replacement; wire the capability into the existing presentation and lifecycle without changing main-turn settlement.
- [x] 2.3 Write a failing contract-inventory test for the newly supported events; update gateway_contract_test.dart classifications and payload samples for exactly the events this PR handles. Keep safe unknown-event behavior.

## 3. Observability and verification

- [x] 3.1 Write failing privacy and failure-isolation tests; add gateway.visibility_outcome logs at the event reducer or invalidation consumer and chat.visibility_action breadcrumbs at applicable user actions, using feature, outcome, action, and count only. Reuse existing connection spans and hermes.* attributes. Verify telemetry cannot break handling.
- [x] 3.2 Update existing project-local verify-in-app skill instructions if this capability makes them stale; review legacy .claude/skills guidance only if present. Add a narrow reusable verification helper only if an actual repeated workflow needs one.
- [x] 3.3 Format changed/new Dart files, run scoped analyzer and regression tests, and strictly validate the delta and synced main spec. Evidence: mapper/contract RED showed ignored events; transport/controller RED showed empty results; reentrant retirement RED incorrectly applied a result. After fixes, 45 focused tests pass and the analyzer reports no issues across 16 paths. HTTP fixtures use the real generated client with FakeHermesServer.
- [ ] 3.4 Run isolated native verify-in-app scenarios for active/idle side results, replay, replacement, and protected ownership retirement. Native verification was not performed in this implementation checkout; publishing and PR review remain owned by integration.
