## 1. Persist dispatch evidence

- [x] 1.1 Add failing protected-storage tests for atomic writes, corruption, unavailable files, invalidation tombstones, retention, compact tombstones, timestamp expiry/skew, explicit forget, and capacity slot release. Implement the versioned context/revision-scoped journal with file protection, backup exclusion, and no original prompt or token storage.
- [x] 1.2 Add failing relay tests for simultaneous identical IDs, changed payload/target, write failure before dispatch, restart after dispatch, saved completion before lost reply, and logout/context departure racing a late result. Integrate the journal and in-process attempt joining; check auth/context before lookup and before writes.
- [x] 1.3 Add a failing gateway transport test for optional `prompt.submit.user_row_id` present and absent. Expose a narrow receipt event and persist it without interpreting session binding or unrelated events as prompt acceptance. No backend route/schema change or generated-client edits are needed.

- [x] 1.4 Add failing tests for delayed retry:false after payload eviction, immutable createdAt/payload mismatch, expired or future-skew first dispatch, terminal pressure eviction, tombstone-capacity refusal and slot release, and Forget recovery. Enforce the validity window without timestamp rewriting or automatic resend; retain safety tombstones until expiry.

## 2. Add status-only outcomes

- [x] 2.1 Add failing relay tests proving unknown/expired retries never dispatch and unrelated latest assistant history never counts as completion. Advertise sendState only with protected persistence and implement context-valid forgetSend without server cancellation, and return pending, uncertain, or proven not_sent without assistant text; preserve approval/question waiting behavior.
- [x] 2.2 Add failing telemetry tests for fixed journal operation/outcome values, recognition of `forgetSend` in phone and watch operation sanitizers, and swallowed telemetry errors. Record `watch.send.journal` through AppEventLogger without content, IDs, fingerprints, context, revision, or addresses.
- [x] 2.3 Update the project verify skill with journal restart, retention, slot release, and deletion-failure cases. Preserve its `.agents` forwarding entry and use the isolated native fixture.

## 3. Verify and ship

- [ ] 3.1 Run `dart format .`, `flutter analyze`, `flutter test`, relevant gateway/relay tests, and `swift test --package-path ios/HermesWatch`. Use FakeHermesServer with the generated REST client for any history checks. Verify phone termination after dispatch and before acknowledgement in the isolated verify-in-app fixture; record hardware gaps. Ship `fix(watch): persist send dispatch and result evidence` as one PR targeting fewer than 500 changed lines.

## Implementation evidence

PR #691 merged the journal library, PR #693 merged the optional prompt receipt, and PR #694 merged protected watch pending storage. Durable phone relay integration and restart regressions are in PR #707. Eighteen journal library tests and both gateway receipt tests passed. Protected watch storage tests passed in cloud CI.

Checked implementation tasks describe source and authored regression coverage. They do not
mean that an open PR has merged or that a native acceptance check has passed. Combined
verification tasks remain open until their specified evidence is available. Native visual,
VoiceOver, gesture, microphone, and paired lifecycle checks have not run. The user excluded
watch simulators, and local native builds remain paused to limit host load.
