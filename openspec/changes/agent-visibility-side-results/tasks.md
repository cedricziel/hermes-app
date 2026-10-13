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
- [x] 3.3 Format changed/new Dart files, run scoped analyzer and regression tests, and strictly validate the delta and synced main spec. Evidence: mapper/contract RED showed ignored events; transport/controller RED showed empty results; reentrant retirement RED incorrectly applied a result. The initial integration batch passed 45 focused tests with a clean 16-path analyzer. Follow-up replacement-notification regressions exposed old Side details and old usage during binding transitions; the final bounded correction batch passes 39 Side/usage/activity tests with a clean three-path analyzer. Null actual ownership preserves known disconnected-stale usage; divergent confirmed ownership hides it. After integration with merged todo plans, an observer regression exposed old side details and a real short-window widget regression overflowed by 50 pixels. Confirmed-binding getters and a shared bounded activity header fix both; the final combined batch passes 122 tests with clean full analysis. HTTP fixtures use the real generated client with FakeHermesServer.
- [ ] 3.4 Run isolated native verify-in-app scenarios for active/idle side results, replay, replacement, and protected ownership retirement. Native verification was not performed in this implementation checkout; publishing and PR review remain owned by integration.
