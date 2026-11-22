# Design

## Context

Read in the code at the base commit of this branch.

- `SettingsScaffold` (`lib/src/widgets/settings_scaffold.dart:189`) takes `title`, `subtitle`, `subtitleMenu`, `previousTitle`, `actions`, `tabs`, `tabController`, `search`, `formAction`, `cancel`, `macCancel`, `shrinkTitle` and a free `body` widget. On a phone it builds an `AppBar` with the title, and the tabs and search in `AppBar.bottom` (`:366-440`).
- The title text is `SettingsBarTitle` (`:497-545`): 17 pt on iOS, one line, ellipsis (or `FittedBox` with `shrinkTitle`), the subtitle at 12 pt under it.
- Leading: `AdaptiveBackButton`, or `ShellMenu.button` on a shell page, or Cancel for a form (`:379-399`). Pages inside a detail pane have no leading (`inSettingsPane`, `lib/src/widgets/settings_pane.dart`).
- `GroupedListView` (`lib/src/widgets/grouped_list.dart:148`) is a `ListView` with an optional `controller` (so it uses the primary scroll controller when none is given). 55 calls in 48 files.
- Chats: `buildChatAppBar` (`chat_app_bar.dart:107`) and the list `ThreadSidebar(fullPage: true)` (`chat_screen_layout.dart:465`) with `NewChatFab` over it on iOS. Kanban: `kanban_screen.dart:244-270`. Schedules: `schedules_screen.dart:249-275`.
- The iOS bar is 44 pt (`kAppleNavBarHeight`, `lib/src/theme/platform_chrome.dart:27`). The tab bar of a page uses `AdaptiveTabBar`, which clamps text to 1.3x (`adaptive_tab_bar.dart:33-35`).
- `cupertino_ui` 1.1.7 has `CupertinoSliverNavigationBar` (`nav_bar.dart:979`) with `largeTitle` and `bottomMode` (it can hold a search field).

## Options

- **A. `CupertinoSliverNavigationBar` in a `CustomScrollView` per page.** The platform's own widget, collapse animation and blur for free. Every opting-in page's body becomes slivers and `SettingsScaffold` gives up its `Scaffold` and `AppBar` on iOS: `actions`, `formAction`, `subtitleMenu`, the shell menu button and the pane rules would all be rebuilt around it, and 45 pages and their tests move at once. Rejected for the cost, not the look.
- **B. A header inside the content, with the bar's title fading in. (Recommended.)** The `AppBar` stays, so buttons, back chevron, form actions and the Mac and Material paths do not change. The large title is the first child of the page's list; a scope shares the scroll offset with the bar. `GroupedListView` inserts the header, so most pages need one flag.
- **C. A bar that grows and shrinks with the scroll offset.** Changes layout while scrolling and fights the inner list. Rejected.
- **D. Do nothing.** The title truncation at 2.0 text still wants a fix; the cheapest is wrapping the bar title, which still leaves list roots looking like detail pages.

## Decisions

1. **Opt-in, per page.** `SettingsScaffold(largeTitle: true)`. The default is false, so no page changes until it is switched on, one at a time, each with its own screenshot.
2. **Effective only when** the chrome is iOS, the layout is not wide (`!isWideLayout`), the page is not in a detail pane, and neither `cancel` nor `formAction` is set. Otherwise the flag is ignored and the page looks as today.
3. **The scope.** `LargeTitleScope` (an inherited widget) holds a `ScrollController` and the header's measured height. The scaffold supplies it through `PrimaryScrollController`, so any vertical scroll view that is primary (every `ListView` on iOS without its own controller) reports into it. A page whose list has its own controller passes it to the scope.
4. **The header.** `LargeTitleHeader`: title at 34 pt, weight 700, the page's text colour, left aligned at the grouped gutter; the subtitle below it at 15 pt in the muted colour; a subtitle menu keeps its button. It wraps freely and is never clamped (checked to text scale 3.1). It is `Semantics(header: true)`.
5. **The collapse.** The bar title's opacity goes from 0 to 1 over the last 24 pt of the header's scroll-off. With Reduce Motion on it switches at the end instead of fading. While the header is on screen the bar title is excluded from semantics, and once it is off screen the header is, so a screen reader finds one heading.
6. **The bar.** Its hairline appears when the content has scrolled under it (offset above 0), and is absent at rest. The design pass confirms or reverts this.
7. **Search and tabs.** Pages with tabs keep small titles: each tab is its own scroll view and a header cannot scroll with all of them. On a page without a large title the search field stays in `AppBar.bottom`. Leaving it there on a large-title page would put the field above the title, which iOS never does, so on a large-title page (PR 3) the field sits in the content directly under the large title, scrolls away with it, and pins under the bar while it is focused or holds a query; the query, focus and keyboard survive a collapse. The design pass recommended this placement and the owner confirms it before PR 3; the alternative (the field pinned in the bar) is rejected for the reason above.
8. **Which pages.**

