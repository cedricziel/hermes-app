## 1. Memory reads

- [x] 1.1 Verify graph and node-detail success/error fixtures against bundled Hermes revision `167e9fdb84248cd0fff80762dc57b6a914b6e930`, covering nodes, full content, explicit profile, missing route, stale ID, and unknown profile. Record the fixture source revision; no new API routes or generated response schemas are required.
- [x] 1.2 Write failing HTTP tests with FakeHermesServer and the real generated client for profile parameters and response validation, then add app-owned graph/detail parsing and scoped read state.
- [x] 1.3 Write failing tests for late responses, profile changes, sign-out clearing, malformed nodes, and skill filtering, then implement generation guards and privacy behavior.

## 2. Memory destination

- [x] 2.1 Write failing widget tests and add Widgetbook cases for loading, empty, memory-source labels, full content, unavailable, and stale detail, then build the list and detail components.
- [x] 2.2 Write a failing settings navigation test, then wire the Memory destination and reuse existing App Lock behavior.
- [x] 2.3 Write failing telemetry tests proving no content, IDs, labels, or profile names are recorded and failures remain non-fatal, then add the read spans, failure events, and navigation breadcrumbs in design.md.

## 3. Verification

- [x] 3.1 Review project verification skills and update only stale `.agents/skills` or legacy `.claude/skills` guidance. Add reusable Memory verification fixtures if needed. Keep this `feat(memory)` PR near 500 lines and split before implementation if measured scope is larger.
- [ ] 3.2 Run dart format, flutter analyze, flutter test, and isolated verify-in-app checks for full-content detail, profile isolation, empty memory, and unsupported routes.
