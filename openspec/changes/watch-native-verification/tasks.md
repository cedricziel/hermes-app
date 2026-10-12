## 1. Establish native fixture isolation

- [x] 1.1 Add a checked-in watch verification section or narrow project skill referenced by `.claude/skills/verify-in-app/SKILL.md` and `.agents/skills/verify-in-app/SKILL.md`. Document dedicated simulator pair creation, storage and routing review, synthetic backend credentials, built entitlement checks, evidence capture, and fixture-owned cleanup.
- [x] 1.2 Add a fixture preflight check with a failing test for rejected personal or unverified storage and routing. Require evidence of pair identifiers, isolated credentials and storage, built plist and entitlements, and throwaway backend home before launch. Implement checks without changing release target identities or production settings. Add native test targets only where required.

## 2. Exercise native boundaries

- [ ] 2.1 Add failing native relay tests for reply and background-expiry races, missing handler, malformed reply, and activation failure; expose narrow verification seams without changing product behavior. Assert one completion and resource cleanup within documented API callback contracts. Specify any discovered production behavior bug in a separate change.
- [x] 2.2 Record the lifecycle matrix and evidence format from the design. Link new watch changes to their acceptance cases. Keep simulator and hardware outcomes distinct and mark unsupported cases unavailable.
- [x] 2.3 Confirm sanitized existing diagnostics suffice. No production spans, log events, or breadcrumbs are added.

## 3. Verify and ship

- [ ] 3.1 Run native Xcode tests, `swift test --package-path ios/HermesWatch`, `dart format .`, `flutter analyze`, and `flutter test`. Run the documented isolated native verify-in-app loop, capture evidence, and clean up. Report hardware gaps explicitly. Ship one PR as `test(watch): add isolated native relay verification`, targeting fewer than 500 changed lines.

## Verification constraint

The user explicitly excluded watch simulators on 2026-10-13 after host resource problems.
Continue with portable tests, preflight tests, static analysis, and device SDK compilation.
Native host tests and visual, sleep/wake, notification, and microphone lifecycle checks remain
unverified. Do not treat this override as evidence that those acceptance cases passed.
The task-owned simulator pair was shut down, unpaired, and deleted. No fixture backend or
Flutter build remained running after cleanup. Tasks 2.1 and 3.1 stay open for their unexecuted
native portions and shipping until the coordinating agent records the final evidence.
