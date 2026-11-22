# Tasks

Two PRs, each about 500 changed lines or fewer. Conventional Commit scope `shell`. It builds on C1 (window sizes) from `docs/design-briefs/macos-platform-fixes.md`; read that brief's minimum-size decision first.

## 1. PR 1: `feat(shell): content pane frame for Mac sub-pages`

- [ ] 1.1 Design pass (`design-pass` skill): sub-pages beside the sidebar at 1100 x 760, 760 x 480 and 640 x 480; the toolbar with sidebar toggle and back button; the sidebar's selected state; Kanban's task panel at 900. Record the decisions in design.md and in `docs/design-briefs/macos-platform-fixes.md`, replacing its "Proposed:" note.
- [ ] 1.2 Build `ContentPaneFrame` (sidebar slot, content slot, toolbar slot; plain model, no controller) in `lib/src/shell/widgets/` with Widgetbook use cases first: Skills, Memory, Files and Tools content at 1100 x 760, 760 x 480 and 640 x 480, light, dark, German, largest text, sidebar collapsed and expanded. Run `flutter test test/widgetbook_test.dart`.
- [ ] 1.3 Write a failing widget test, then give `SettingsScaffold` on the Mac a narrow-pane mode: below a content width (find it in the catalog; 480 needs it) the toolbar search field becomes a 28 pt search button that opens the field, so the subtitle is not cut. Add the use case at 760 x 480, and describe the mode in `docs/architecture/settings-screens.md` (the `SettingsScaffold` paragraph) in the same PR.
- [ ] 1.4 Scan the source once (a script, not a test) for every `Navigator.of(context)` and `rootNavigator: true` call a sub-page can reach, and the pages that read `isWideLayout(context)` without `width:`; keep its output in design.md.

## 2. PR 2: `feat(shell): keep the Mac sidebar while a sub-page is open`

- [ ] 2.1 Write failing widget tests on a Mac chrome: a push from the chat keeps the sidebar and leaves no chat row selected while the page is open (the design pass's answer to open question 2); Back pops to the chat and selects it again; a dialog from a sub-page uses the root navigator and Connection details still covers the window; picking a chat or a destination in the sidebar pops the stack; in a compact window the page fills the window and the sidebar opens over it from the toolbar button; iOS and Material chrome push over the window as before.
- [ ] 2.2 Write failing width tests at 760, 900 and 1100 for Tools and MCP servers (and any page task 1.4 found), then make them read their own box width.
- [ ] 2.3 Write failing history tests: ⌘[ and ⌘] across a content-pane push and across a destination change, and ⌘[ with a dialog over a sub-page (the page stays), with `DesktopNavigationHistory` observing both navigators; if the order is wrong, restrict it to one and say so in design.md.
- [ ] 2.4 Implement `ContentPaneNavigator` and the helper `pushSubpage(context, route, kind:)`; host the navigator in `ChatScreen`'s Mac split (`chat_screen_layout.dart:344`) and in `AppShell`'s (`app_shell.dart:861`); move the call sites in `chat_screen_navigation.dart`, `memory_destination.dart`, `open_files.dart` (with the Activity panel case), `kanban_screen.dart` (`:206`, `:306`) and the server-care pages (`lib/src/server_care/server_screen.dart:47`, `:241`; `lib/src/server_care/update_page.dart:74`) to the helper.
- [ ] 2.5 Write failing lifecycle tests, then confirm: sign-out, server change and expiry remove an open sub-page in the same frame; App Lock covers it; Files' downloads are cleared on lock and sign-out (existing `FilesLockCleanup` tests stay green).
- [ ] 2.6 Add the breadcrumbs `nav.subpage.opened` (`kind`) and `nav.subpage.closed_by_sidebar`, with a test that no title, profile, path or id is in them.
- [ ] 2.7 Add guard `arch.subpage-push` (a sub-page pushed outside `pushSubpage` fails) in `test/architecture/` with a baseline that ratchets down; check it fails on a raw push first.
- [ ] 2.8 Update `docs/architecture/app-shell.md` ("Pages above the shell" gains the content-pane rule) and `docs/architecture/macos.md` in this PR.
- [ ] 2.9 Update the skills this makes stale in this PR: `verify-in-app` and `workflow-screenshots` (a sub-page now shows beside the sidebar on the Mac, so screenshots and navigation steps change), and `architecture-guards` for `arch.subpage-push`.
- [ ] 2.10 Run `/simplify` and apply its code fixes here, then `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`; confirm no Hermes route or RPC was added (Backend contract); check the screens with the workflow tests (`workflow-screenshots`) and `verify-in-app`: Skills, Memory and Files beside the sidebar.

## Not verified on a device

- Sidebar stays and resizes with a sub-page open on a real Mac; ⌘[ and ⌘] across sub-pages; the window at its 640 x 480 minimum with a sub-page and the sidebar overlay.
