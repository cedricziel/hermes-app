## 1. Phone invalidation

- [x] 1.1 Start with failing tests in `watch_request_handler_test.dart` and `watch_auth_gate_test.dart` for remembered replies after sign-out and late completion after departure; add session guards and clear/invalidate send attempts.
- [x] 1.2 Start with failing bridge tests for confirmed departure versus restoration and transient refresh failures; test delayed logout after successful sign-in and phone restart, then publish retained, revision-ordered invalidation and usable-session re-establishment through `WatchBridge` and `WatchRelay` without replacing complication context.

## 2. Watch cleanup

- [x] 2.1 Start with failing Swift core tests for cached conversations, lists, drafts, retry audio, and delayed replies; add shared invalidation ownership and work-generation guards before cache writes and UI mutations.
- [x] 2.2 Start with failing cleanup tests for temporary audio and deletion failure with restart; connect recorder cancellation, cache removal, persisted cleanup tombstones, startup retry, and private status cleanup. Native SwiftUI has no Widgetbook support; use SwiftUI previews for signed-out state before wiring screens.
- [x] 2.3 Start with failing diagnostics tests for fixed reason/result/count fields and swallowed logger failures; add the outcome event and local Apple logs described in the proposal.

## 3. Verification and scope

- [x] 3.1 Update existing verify-in-app guidance in `.agents/skills` and any equivalent `.claude/skills` entry made stale with paired-watch logout checks, isolated credentials, and cleanup. Coordinate shared guidance with the watch validation change.
- [x] 3.2 Keep the implementation in one reviewable `fix(watch)` PR, targeting roughly 500 changed lines. If native delivery plumbing exceeds that budget, separate it from model cleanup without omitting either requirement.
- [ ] 3.3 Run `dart format`, `flutter analyze`, `flutter test`, and `swift test --package-path ios/HermesWatch`. Run verify-in-app with a throwaway backend and native paired-watch checks for foreground cached content, unreachable-phone logout followed by reconnection, recording interruption by invalidation, and late replies. Document hardware checks not run. Validate the OpenSpec change strictly. No API route or generation task is required.

## Implementation evidence

Phone privacy PR #696 and native cleanup PR #698 merged after independent review and cloud CI. The exact phone privacy checkout passed 121 focused headless tests. Native cleanup source includes startup retry and deletion-failure regression tests.

Checked implementation tasks describe source and authored regression coverage. They do not
mean that an open PR has merged or that a native acceptance check has passed. Combined
verification tasks remain open until their specified evidence is available. Native visual,
VoiceOver, gesture, microphone, and paired lifecycle checks have not run. The user excluded
watch simulators, and local native builds remain paused to limit host load.
