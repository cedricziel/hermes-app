# Tasks

Three PRs, each about 500 changed lines or fewer. Conventional Commit scope `shell`. It builds on C1 (window sizes) from `docs/design-briefs/macos-platform-fixes.md`; read that brief's minimum-size decision first.

## 1. PR 1: `feat(shell): content pane frame for Mac sub-pages`

- [ ] 1.1 Design pass (`design-pass` skill): sub-pages beside the sidebar at 1100 x 760, 760 x 480 and 640 x 480; the toolbar with sidebar toggle and back button; the sidebar's selected state; Kanban's task panel at 900. Record the decisions in design.md and in `docs/design-briefs/macos-platform-fixes.md`, replacing its "Proposed:" note.
- [ ] 1.2 Build `ContentPaneFrame` (sidebar slot, content slot, toolbar slot; plain model, no controller) in `lib/src/shell/widgets/` with Widgetbook use cases first: Skills, Memory, Files and Tools content at 1100 x 760, 760 x 480 and 640 x 480, light, dark, German, largest text, sidebar collapsed and expanded. Run `flutter test test/widgetbook_test.dart`.
- [ ] 1.3 Scan the source once (a script, not a test) for every `Navigator.of(context)` and `rootNavigator: true` call a sub-page can reach, and the pages that read `isWideLayout(context)` without `width:`; keep its output in design.md.

## 2. PR 2: `feat(shell): keep the Mac sidebar while a sub-page is open`

- [ ] 2.1 Write failing widget tests on a Mac chrome: a push from the chat keeps the sidebar and its selected chat; Back pops to the chat; a dialog from a sub-page uses the root navigator; picking a chat in the sidebar pops the stack; iOS and Material chrome push over the window as before.
- [ ] 2.2 Write failing width tests at 760, 900 and 1100 for Tools and MCP servers (and any page task 1.3 found), then make them read their own box width.
- [ ] 2.3 Write failing history tests: ⌘[ and ⌘] across a content-pane push and across a destination change, with `DesktopNavigationHistory` observing both navigators; if the order is wrong, restrict it to one and say so in design.md.
- [ ] 2.4 Implement `ContentPaneNavigator` and the helper `pushSubpage(context, route, kind:)`; host the navigator in `ChatScreen`'s Mac split (`chat_screen_layout.dart:344`) and in `AppShell`'s (`app_shell.dart:857`); move the call sites in `chat_screen_navigation.dart`, `memory_destination.dart`, `open_files.dart` (with the Activity panel case) and `kanban_screen.dart` to the helper.
- [ ] 2.5 Write failing lifecycle tests, then confirm: sign-out, server change and expiry remove an open sub-page in the same frame; App Lock covers it; Files' downloads are cleared on lock and sign-out (existing `FilesLockCleanup` tests stay green).
- [ ] 2.6 Add the breadcrumbs `nav.subpage.opened` (`kind`) and `nav.subpage.closed_by_sidebar`, with a test that no title, profile, path or id is in them.
- [ ] 2.7 Check the screens with the workflow tests (`workflow-screenshots`) and `verify-in-app`.

## 3. PR 3: `docs(shell): record sub-pages in the content pane`

- [ ] 3.1 Add guard `arch.subpage-push` (a sub-page pushed outside `pushSubpage` fails) with a baseline that ratchets down; update `docs/architecture/app-shell.md` ("Pages above the shell" gains the content-pane rule) and `docs/architecture/macos.md`.
- [ ] 3.2 Run `/simplify`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`.

## Not verified on a device

- Sidebar stays and resizes with a sub-page open on a real Mac; ⌘[ and ⌘] across sub-pages; the window at its 640 x 480 minimum with a sub-page and the sidebar overlay.