| Page                                                                          | Platform | Large title                           | Why                                           |
| ----------------------------------------------------------------------------- | -------- | ------------------------------------- | --------------------------------------------- |
| Server overview, MCP servers, Tools, Profiles, Messaging, Helper models, More | iPhone   | yes (PR 2)                            | one list, no tabs, no search                  |
| Providers, Bots, Schedules, Chats list                                        | iPhone   | yes (PR 3, search under the title)    | one list with a search field or a custom bar  |
| Skills, Plugins, Memory                                                       | iPhone   | no                                    | tabs in the bar                               |
| Kanban                                                                        | iPhone   | no                                    | a board of columns, no single vertical scroll |
| Files, file preview                                                           | iPhone   | no                                    | the path bar needs the room                   |
| Conversation, group chat                                                      | iPhone   | no                                    | not a list                                    |
| Server sub-pages, skill, server and schedule detail, task, editors, forms     | iPhone   | no                                    | detail pages and forms                        |
| Any page in a pane, any page at regular width                                 | iPad     | no                                    | out of scope for now                          |

9. **The Chats list.** On a compact phone the title is the list's own, "Chats", with the profile label under it as the subtitle that the bar carries today. New message stays a 44 pt bar button, and `NewChatFab` is unchanged. If the navigation change has landed, the menu button is already gone from this bar.
10. **Long dynamic titles.** The bar title keeps `shrinkTitle` for long dynamic titles on detail pages, which stay small.

## Platforms

iOS only (iPhone and any compact iOS layout). Android, macOS, Windows, Linux and watchOS are unchanged. No native change.

## Invariants touched

- **App Lock.** The header is page content, so the existing cover hides it; titles are fixed words.
- **Privacy.** The Schedules header can show a profile name; the bar shows it today. Neither goes to a breadcrumb, span or log.
- **Touch targets.** The bar's buttons stay 44 pt. The header is not interactive, except a subtitle menu, which keeps its 44 pt target.
- **Status is not colour alone.** A title carries no status. No change.
- **Large text.** The header wraps; the bar title still shrinks; nothing overflows at 320 pt and scale 3.1.

## Risks

| Risk                                                            | Mitigation                                                                                                                                          |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| A page's list is not primary, so the bar never hears the scroll | The scope's controller is passed to `GroupedListView(controller:)` or to the page's list; a test per opted-in page scrolls and finds the bar title. |
| The header and the bar title are both announced                 | Semantics exclusion as in decision 5; a widget test reads the tree at both offsets.                                                                 |
| Short pages never collapse and keep a bare 34 pt title          | The same on iOS; accepted.                                                                                                                          |
| Pull to refresh above a large title                             | `RefreshIndicator.adaptive` sits over the list; the header scrolls with it. Checked on Chats and Server in the workflow screenshots.                |
| `SettingsScaffold` tests that count `AppBar` children change    | The flag defaults to false; existing tests do not move.                                                                                             |
| The toolsets brief says large titles exist                      | Fix the brief's sentence in the PR that lands the Tools page.                                                                                       |

## Acceptance checks

- **Catalog** (first): the header and the scaffold on iOS in four states: at rest, half collapsed, collapsed, and short content that cannot scroll; with a subtitle, with a subtitle menu, and with a 60 character title; at 390 pt in light and dark, at 320 pt with scale 2.0 and 3.1; the same page on Android and on iPad as a regression pair showing no change.
- **Widget:** the flag is ignored on Material, on macOS, at regular width, in a pane, with `cancel` or `formAction`; with it on, scrolling by the header's height fades the bar title in; the semantics tree holds one heading at each offset; Reduce Motion switches without a fade; `GroupedListView` inserts the header once.
- **Per page:** each opted-in page shows the header and its title, and keeps all of its existing behaviour (existing tests unchanged).
- **Workflow screenshots:** rerun `test/workflows/` as iPhone and look at them.
- **Revert check:** reverting the scope wiring fails the collapse test.

## Design pass

The pass ran; its canvas and per-artboard decisions are in `docs/design-briefs/ios-large-titles.md`. It confirms decision 6 (no hairline at rest) and recommends the search placement that decision 7 now records: the field under the large title, scrolling with it, pinned under the bar once focused or holding a query. PR 3 starts once the owner confirms it.

## Open questions for the design pass

See `docs/design-briefs/ios-large-titles.md`.
