# Tasks

Two PRs, then one per remaining area, each about 500 changed lines or fewer. Conventional Commit scope `widgets`.

## 1. PR 1: `feat(widgets): Mac toast view and use cases`

- [ ] 1.1 Design pass (`design-pass` skill) for the toast: placement, look, tones, the modal-barrier question. Record the decisions in design.md and in `docs/design-briefs/macos-platform-fixes.md`, replacing its "Proposed:" note.
- [ ] 1.2 Add the tone words Info, Done, Warning and Error to `lib/l10n/arb/app_en.arb` and `app_de.arb` (German: Info, Erledigt, Warnung, Fehler) under the widgets area anchor, with descriptions; run `flutter gen-l10n`.
- [ ] 1.3 Build `AppToastView` as a plain-model widget in `lib/src/widgets/` (message, tone, action label, callbacks; no controller) with Widgetbook use cases in `widgetbook/` first: every tone with its icon and word, with and without action, one and three lines, German, largest text, light and dark, compact and wide window, hovered, reduced motion. Run `flutter test test/widgetbook_test.dart`.
- [ ] 1.4 Write failing semantics tests (live region, one announcement, icon and word per tone, three-line cut keeps the full text in the label), then make the view pass them.

## 2. PR 2: `feat(widgets): show transient messages as a toast on the Mac`

- [ ] 2.1 Write failing tests for the host with a fake clock: the base and long-text durations, the action minimum, pause on hover and focus, accessible navigation keeps it, a click or Escape dismisses it, replacement, the error that a neutral toast does not replace within one second.
- [ ] 2.2 Write failing tests for App Lock cover and for sign-out and server change dropping the queue, and for `queue.locked` hiding the toast in a conversation window and the quick panel; a text field keeps focus while a toast shows.
- [ ] 2.3 Implement `AppToast.show` and the host in `lib/src/widgets/app_toast.dart`, mounted in the `MaterialApp` builder of the main app, the conversation window app and the quick panel, and the `ToastRegion` around the Mac content pane (`AppShell` and `ChatScreen`), with a test that the toast sits in the pane and never over the sidebar; the Material and iOS path calls `ScaffoldMessenger.maybeOf(context)?.showSnackBar` as today. Test that a window without a host falls back.
- [ ] 2.4 Add guard `arch.raw-snackbar` in `test/architecture/`; check first that it fails on a new raw `showSnackBar` call outside `lib/src/widgets/app_toast.dart` and that its message names `AppToast.show`, then record the baseline of today's counts; run `UPDATE_BASELINE=1 flutter test test/architecture` only to check it lowers nothing.
- [ ] 2.5 Migrate the export flow (remove `_aboveComposer`), the chat notices and schedules; lower the baseline with `UPDATE_BASELINE=1`. Check the screens with a workflow test (`workflow-screenshots`) or `verify-in-app`.
- [ ] 2.6 Update `docs/architecture/macos.md` and `docs/building-blocks.md` (a row "A short result message: AppToast") in this PR, which lands the block.
- [ ] 2.7 Update the skills it makes stale in this PR: `workflow-screenshots` and `verify-in-app` (where a toast shows on the Mac and how to catch it in a screenshot), and `architecture-guards` if `arch.raw-snackbar` needs a note.
- [ ] 2.8 Telemetry: none, as the proposal says; no task adds a span, log event or breadcrumb, and a review checks that no toast text reaches one.
- [ ] 2.9 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`; confirm no Hermes route or RPC was added (Backend contract); check a toast on a Mac with `verify-in-app` (placement in the content pane, VoiceOver, hover pause).

## 3. PR 3 onward: `feat(<area>): show <area> messages as a Mac toast`

Each migration changes what a Mac user sees (a toast instead of a SnackBar), so it is a `feat`, not a `refactor`; it also lowers the `arch.raw-snackbar` baseline, test code that belongs in the same PR.

- [ ] 3.1 One PR per remaining area: write a failing widget test that the area's message shows as a toast on Mac chrome and as today's SnackBar elsewhere, move its calls to `AppToast.show`, and lower the baseline with `UPDATE_BASELINE=1`. Update any architecture doc or skill that describes that area's messages in the same PR. Report hard-coded English messages found on the way to the orchestrator, do not fix them here.
- [ ] 3.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, then check a toast on a Mac with `verify-in-app` (placement in the content pane, VoiceOver, hover pause).

## Not verified on a device

- VoiceOver speaks a toast once; placement beside a real composer; hover pause with a trackpad.
