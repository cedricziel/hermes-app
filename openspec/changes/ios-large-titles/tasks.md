# Tasks

Three PRs, each about 500 changed lines or fewer with tests. Every behaviour task starts with a failing test. UI starts in the catalog. The design pass (`docs/design-briefs/ios-large-titles.md`) runs before PR 1; PR 3 also waits for the owner to confirm its search placement.

## 1. PR 1: `feat(widgets): add the large title header and scope behind a flag`

- [ ] 1.1 Catalog use cases (first), in `widgetbook/` beside the adaptive chrome ones: the header and a `SettingsScaffold(largeTitle: true)` page on iOS at rest, half collapsed, collapsed and with short content; with a subtitle, a subtitle menu and a 60 character title; 390 pt light and dark, 320 pt at text scale 2.0 and 3.1; the same page on Android and on iPad at 1024 pt as the unchanged pair. `test/widgetbook_test.dart` builds each in both themes.
- [ ] 1.2 Write failing widget tests in `test/widgets/settings_scaffold_test.dart`: the flag is ignored on Material, macOS, expanded layouts (`isWideLayout` true), in a pane, with `cancel` and with `formAction`; on compact iOS scrolling by the header height fades the bar title in; Reduce Motion switches without a fade; one heading in the semantics tree at each offset; the bar's actions keep 44 pt targets at scale 3.1.
- [ ] 1.3 Implement `LargeTitleHeader` and `LargeTitleScope` (`lib/src/widgets/large_title_header.dart`), the flag and the bar title fade in `SettingsScaffold`, and the header insertion in `GroupedListView`. Existing tests must not change.
- [ ] 1.4 Revert check: remove the scope wiring and see the collapse test fail.
- [ ] 1.5 `dart format`, `flutter analyze`, `flutter test`, `flutter test test/architecture`.

## 2. PR 2: `feat(ui): large titles on list pages on iPhone`

Server overview, MCP servers, Tools, Profiles, Messaging and Helper models, and More if the navigation change has landed.

- [ ] 2.1 For each page, a failing test that it shows the header on iOS when not expanded (an iPhone at 390 and 852 wide, an iPad in Split View), the bar title appears after scrolling, and nothing changes on Android and iPad. Then switch the flag on.
- [ ] 2.2 Fix the sentence in `docs/design-briefs/toolsets.md:118` and `:202` if it still names a collapsing title that the Tools page does not have, or keep it if the page now does.
- [ ] 2.3 Update `docs/architecture/app-shell.md` (settings kit) and `docs/architecture/settings-screens.md` with the flag and the rule for which pages opt in.
- [ ] 2.4 Rerun `test/workflows/` as iPhone and look at the screenshots at default and large text.

## 3. PR 3: `feat(ui): large titles on Providers, Bots, Schedules and Chats`

Starts after the owner confirms the search placement of design decision 7 (the field under the large title).

- [ ] 3.1 Failing tests for the search placement in `specs/large-titles/spec.md` ("Search sits under the large title"): the field is under the large title at rest, scrolls away with it when empty and unfocused, pins under the bar while focused or holding a query, and the keyboard and the query survive a collapse.
- [ ] 3.2 Move Schedules' custom `AppBar` onto the same header, and give the Chats list its large title (`chat_screen_layout.dart`, `ThreadSidebar(fullPage: true)`), keeping New message in the bar and `NewChatFab` in place.
- [ ] 3.3 Rerun the workflow screenshots and the Chats tests in `test/messenger_navigation_test.dart`.
- [ ] 3.4 Report to the orchestrator whether Android (`SliverAppBar.large`) and iPad should follow, as roadmap rows.
