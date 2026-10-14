## 1. Context contract

- [x] 1.1 Start with failing phone tests for same-owner restart, token refresh, confirmed departure, ungated server, and missing gated owner; implement protected context persistence and rotation using `VerifiedSessionOwner` and the session revision from `watch-session-privacy`.
- [x] 1.2 Start with failing codec and handler tests for version 2 IDs, delimiter characters, historical profiles, legacy IDs, and colliding session IDs across owners; replace binding and reject mismatches before any repository or transport access.
- [x] 1.3 Start with failing relay tests for `session` handshake, scoped new-chat send, transcription, remembered sends, and post-await owner changes; add context fields and guards on every content operation and response.

## 2. Watch isolation

- [x] 2.1 Start with failing Swift tests for handshake, context-scoped caches, stale replies, revision ordering, cold offline launch, and legacy cache removal; wire context acceptance to shared cleanup before displaying current data.
- [x] 2.2 Start with failing status/navigation tests for old complication targets and handoff activation; bind acceptance to the current context without changing the existing handoff payload protocol. Add SwiftUI previews for update-required and changed-session states before screen wiring; Widgetbook does not host native watch UI.
- [x] 2.3 Start with failing phone and Swift tests for new-watch/old-phone and old-watch/new-phone combinations; provide update/open-phone guidance and block ambiguous content requests.
- [x] 2.4 Start with failing telemetry tests for fixed enums and swallowed failures; add rejection events and local logs with no identifiers or content, and recognize `session` in the operation sanitizer in both `WatchBridge` and `WCSessionTransport`.

## 3. Verification and delivery

- [x] 3.1 Update stale verify-in-app guidance under `.agents/skills` and any equivalent `.claude/skills` entry with owner-switch fixtures; coordinate shared native validation documentation with the watch validation change.
- [ ] 3.2 Target one `fix(watch)` PR of roughly 500 changed lines after privacy cleanup lands. If context persistence plus transport changes exceed that budget, stage phone protocol support before watch migration while keeping legacy writes blocked until ownership can be verified.
- [ ] 3.3 Run `dart format`, `flutter analyze`, `flutter test`, and `swift test --package-path ios/HermesWatch`; run verify-in-app with isolated backend identities and native paired-watch checks for account/server switches, refresh, phone restart, delayed updates, offline launch, handoff, and version skew. Document unavailable hardware validation. Run strict OpenSpec validation. No route or generated-client changes are required.

## Implementation evidence

The protected context and codec foundations merged in PR #689. Runtime source and regression tests are in PR #706. The identity checkpoint passed 182 headless tests, but omitted phone intents. The later focused intent and scope checks passed 105 intent tests and two scope tests. PR #706 merged after independent review, full CI, and platform builds.

Checked implementation tasks describe source and authored regression coverage. They do not
mean that an open PR has merged or that a native acceptance check has passed. Combined
verification tasks remain open until their specified evidence is available. Native visual,
VoiceOver, gesture, microphone, and paired lifecycle checks have not run. The user excluded
watch simulators, and local native builds remain paused to limit host load.

The shared watch verification procedure now documents this change's portable
regressions and native acceptance cases. The existing `.claude` procedure links
to it, and the `.agents` forwarding entry remains intact. This documentation
update does not establish that any native acceptance case passed.
