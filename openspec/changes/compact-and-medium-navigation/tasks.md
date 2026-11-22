# Tasks

Three PRs, each about 500 changed lines or fewer with tests, merged in order. Every behaviour task starts with a failing test. UI starts in the catalog. The design pass (`docs/design-briefs/compact-and-medium-navigation.md`) runs before PR 1 and its decisions are written into that brief.

## 1. PR 1: `feat(shell): add the destination bar, rail and More page to the catalog`

Plain-model widgets and the form function. Nothing is wired into the shell.

- [ ] 1.1 Catalog use cases in `widgetbook/` (first): `ShellDestinationBar` in its Apple tab bar, Material navigation bar and Material rail forms, each with 2, 4 and 5 items, every item selected in turn, with and without the attention mark, light and dark, at 320 pt with text scale 2.0, 390 pt, 600 dp and 840 dp; the More page with every entry offered, with none of the optional ones, and with the attention mark; medium Chats as a plain-model list beside a detail placeholder, with and without a selection. `test/widgetbook_test.dart` builds them in both themes.
- [ ] 1.2 Write the failing table test for `shellFormOf` (Android: 599.9 compact, 600 to 899.9 medium, 900 expanded; iPhone 932 x 430 expanded, 852 x 393 medium, 393 x 852 compact; iPad 744 x 1133 and 1024 x 1366 expanded, Split View 507 wide compact; Android tablet 800 x 1280 medium; Windows 700 medium; Mac expanded at any width), then implement it next to `isWideLayout` in `lib/src/theme/breakpoints.dart`. Add a guard test that `isWideLayout` is true exactly when the form is expanded on non-Mac platforms.
- [ ] 1.3 Write failing widget tests for `ShellDestinationBar`: item labels and `Semantics` names, `selected` state, filled icon and bold label on the selected item (not colour alone), 44 pt (iOS) and 48 dp (Android) targets at scale 1.0, 2.0 and 3.1, labels whole on one line at 320 pt and 2.0 with five items, the badge's accessible words. Then implement the widget.
- [ ] 1.4 Write failing tests for the More page (a gate per entry, the Memory waiting count, the attention words), then implement it with `SettingsScaffold` and `GroupedListView` and a `MoreEntry` model.
- [ ] 1.5 Put every user-visible string of the bar, rail and More page ("Chats", "Bots", "Kanban", "Schedules", "More", "Settings", the section headers and the attention words) in `lib/l10n/arb/app_en.arb` and `app_de.arb` under the `@@x-area-shell` anchor, read with `context.l10n`; run `flutter gen-l10n`. A widget test pumps the German locale and finds the German labels.
- [ ] 1.6 Run the architecture guards (`flutter test test/architecture`), `dart format`, `flutter analyze` and `flutter test`.

## 2. PR 2: `feat(shell): navigate by tab bar on phones`

- [ ] 2.1 Write failing `AppShell` widget tests on iPhone and Android phone sizes: the items per server answer (none extra, each of Bots, Kanban, Schedules, all three); a destination that goes off while selected falls back to Chats; pages stay alive across a switch (a Kanban filter survives); the bar is hidden in an open conversation, with the keyboard up and under a pushed page; all five deep link kinds select the right item with a pushed page open and are ignored when not offered; App Lock covered leaves no tab in the semantics tree, and the same item is selected after unlock.
- [ ] 2.2 Publish the drawer's entries from `ChatScreen` as a `MoreEntry` list (an inherited widget the shell reads) and move the account menu's entries and Server into it. Write the failing test per gate first, mirroring today's drawer test in `test/messenger_navigation_test.dart`.
- [ ] 2.3 Move the drawer's and the account menu's entries that are hard-coded English today (`chat_screen_layout.dart:376-434`, `thread_sidebar.dart:943-988`) into en and de ARB strings under the `@@x-area-shell` anchor, read with `context.l10n` by both the More page and the Windows and Linux drawer; run `flutter gen-l10n`. Reuse existing keys where they already exist.
- [ ] 2.4 Wire the bar into `AppShell._build` for iOS and Android below the medium form, remove the drawer and `ShellMenu` there (Windows and Linux keep them), and drop the `shell-menu` button from the Chats list bar. Update `test/chat_screen_shell_menu_test.dart` and `test/messenger_navigation_test.dart`.
- [ ] 2.5 Add the `form` and `via` attributes to `nav.destination` (`via`: `bar`, `rail`, `drawer`, `sidebar`, `link`, `fallback`, passed by each caller of `_select`) and the `nav.more.opened` breadcrumb, with a test per value that the attributes are fixed and no title, profile or id appears.
- [ ] 2.6 Write failing tests for Android Back on a tab root (decision 11): Back on Kanban's root selects Chats, Back on Chats leaves the app; if the owner keeps today's behaviour, the first test asserts the alternative instead. Then implement it with a `PopScope` on the shell.
- [ ] 2.7 Update `docs/architecture/app-shell.md` ("State and routing", "Messenger navigation") and the kanban, messenger-navigation, memory-navigation, mcp-servers and deep-links specs through the deltas in this change; the `requests` link selects Chats on a phone instead of opening the chat drawer (test in `test/deep_links/`).
- [ ] 2.8 Rerun `test/workflows/` on phone sizes and look at the screenshots; run `verify-in-app` on an iOS and an Android simulator if one is available, and say in the PR what was not checked on a device.

## 3. PR 3: `feat(shell): add a navigation rail and list-detail Chats at medium width`

- [ ] 3.1 Write failing tests: at 600, 719, 720 and 899 dp on Android the rail shows the same items as the bar; Chats is a single pane below 720 and list plus detail from 720; a resize across 599 to 600 to 720 to 900 and back keeps the open conversation, its draft, a queued prompt and a running reply, and builds one `ChatScreen`; Windows at 700 dp gets the rail and at 500 dp the drawer; an iPad at 744 keeps the sidebar.
- [ ] 3.2 Add the medium layout to `ChatScreen` (`lib/src/chat/chat_screen_layout.dart`) and the rail to the shell. The list column reuses `ThreadSidebar(fullPage: true)` and shows no destination rows.
- [ ] 3.3 Update `docs/architecture/app-shell.md` and `docs/architecture/chat.md`, then rerun the workflow screenshots at tablet sizes.
- [ ] 3.4 Report to the orchestrator: whether Schedules and Server should split below 900 dp (a roadmap row), and any finding along the way.
