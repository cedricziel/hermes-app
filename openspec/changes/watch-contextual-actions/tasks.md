## 1. Native fixtures

- [ ] 1.1 Add deterministic DemoClient or native SwiftUI fixtures before wiring for empty chat, existing typed/voice draft, successful answer, pending request, failure, and uncertain delivery. Include maximum text size and VoiceOver. SwiftUI screens cannot be hosted directly in Widgetbook; no Flutter widget is introduced.

## 2. Contextual behavior

- [x] 2.1 Write failing Swift selector tests for empty-chat starters, no draft overwrite, completed-answer follow-ups, busy/uncertain suppression, and request-action delegation. Then implement a small deterministic selector using existing conversation delivery and request state.
- [x] 2.2 Write failing model/presentation tests proving starter selection fills a draft without sending, Continue/Summarize retain ordinary send identity, and stale activation submits nothing. Then wire built-in controls into ConversationView without a favorites editor or persistence.
- [ ] 2.3 Write failing gesture and accessibility tests where portable, then preserve voice-review/manual-fast-send gesture behavior, meaningful VoiceOver action labels, readable large-text layouts, and stable focus. Verify native-only layout and gesture behavior on device.

## 3. Verification and delivery

- [x] 3.1 Confirm no extra telemetry, REST routes, or gateway methods are needed. Existing content-free relay diagnostics remain unchanged. If implementation unexpectedly requires a REST schema change, update openapi/hermes-agent.openapi.json and run scripts/generate_hermes_api_client.sh rather than editing generated code.
- [x] 3.2 Review .agents/skills/verify-in-app and any existing .claude/skills mirror for stale guidance. Link the watch-native-verification contextual-action cases; add a narrow project skill only if an uncovered repeatable workflow emerges.
- [ ] 3.3 Verify with dart format, flutter analyze, flutter test, and swift test --package-path ios/HermesWatch. Run the isolated verify-in-app relay loop and watch-native-verification checks for starters, follow-ups, active requests, optional fast-send, large text, and VoiceOver. Run openspec validate watch-contextual-actions --strict. Ship one reviewable feat(watch) PR near 500 changed lines.

## Implementation evidence

The frozen contextual source contains built-in editable starters, guarded ordinary follow-ups, and selector regression tests. A UI-used activation helper and model/presentation regressions cover editable starter insertion, ordinary send identity, and stale activation.

Checked implementation tasks describe source and authored regression coverage. They do not
mean that an open PR has merged or that a native acceptance check has passed. Combined
verification tasks remain open until their specified evidence is available. Native visual,
VoiceOver, gesture, microphone, and paired lifecycle checks have not run. The user excluded
watch simulators, and local native builds remain paused to limit host load.

The shared watch verification procedure now documents this change's portable
regressions and native acceptance cases. The existing `.claude` procedure links
to it, and the `.agents` forwarding entry remains intact. This documentation
update does not establish that any native acceptance case passed.
