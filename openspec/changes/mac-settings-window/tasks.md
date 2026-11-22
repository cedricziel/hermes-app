# Tasks

Three PRs, each about 500 changed lines or fewer. Conventional Commit scope `settings`. The design pass (task 1.1) runs before the catalog work.

## 1. PR 1: `feat(settings): settings window view and bridge types`

- [ ] 1.0 Spike, no merge: can a second view of the main engine host Settings (design option E), and does `desktop_multi_window` open a Settings window with a frame autosave name, a minimum size and no chat entry in the Window menu? Record the answer in design.md. If E works, rewrite the bridge tasks (2.x) as plain providers and say so.
- [ ] 1.1 Design pass for the window (`design-pass` skill); record the decisions in design.md and in `docs/design-briefs/macos-platform-fixes.md`, replacing its "Proposed:" note.
- [ ] 1.2 Build `SettingsWindowView` as a plain-model widget in `lib/src/settings/widgets/` (sections, rows, values, availability, a notice line; callbacks only) with Widgetbook use cases in `widgetbook/` before any wiring: default, German, largest text, light and dark, minimum size, signed out (main-owned rows disabled with the reason), a failing command line. Run `flutter test test/widgetbook_test.dart`.
- [ ] 1.3 Write failing tests, then add `SettingsSnapshot` (a closed record of booleans, enum names and flags) and the command names; a test fails if a snapshot field can hold free text.

## 2. PR 2: `feat(settings): open Settings in its own window on the Mac`

- [ ] 2.1 Write failing tests with a fake window link: open creates one window, a second request focuses it, the window is not in the chat list of the Window menu and is not restored at launch.
- [ ] 2.2 Write failing tests that each main-owned command reaches the main engine and returns a snapshot, that a lost answer repeats nothing, and that no answer carries exception text.
- [ ] 2.3 Implement the main-side `SettingsWindows` (create, focus, snapshot, commands) next to `ConversationWindows`, and `runSettingsWindow` in `lib/src/windows/` (own `MaterialApp`, theme, `ThemeController`, `DictationSettings`, `PortableCallSettings`; no `AuthController`, no `AppLockController`).
- [ ] 2.4 Write failing tests for closing on cover, sign-out, server change and expiry, and for ⌘, while covered. Then implement them on the existing lock and connection listeners.
- [ ] 2.5 Wire `MacCommand.settings` and the account menu on macOS to `SettingsWindows.open`; keep `showSettingsDialog` for the other platforms. Test that the account menu on iOS still opens the dialog.
- [ ] 2.6 Write failing tests that a preference written in the window is read again in the main window (`settings.changed`), then implement it.

## 3. PR 3: `docs(settings): record the Settings window`

- [ ] 3.1 Update `docs/architecture/macos.md` (the window, the bridge, the App Lock rule) and `docs/architecture/app-shell.md` if the shell's command changed. Add a note to the `verify-in-app` skill on opening the window.
- [ ] 3.2 Add the breadcrumbs and the `settings.window.command_failed` event, with tests that no value, name or address is in them.
- [ ] 3.3 Run `/simplify`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`.

## Not verified on a device

- Open, focus and close on a real Mac; the frame survives Command-Q; the window goes when the app locks.
