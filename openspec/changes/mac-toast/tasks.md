# Tasks

Three PRs, each about 500 changed lines or fewer. Conventional Commit scope `widgets`.

## 1. PR 1: `feat(widgets): Mac toast view and use cases`

- [ ] 1.1 Design pass (`design-pass` skill) for the toast: placement, look, tones, the modal-barrier question. Record the decisions in design.md and in `docs/design-briefs/macos-platform-fixes.md`, replacing its "Proposed:" note.
- [ ] 1.2 Build `AppToastView` as a plain-model widget in `lib/src/widgets/` (message, tone, action label, callbacks; no controller) with Widgetbook use cases in `widgetbook/` first: every tone with its icon and word, with and without action, one and three lines, German, largest text, light and dark, compact and wide window, hovered, reduced motion. Run `flutter test test/widgetbook_test.dart`.
- [ ] 1.3 Write failing semantics tests (live region, one announcement, icon and word per tone, three-line cut keeps the full text in the label), then make the view pass them.

## 2. PR 2: `feat(widgets): show transient messages as a toast on the Mac`

- [ ] 2.1 Write failing tests for the host with a fake clock: the base and long-text durations, the action minimum, pause on hover and focus, accessible navigation keeps it, replacement, the error that a neutral toast does not replace within one second.
- [ ] 2.2 Write failing tests for App Lock cover and for sign-out and server change dropping the queue; a text field keeps focus while a toast shows.
- [ ] 2.3 Implement `AppToast.show` and the host in `lib/src/widgets/app_toast.dart`, mounted in the `MaterialApp` builder of the main app, the conversation window app and the quick panel; the Material and iOS path calls `ScaffoldMessenger.maybeOf(context)?.showSnackBar` as today. Test that a window without a host falls back.
- [ ] 2.4 Add guard `arch.raw-snackbar` with the baseline of today's counts; run `UPDATE_BASELINE=1 flutter test test/architecture` only to check it lowers nothing.
- [ ] 2.5 Migrate the export flow (remove `_aboveComposer`), the chat notices and schedules; lower the baseline with `UPDATE_BASELINE=1`. Check the screens with a workflow test (`workflow-screenshots`) or `verify-in-app`.

## 3. PR 3 onward: `refactor(<area>): use AppToast`

- [ ] 3.1 One PR per remaining area, each lowering the baseline; no behaviour change on non-Mac platforms. Report hard-coded English messages found on the way to the orchestrator, do not fix them here.
- [ ] 3.2 Update `docs/architecture/macos.md` and `docs/building-blocks.md` (a row "A short result message: AppToast") in the first PR that lands the block.

## Not verified on a device

- VoiceOver speaks a toast once; placement beside a real composer; hover pause with a trackpad.
