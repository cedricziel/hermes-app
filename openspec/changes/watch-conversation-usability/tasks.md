## 1. Native fixtures

- [ ] 1.1 Add deterministic native DemoClient or SwiftUI preview fixtures for the spec scenarios, old payloads, long content, maximum text size, and VoiceOver before screen wiring. SwiftUI screens cannot be hosted directly in Widgetbook; add Flutter Widgetbook cases first only if this change adds a Flutter widget.

## 2. Behavior

- [x] 2.1 Write failing Swift tests for outgoing acceptance states, Retry identity, Edit gating, Check result, duplicate-risk confirmation, fresh Send again identity, Discard, and scroll-follow decisions. Then render the delivery row and stable answer anchors.
- [ ] 2.2 Start with failing accessibility/presentation tests where portable, then implement meaningful control labels, message speaker announcements in chronological order, non-color status, stable focus, and scrollable large-text content; verify native-only behavior on device.
- [x] 2.3 Start with a failing diagnostic test, then preserve content-free operation/result diagnostics and add new operation allowlist values when applicable. Confirm telemetry exceptions cannot affect replies. No extra UI logs, spans, or breadcrumbs are proposed.

## 3. Compatibility and delivery

- [x] 3.1 Start with failing old-peer and auth-reset regression tests, then implement optional-field fallback and sensitive-state reset. Use the real generated REST client with FakeHermesServer for affected HTTP behavior; use the existing gateway test server for RPC behavior. No new REST route is planned, so no OpenAPI regeneration is required. If implementation changes a REST route or schema, update openapi/hermes-agent.openapi.json and run scripts/generate_hermes_api_client.sh rather than hand-editing generated code.
- [x] 3.2 Review project verify-in-app guidance in .agents/skills and any existing .claude/skills mirror; update only guidance made stale and link the shared native watch lifecycle verification. Add a narrow project skill only if the implemented workflow needs repeatable instructions not already covered.
- [ ] 3.3 Verify with dart format, flutter analyze, flutter test, and swift test --package-path ios/HermesWatch. Run the isolated verify-in-app loop for affected relay/UI behavior and the native watch lifecycle checklist for supported sizes, large text, VoiceOver, offline recovery, and late results. Run openspec validate watch-conversation-usability --strict. Keep one reviewable PR near 500 lines using feat(watch) or fix(watch), splitting an implementation that exceeds that bound before broadening scope.

## Implementation evidence

The frozen conversation source is in PR #709. It includes outgoing delivery evidence, guarded Edit, explicit recovery, answer anchors, and regression tests for reading position and focus decisions.

Checked implementation tasks describe source and authored regression coverage. They do not
mean that an open PR has merged or that a native acceptance check has passed. Combined
verification tasks remain open until their specified evidence is available. Native visual,
VoiceOver, gesture, microphone, and paired lifecycle checks have not run. The user excluded
watch simulators, and local native builds remain paused to limit host load.

The shared watch verification procedure now documents this change's portable
regressions and native acceptance cases. The existing `.claude` procedure links
to it, and the `.agents` forwarding entry remains intact. This documentation
update does not establish that any native acceptance case passed.
