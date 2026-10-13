## 1. Board suspension

Target one component PR, `fix(kanban): suspend retained board activity`. No backend regeneration, Widgetbook use cases or new observability signals are needed.

- [x] 1.1 Start with failing controller tests for paused reads/actions, immediate stream and timer shutdown, and fresh resume retaining local context; add the optional activity boundary while preserving visibility behavior.
- [x] 1.2 Start with failing tests for old reads, stream connections and bulk results completing after suspension and resume; fence every continuation and follow-up refresh.
- [x] 1.3 Start with failing tests for earlier activity listeners and nested false-to-true notifications; read live activity, invalidate every delivered notification and recheck after notifications before protected dispatch.
- [x] 1.4 Reproduce activity and visibility suspension with immediate resume inside stream subscription creation; reject the retired subscription and its callbacks so fresh resume can attach its stream.

## 2. Verification

- [x] 2.1 Review project skills for stale instructions; no new recurring workflow or skill changes are expected in this component-only change.
- [x] 2.2 Run dart format, focused flutter analyze, focused board activity and existing controller tests, and strict OpenSpec validation.
- [ ] 2.3 Verify the retained board through the isolated verify-in-app loop after owner/UI integration. Keep this task pending until that integration exists; component tests do not establish native connection behavior.

Verification: all 17 initial activity regressions were observed failing for their named behavior before the controller implementation. The initial full batch of 107 tests passed across activity, board controller, filters, reconnect backoff, board screen, bulk bar, action errors and event connection. Independent review reproduced two additional stream attachment regressions before fixing them. After those fixes, all 53 tests in `kanban_board_activity_test.dart` and `kanban_board_controller_test.dart` pass, including all 19 activity regressions. Direct Dart formatting reports no changes and focused Flutter analysis reports no issues. Strict OpenSpec validation passes with the review additions. Tests use the real generated client through `FakeHermesServer` and fake time with zero-time event delivery. No project skill became stale. Native and integrated owner verification remain pending; no personal backend or native client was launched.
