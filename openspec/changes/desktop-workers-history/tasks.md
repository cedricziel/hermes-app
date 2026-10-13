## 1. Guarded history (feat(navigation))

- [x] 1.1 Start with failing widget tests for eligible Back/Forward, rejected guards, modal exclusion, branch clearing, programmatic removal, and external unwinds; implement bounded immutable-target history.
- [x] 1.2 Start with failing tests for gates and late resolution cancellation; wire root history to live auth/lock/Handoff state and peer/external invalidation.

## 2. Workers and desktop commands

- [x] 2.1 Start with failing HTTP-backed workers replay tests for board/plugin removal and read-only reconstruction; register workers with fresh repository resolution. No API contract or generated client change is needed.
- [x] 2.2 Start with failing tests for Cmd+] menu, auxiliary-window disabling, mouse side buttons, and unchanged scrolling; wire the shared guarded command engine and toolbar Back. Existing widgets need no Widgetbook use cases.
- [x] 2.3 Start with a failing test for fixed history outcome breadcrumbs and add them without user content. Existing HTTP spans cover reads; no new logs. Review existing skills for stale instructions; no workflow change or new skill is expected.

## 3. Verification

- [x] 3.1 Run dart format, flutter analyze, focused flutter tests, and strict OpenSpec validation. Record that verify-in-app/native input verification is excluded by the authorized source-only scope and remains outstanding.

## 4. Reviewed regressions

- [x] 4.1 Reproduce desktop settings toolbar Back bypass with failing Windows/Linux tests; delegate desktop Back through history while preserving mobile behavior.
- [x] 4.2 Reproduce late Forward under auxiliary focus with a held HTTP GET and FakeWindowHost; gate live window ownership/windowless events and cancel pending resolution on focus transitions.
- [x] 4.3 Reproduce cancelled guarded queue suppression with a failing engine widget test; wake cancellation and preserve newest external request semantics.
- [x] 4.4 Run scoped regression tests, full analysis, formatting, strict OpenSpec validation, and whitespace checks; native input remains unverified.

## 5. Held framework guard

- [x] 5.1 Reproduce cancellation during a held willPop future with one failing component test; race cancel/dispose against maybePop, handle detached errors, retain newer intents, and document that already-requested framework effects cannot be undone.
- [x] 5.2 Run focused regression tests, full analysis, format, strict OpenSpec validation, and whitespace checks; freeze the reviewed scope without native or backend verification.
