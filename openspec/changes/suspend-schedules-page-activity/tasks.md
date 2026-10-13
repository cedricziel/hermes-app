## 1. Page activity boundary

Target one component PR, `fix(schedules): suspend retained page activity`. No generated API, Widgetbook or observability additions are needed.

- [x] 1.1 Start with failing controller tests for inactive reads/actions, timer shutdown and fresh recovery retaining local state; add the optional activity boundary.
- [x] 1.2 Start with failing controller tests for late list/profile/job/run and mutation outcomes; reject retired commands, prevent follow-up dispatch and stale publication, and explicitly update the disposed mutation contract.
- [x] 1.3 Start with failing controller tests for earlier activity listeners, nested false-to-true notifications and suspension during loading/optimistic/publication notifications; fence every delivered notification and continuation.

- [x] 1.4 Start with failing widget tests for held command disposal, retired profile lookup navigation and run-history delay; catch typed cancellation at all changed API callers and recheck activity after awaits.

## 2. Verification

- [x] 2.1 Review project skills for stale guidance; this component introduces no new recurring workflow and requires no skill changes.
- [x] 2.2 Run Dart formatting, Flutter analysis, focused controller and related schedules tests, and strict OpenSpec validation.
- [ ] 2.3 Verify through the isolated verify-in-app loop after owner/UI integration. Leave pending until that integration exists; controller tests alone do not verify native connection behavior.

Verification: 14 initial controller regressions failed against unchanged source. Additional scope-listener, retained-scope and two disposed-outcome regressions also failed before fixes. Three widget callback regressions reproduced uncaught disposed-run and retired-profile cancellation and a stale delayed run-history lookup against unchanged UI callers. All 145 tests in the focused activity, callback, controller, schedules screen, macOS, workflow and editor batch now pass. Formatting reports no changes, focused analysis reports no issues, and strict OpenSpec validation passes. No project skill became stale. No real backend or native client was launched. Owner/UI retention, external intent metadata recovery and native verification remain pending.
