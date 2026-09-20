## 1. Switch to Chat for taps and shares

- [x] 1.1 Write failing widget tests in `test/app_shell_test.dart`: a notification tap, shared text and a shared file each switch from Kanban to Chat
- [x] 1.2 Add `ChatScreen.onShowChat` in `lib/src/chat/chat_screen.dart`, call it for every tap and whenever shared items are taken, and pass the shell's `_showChat` from `lib/src/shell/app_shell.dart`

## 2. Kanban tab lifecycle

- [x] 2.1 Write failing widget tests: the board is not built before its tab opens, is closed on leaving the tab, and is not rebuilt after the plugin goes off and on
- [x] 2.2 Build the Kanban page only while its tab is selected and remove the `_kanbanOpened` flag in `lib/src/shell/app_shell.dart`

## 3. Spec, telemetry and skills

- [x] 3.1 Sync the deltas into `openspec/specs/{kanban,notifications,sharing}/spec.md` and archive the change
- [x] 3.2 Telemetry: none, nothing to add
- [x] 3.3 No `.claude/skills` entry is made stale by this change

## 4. Verify

- [x] 4.1 Run `dart format`, `flutter analyze` and `flutter test`
- [x] 4.2 Verify in the running app: not run, no dev backend is available to this change. The widget tests drive the real shell and chat screen and are the evidence
