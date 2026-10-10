This change is two PRs. PR A (sections 1-2) ships the native panel host and the shortcut with an empty panel behind it; PR B (sections 3-5) fills the panel with the chat. Each stays near 500 changed lines.

## 1. PR A: native panel host — `feat(macos): add a quick panel window`

- [x] 1.1 Spike, with a failing native check first (Runner test or a scripted `scripts/dev-app.sh` screenshot when XCTest cannot host it): create a `desktop_multi_window` window marked `kind: panel`, re-parent its `FlutterViewController` into a non-activating floating `NSPanel` (`QuickPanel` in `MainFlutterWindow.swift`), hide and show it ten times, and confirm the engine and main channel survive. Fall back to `object_setClass` if re-parenting fails; record the choice in design.md. (Done as a scripted check, not a committed test; see the verify-in-app skill.)
- [x] 1.2 Failing Dart tests first: panel launch args (`kind: panel`) round-trip in `conversation_window_args.dart`; `ConversationWindows` skips the panel in persistence and the Window menu, answers `profile.current` from `ChatProfiles`, and closes the panel on sign-out. Implement.
- [x] 1.3 Register `RecordPlugin` and `HermesSpeechPlugin` in `QuickPanel` only; keep `ConversationWindow.registerPlugins` unchanged. Comment why.

## 2. PR A: shortcut and setting

- [x] 2.1 Spike first: add the KeyboardShortcuts Swift package to `Runner.xcodeproj` through Xcode SPM (Runner target only; commit the pbxproj and `Package.resolved`, `git restore` other Xcode churn), confirm `flutter build macos` works from a clean clone and in the sandboxed Release build, then show `RecorderCocoa` in Settings as an `AppKitView` platform view (`hermes_app/shortcut_recorder`). If it cannot be made to fit, use the Flutter recorder fallback from design decision 2. Record the result in design.md.
- [x] 2.2 Widgetbook use cases for `ShortcutRecorderRow` (no shortcut, shortcut set, narrow width) in both themes, with a plain stand-in for the native view.
- [x] 2.3 Failing tests with a fake `GlobalShortcut` first: a press shows the panel when a connection is ready and the main window otherwise, a recorder change logs `panel.shortcut_changed {set}` without the chord, the row shows set or empty. Implement `QuickPanelShortcut.swift` (name `quickPanel`, no default, `onKeyDown` forwarded over `hermes_app/quick_panel`), the Dart `GlobalShortcut` and the Settings… row in `settings_dialog.dart`.
- [x] 2.4 Breadcrumbs `panel.shortcut_pressed`, `panel.shown`/`panel.hidden {reason}` forwarded from the panel engine, with a test that no attribute holds text.

## 3. PR B: panel chat — `feat(macos): chat in the quick panel`

- [ ] 3.1 Failing unit tests for `QuickPanelSession` with a fake clock: continue under 5 minutes on the same profile, fresh after 5 minutes or a profile change, cleared after Open in Hermes. Implement; record `panel.chat {continued}`.
- [ ] 3.2 Widgetbook use cases for `QuickPanelView` (empty, typing, dictating, streaming, approval request, failed reply) at panel width, both themes.
- [ ] 3.3 Failing widget tests with `FakeChatTransport` and `FakeHermesServer`: Return sends on the current profile, reply streams, Escape cancels dictation then hides, model pill hides when options fail. Wire `QuickPanelScreen` with `ChatController`, `ChatComposer`, `ComposerModelPill`, attachments and a panel-owned `DictationController`; resize the panel as content grows.

## 4. PR B: Open in Hermes

- [ ] 4.1 Failing test first: `showInWindow` opens or focuses the chat's conversation window via `ConversationWindows`, hides the panel and logs `panel.opened_in_window`. Implement button and ⌘O.

## 5. Docs and verify (each PR)

- [ ] 5.1 Update CLAUDE.md (Conversation windows paragraph) and `.claude/skills/verify-in-app/SKILL.md` with how to record a shortcut (the native recorder) and check the panel over a full-screen app.
- [ ] 5.2 Run `dart format`, `flutter analyze`, `flutter test`, build macOS (Release, sandboxed), and verify-in-app against `scripts/dev-backend.sh`: summon over another app and a full-screen app, send, dictate, continue within 5 minutes, start fresh after, Open in Hermes while streaming, Escape, sign out.
