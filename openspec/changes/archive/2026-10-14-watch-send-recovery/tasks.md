## 1. Preserve pending identity

- [x] 1.1 Add failing Swift outbox tests for persistence-before-delivery, write failure, restart, context/revision departure, late results, invalidation tombstones, and capacity slot release. Implement protected backup-excluded context-scoped pending storage and explicit recovery states.
- [x] 1.2 Add failing RelayClient/core tests for capability absent, unsupported protocol, unknown/uncertain/pending status, and saved completion arriving twice. Parse sendState/recoveryState and enforce status-only restoration using the original ID; validate context/revision before mutation.

## 2. Expose deliberate recovery

- [x] 2.1 Add native DemoClient and SwiftUI preview cases for pending, uncertain with or without a thread, not_sent, unsupported phone, capacity failure, and resend confirmation. These are the native equivalent of catalog use cases; Flutter Widgetbook cannot render the watch UI.
- [x] 2.2 Add failing interaction/model tests for Check result, Open chat, required status check before resend, cancelled resend, confirmed resend with a new identity, and local Forget recovery. Wire base controls into the existing error area before later conversation-usability work. Never edit the uncertain original in place or silently resend it.
- [x] 2.3 Add a failing logging test for fixed recovery action/outcome values without private fields. Add the local Apple logs named in the proposal; reuse existing request diagnostics for timing.
- [x] 2.4 Update the project verify skill with restart, sleep/wake, confirmed/cancelled resend, version skew, timestamp expiry/skew guidance, context departure, and protected-file deletion-failure cases. Preserve the `.agents` forwarding skill.

## 3. Verify and ship

- [ ] 3.1 Run `swift test --package-path ios/HermesWatch`, native UI tests, `dart format .`, `flutter analyze`, and `flutter test`. Run the isolated native verify-in-app fixture against restart and lost-reply cases. Check smallest supported screen, Dynamic Type, and accessibility labels for recovery and confirmation controls; report unavailable hardware coverage. Ship `feat(watch): check pending results before explicit resend` as one bounded PR targeting fewer than 500 changed lines.

## Implementation evidence

Protected pending storage merged in PR #694. PR #707 contains runtime restoration, status checking, explicit resend confirmation, recovery diagnostics, fixtures, and updated recovery verification guidance.

Checked implementation tasks describe source and authored regression coverage. They do not
mean that an open PR has merged or that a native acceptance check has passed. Combined
verification tasks remain open until their specified evidence is available. Native visual,
VoiceOver, gesture, microphone, and paired lifecycle checks have not run. The user excluded
watch simulators, and local native builds remain paused to limit host load.
