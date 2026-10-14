## 1. Isolate local attempts

- [x] 1.1 Add failing Swift tests for a stopped wait receiving each reply kind after a newer attempt starts. Assert messages, thread identity, Handoff target, phase, retry buffers, and poll count.
- [x] 1.2 Guard every post-await send result before any conversation mutation; keep Stop waiting local and preserve its user message.

## 2. Verify and ship

- [x] 2.1 Confirm existing request diagnostics remain unchanged. No new spans, events, or breadcrumbs are required.
- [x] 2.2 Update the watch verification checklist in `.claude/skills/verify-in-app/SKILL.md` with late-reply behavior, using the isolated fixture planned by `watch-native-verification`; preserve the `.agents` forwarding skill.
- [ ] 2.3 Run `swift test --package-path ios/HermesWatch`, `dart format .`, `flutter analyze`, and `flutter test`. Verify Stop waiting followed by a new send against an isolated watch and phone fixture. Record unavailable device coverage explicitly. Ship one bounded PR as `fix(watch): ignore replies from stopped send attempts`, targeting fewer than 500 changed lines.

## Implementation evidence

PR #686 merged with post-await attempt guards and regression tests. The checked-in watch verification procedure includes late results after leaving a wait.

Checked implementation tasks describe source and authored regression coverage. They do not
mean that an open PR has merged or that a native acceptance check has passed. Combined
verification tasks remain open until their specified evidence is available. Native visual,
VoiceOver, gesture, microphone, and paired lifecycle checks have not run. The user excluded
watch simulators, and local native builds remain paused to limit host load.
