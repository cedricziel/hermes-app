## 1. Contract and state behavior

- [ ] 1.1 Write failing mapper and transport tests using pinned-contract payload fixtures for sessions.changed, cron.changed, platforms.changed, pairing.changed; existing session and REST list methods; implement safe optional decoding and owning-session routing without backend or generated-client changes.
- [ ] 1.2 Write a failing regression test for "Change signals invalidate the appropriate data"; implement the behavior specified in agent-change-invalidation, including its unavailable fallback.
- [ ] 1.3 Write a failing regression test for "Refresh work is coalesced and respects visibility"; implement the behavior specified in agent-change-invalidation, including its unavailable fallback.
- [ ] 1.4 Write a failing regression test for "Refresh does not overwrite user edits"; implement the behavior specified in agent-change-invalidation, including its unavailable fallback.

## 2. Presentation and integration

- [ ] 2.1 Write a failing test for stale data, refresh failure, and unsaved-form preservation; add Widgetbook cases for the existing list failure and loading states before wiring invalidation into screens.
- [ ] 2.2 Write failing integration tests for event delivery during an active turn, between turns, after reconnect, and after profile or connection replacement; wire the capability into the existing presentation and lifecycle without changing main-turn settlement.
- [ ] 2.3 Write a failing contract-inventory test for the newly supported events; update gateway_contract_test.dart classifications and payload samples for exactly the events this PR handles. Keep safe unknown-event behavior.

## 3. Observability and verification

- [ ] 3.1 Write failing privacy and failure-isolation tests; add gateway.visibility_outcome logs at the event reducer or invalidation consumer using feature, outcome, and count only; add no new automatic-invalidation breadcrumb. Reuse existing connection spans and hermes.* attributes. Verify telemetry cannot break handling.
- [ ] 3.2 Update existing project-local verify-in-app skill instructions if this capability makes them stale; review legacy .claude/skills guidance only if present. Add a narrow reusable verification helper only if an actual repeated workflow needs one.
- [ ] 3.3 Verify dart format, flutter analyze, relevant flutter test suites, and an isolated verify-in-app run covering the spec scenarios. For REST reads, use FakeHermesServer with the real generated client. Validate this OpenSpec change strictly and review the diff as one feat(chat) PR targeting roughly 500 implementation lines or fewer.
