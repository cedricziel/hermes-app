# Proposal

**Owner decides:** whether list and overview pages on iPhone get a Cupertino large title that collapses into the 44 pt bar on scroll, starting with the pages that have no tabs or search field, and leaving tab pages, detail pages and forms with small titles; and whether, on the large-title pages that search (PR 3), the search field moves from the bar to under the title (recommended by the design pass) or stays pinned in the bar.

Audit item D5 (roadmap F.230). It does not depend on the navigation change (`compact-and-medium-navigation`) and does not block it.

## Why

The premise is true. No page in the app has a large title: `rg` finds no `CupertinoSliverNavigationBar`, `SliverAppBar.large` or large-title code in `lib/` or `widgetbook/`. Every iPhone page draws a 44 pt bar with a centred 17 pt title:

- `SettingsScaffold._phone` (`lib/src/widgets/settings_scaffold.dart:366-420`): `toolbarHeight: kAppleNavBarHeight`, `centerTitle: ios`, a `SettingsBarTitle` of 17 pt on one line with an ellipsis (`:497-545`). About 45 pages use it (about 50 call sites in about 40 files, among them Server, Bots, Skills, Plugins, MCP servers, Providers, Tools, Profiles, Messaging, Memory, Helper models, Files).
- Chats: `buildChatAppBar` (`lib/src/chat/widgets/chat_app_bar.dart:107-135`) with a centred 17 pt "Chats" (`lib/src/chat/chat_screen_layout.dart:436-452`).
- Kanban: `AppBar(title: const Text('Kanban'))` (`lib/src/kanban/kanban_screen.dart:257-259`).
- Schedules: a custom `AppBar` with `SettingsBarTitle` (`lib/src/schedules/schedules_screen.dart:249-262`).

Two things follow. A list root looks like a pushed detail page, so the person has no cue where they are. And a long title is cut: at 2.0 text the bar title ends in an ellipsis (audit finding, roadmap F.230). Design briefs already assume large titles that do not exist: `docs/design-briefs/toolsets.md:118` says "large title collapsing as in Skills", and Skills has none. This change makes that sentence true or removes it.

## What Changes

On iPhone and other compact iOS layouts, a page that opts in shows its title at 34 pt, left aligned, as the first thing in its scrolling content. The bar above it starts with no title. As the content scrolls up, the large title leaves with it and the bar's own 17 pt title fades in. The bar's buttons, height and back chevron do not change.

- **Where it applies.** A page that is a list or an overview, reached from a tab, from More or from a row, and that has one vertical scroll view. First PR of pages: Server, MCP servers, Tools, Profiles, Messaging, Helper models, and More when the navigation change lands. Second: Providers, Bots, Schedules and the Chats list, which have a search field (see the interaction below).
- **Where it does not.** Pages that stay small: the open conversation, Kanban (a board of columns), Files and the file preview (a path bar needs the room, `docs/design-briefs/server-files.md:91`), Skills, Plugins and Memory (they have tabs in the bar), every detail page (a skill, a server, a task, a schedule), every form with Cancel or Save, the Server sub-pages (Usage, Update, Logs, Check), anything in an iPad detail pane, and anything at regular width.
- **`SettingsScaffold`.** A new `largeTitle` flag, default false. When true on compact iOS and not in a pane and not a form (`cancel` or `formAction` set), the scaffold wraps the body in a scope that holds a scroll controller, puts the large header in front of the body's content, and lets the bar title fade in. `GroupedListView` reads the scope and inserts the header as its first child, so the pages that use it (55 calls in 48 files) need no layout change. A page with its own list places the header itself with the same widget.
- **Subtitle and search.** The subtitle moves from the bar into the header, under the large title; a subtitle menu (Schedules' profile scope) stays a button. PR 2's pages have no search field. On a large-title page with search (PR 3), the field moves out of the bar into the content, directly under the large title: it scrolls away with the title, and pins under the bar while it is focused or holds a query. The design pass recommended this placement; the owner confirms it before PR 3.
- **Text size.** The header is not clamped: at 2.0 and 3.1 it wraps over as many lines as it needs, which is what fixes the truncated title. The small bar title keeps one line and shrinks (`shrinkTitle`) at the largest sizes.
- **Material and macOS.** No change.

## Non-goals

- Android, Windows, Linux and the Mac. Material has `SliverAppBar.large`; it is a separate decision.
- iPad at regular width and pages in a detail pane.
- Shared-element title animation between pages on push and pop.
- Making the bar translucent or blurred.
- Large titles on pages with tabs, forms and detail pages.
- Moving the search field on pages that keep a small title. Only large-title pages move it.

## Capabilities

### New Capabilities

- `large-titles`: which iOS pages show a large title, how it collapses, how it reads in the accessibility tree and at large text, and which pages never show one.

### Modified Capabilities

None. The existing specs describe screens, not title styles.

## Impact

- Code: `lib/src/widgets/settings_scaffold.dart` (the flag, the scope, the bar title fade), a new `lib/src/widgets/large_title_header.dart`, `lib/src/widgets/grouped_list.dart` (read the scope), and the page files listed above. Widgetbook use cases in `widgetbook/adaptive_chrome_use_cases.dart` or a new file beside it. Tests in `test/widgets/settings_scaffold_test.dart` and new ones.
- Backend: none. Native: none. No new package: `cupertino_ui` 1.1.7 ships `CupertinoSliverNavigationBar` (`nav_bar.dart:979`); it is rejected below, not added.
- Security and privacy: None. A title is a fixed word. The Schedules header shows the profile name that the bar already shows; it is on screen only and covered by App Lock like the rest of the page.
- Observability: None. This is a restyle: no work that takes time, no outcome worth counting, no step that explains a crash.
- Delivery: three PRs (see tasks.md).
