## 1. Contract and state behavior

- [x] 1.1 Write failing mapper and transport tests using pinned-contract payload fixtures for message.reaction and reaction; optional canonical transcript row_id; implement safe optional decoding and owning-session routing without backend or generated-client changes.
- [x] 1.2 Write a failing regression test for "Durable reactions attach only by message identity"; implement the behavior specified in agent-reactions, including its unavailable fallback.
- [x] 1.3 Write a failing regression test for "Identity-free reactions stay separate"; implement the behavior specified in agent-reactions, including its unavailable fallback.
- [x] 1.4 Write a failing regression test for "Replay preserves reported reactions"; implement the behavior specified in agent-reactions, including its unavailable fallback.

## 2. Presentation and integration

- [x] 2.1 Write a failing widget test for compact, expanded, empty, unavailable, and accessibility states; add Widgetbook use cases before wiring the card into chat.
- [x] 2.2 Write failing integration tests for event delivery during an active turn, between turns, after reconnect, and after profile or connection replacement; wire the capability into the existing presentation and lifecycle without changing main-turn settlement.
- [x] 2.3 Write a failing contract-inventory test for the newly supported events; update gateway_contract_test.dart classifications and payload samples for exactly the events this PR handles. Keep safe unknown-event behavior.

## 3. Observability and verification

- [x] 3.1 Write failing privacy and failure-isolation tests; add gateway.visibility_outcome logs at the event reducer or invalidation consumer and chat.visibility_action breadcrumbs at applicable user actions, using feature, outcome, action, and count only. Reuse existing connection spans and hermes.* attributes. Verify telemetry cannot break handling.
- [x] 3.2 Update existing project-local verify-in-app skill instructions if this capability makes them stale; review legacy .claude/skills guidance only if present. Add a narrow reusable verification helper only if an actual repeated workflow needs one.
- [ ] 3.3 Verify dart format, flutter analyze, relevant flutter test suites, and an isolated verify-in-app run covering the spec scenarios. For REST reads, use FakeHermesServer with the real generated client. Validate this OpenSpec change strictly and review the diff as one feat(chat) PR targeting roughly 500 implementation lines or fewer.

## Verification evidence

- Parser/mapper/receipt/controller baseline: 13 passed and 15 intended RED failures before wiring; no compilation failure.
- Reentry proof: omitting the pure actual-binding getter guard reproduced the old-owner badge during earlier Todo ownership notification; guarded source restored.
- Final reaction/parser/gateway/controller/widget/contract plus inherited transport-signals and prompt-receipt suite: 88 passed. Passive queued/auto-continued routing and future-role decoders were verified RED (four failures) before their scoped fixes. The actual chat widget exposed a Material boundary issue before its fix.
- Full analyzer: clean. Format check: 24 Dart files, zero changes. Main and delta specification strict validation: passed after separating current contract pin71d34bad from retained fixture baseline167e9fdb.
- Native reaction scenarios remain unobserved; task3.3 stays unchecked. The pinned REST messages path has database id without canonical row_id, so it cannot establish reaction identity or cold restoration.

## Queue integration evidence

- Integrated on queue-recovery `1cfb8d8a05e99f9d3acae72ded349e20f10cb3e0`, preserving the already merged canonical core, MoA and durable submission guards.
- Six new queue cases use the actual protected store and gateway or a controlled owning queue transport. Receipt-hook omission failed two assertions on missing canonical identity; insertion-history omission failed two assertions on pending badges. Four stale receipt controls passed in both RED runs.
- Restored integration: 126 reaction, receipt, watch, durable queue, composer and widget tests passed. A separate 64-test ownership batch covered MoA, Side, Todo, usage, activity and the six queue cases. Counts overlap between batches.
- Deferred users remain absent until typed PromptAccepted; exact stamped PromptAcknowledged establishes only their canonical row identity. Pending reactions are matched after actual insertion. Reentry rechecks prevent a retired attachment from updating Flyer afterward.
- Native reaction scenarios remain unchecked. Prior native Side/Process/MoA observations do not establish reaction delivery.
