# Design

Platforms: macOS in this change. Windows and Linux share the code path and can be switched on later; iOS, iPadOS and Android are not touched. No native, entitlement or Xcode change.

Invariants touched: auth (no page of an old session outlives the connection), App Lock (the cover stays above every page), privacy (Files and server-care rules, no path or name in a signal), telemetry (fixed names only), navigation history (⌘[ and ⌘]).

## Current behaviour

- One root navigator: `MaterialApp` at `lib/src/app.dart:173`, with the observers `_handoffObserver`, `_history` (`DesktopNavigationHistory`) and `_pushedRoutes`. The shell is its `home`.
- The Mac sidebar is a `MacSplitView` (`lib/src/macos/mac_sidebar.dart:279`). Two places build it: `AppShell` for the non-chat destinations (`lib/src/shell/app_shell.dart:860-864`) and `ChatScreen` for the chat (`lib/src/chat/chat_screen_layout.dart:344-347`, `buildSidebar(...)` beside `content`). `MacSidebarScope` is provided inside `AppShell` (`app_shell.dart:749`).
- Sub-pages are root-navigator routes, so they cover the split view. List: `chat_screen_navigation.dart` `:274` Profiles, `:311` Messaging, `:327` Skills, `:351` Plugins, `:361` MCP, `:404` Tools, `:491` Providers, `:510` Helper models; `lib/src/memory/memory_destination.dart:47` Memory; `lib/src/files/open_files.dart:67` Files (root navigator by choice, because the Activity panel has its own navigator, `lib/src/chat/activity/checkpoints_context_panel.dart:241`); `lib/src/kanban/kanban_screen.dart:206`, `:306`; the server-care pages (`lib/src/server_care/server_screen.dart:47`, `:241`; `lib/src/server_care/update_page.dart:74`). Connection details (`chat_screen_navigation.dart:520`) is pushed on the root navigator too and stays there (see "What B changes").
- Each such page draws its own toolbar. `SettingsScaffold` on macOS shows `MacToolbar` with a back button and leaves room for the traffic lights when the page covers the window (`lib/src/widgets/settings_scaffold.dart:244-276`, `mac_toolbar.dart:45-47`). ⌘[ is `MacCommand.back`, offered while the route is current (`settings_scaffold.dart:260-262`) and routed through `DesktopNavigationHistory`.
- Pages that sit in a pane already exist: `SettingsPane` marks a page with no route of its own (`lib/src/widgets/settings_pane.dart`, used by `ServerSplitView`).
- Widths: the sidebar docks from `kMacCompactWindowWidth` (760) and is 220 to 360 wide, 280 by default (`mac_sidebar.dart:14-20`). At 760 the content is 400 to 540 wide. List-and-detail pages already read their own box width: `kMacSplitBreakpoint` (560, `lib/src/theme/breakpoints.dart:38`) is written for "a Mac window's sidebar takes room", and `providers_screen.dart:570` and `schedules_screen.dart:210` use it. A few pages read the window's width instead (`isWideLayout(context)` without `width:`, e.g. `lib/src/tools/tools_screen.dart:347`, `lib/src/mcp/mcp_servers_screen.dart:80`) and would think they have 900 points when they have 620.
- The window minimum is 640 x 480 and the first-launch size 1100 x 760 (C1 in `docs/design-briefs/macos-platform-fixes.md`); at 640 the window is compact and the sidebar opens over the page.

## Options

A. Wrap each pushed page in its own split view (`MacSplitView(sidebar: ..., content: page)` in every route builder). Rejected: the sidebar's controller state (chats, search, selection) belongs to `ChatScreen`, so each route would need it passed in or duplicated, and the sidebar would animate in and out with every route.

B. A nested `Navigator` in the content slot (recommended). `ChatScreen` and `AppShell` wrap `content` in a shared `ContentPaneNavigator` whose first page is today's content; sub-pages push onto it through the helper `pushSubpage` ("What B changes"), so the call sites in `chat_screen_navigation.dart`, `memory_destination.dart`, `open_files.dart`, `kanban_screen.dart` and the server-care pages (`lib/src/server_care/server_screen.dart`, `lib/src/server_care/update_page.dart`) move to it: `ChatScreen`'s own context sits above the nested navigator, so a plain `Navigator.of(context)` there would still find the root; dialogs, sheets and popups keep using the root navigator (`showAppDialog`, `lib/src/widgets/dialog_presentation.dart:12`). The sidebar sits outside it and never rebuilds for a push. `ChatScreen` already runs nested navigators for the compact messenger (`chat_screen_layout.dart:363`) and the Activity panel, so the pattern exists.

C. Make each sub-page a `SettingsPane` in a destination, as Server does. Right for list-and-detail areas (Providers, Messaging), too large for one change, and it does not cover Files or Memory.

D. Do nothing; document that Back is the way out. Cheapest; leaves the audit finding open.

Recommendation: B, Mac first.

## What B changes

- Which routes: all sub-pages listed above. Full-window routes stay on the root navigator: Connection details and sign-in (`HomeScreen`), the voice call screen, the Bot Screen viewer, media and Quick Look viewers, and every dialog, sheet and popup menu. A route helper `pushSubpage(context, route, kind:)` picks the nested navigator on macOS and the root one elsewhere, so a future switch for Windows and Linux is one condition.
- Files: `openFiles` today pushes with `rootNavigator: true`. It moves to the nearest content-pane navigator, except when called from the Activity panel, whose own navigator closes with the panel; there it asks the panel to close and pushes onto the content pane.
- Back: the toolbar's back button pops the nested navigator. ⌘[ and ⌘] keep working: the `DesktopNavigationHistory` observer is passed to the nested navigator as well (`observers:`), and its target resolver learns the same sub-page kinds (task 2.3 checks that history built from two navigators is ordered correctly; if it is not, history records only the content pane's routes). While a dialog is over the page ⌘[ does not leave the page, as `settings_scaffold.dart:258` says.
- Escape and the window's close button are unchanged.
- The sidebar stays live: picking a chat or a destination while a sub-page is open pops the content pane to its first route and then shows the pick. Search in the toolbar of the chat is not available on a sub-page (its toolbar belongs to the chat); the sub-page's own toolbar shows.
- Toolbar: a page in the pane has no traffic-light padding (`clearTrafficLights` false); it shows the sidebar toggle at its leading edge when the sidebar is collapsed or compact, next to the back button (`MacToolbar` already does this when a `ShellMenu` is above it).
- Selected state (open question 2, decided in the design pass, the owner may overrule): while a sub-page is open the Chat destination stays current and no chat row is selected; the toolbar title says where the user is. Back to the first route selects the chat the user came from again; picking a chat selects that one.
- Connection end: `AppShell` unmounts and takes the nested navigator with it, so no page of the old session stays, and `ConnectionPageCloser` still sweeps the root. Keep the rule from `docs/architecture/app-shell.md` ("Pages above the shell") and add: a page in the content pane goes when the shell does. Under App Lock `AppLockGate` already covers everything (`lib/src/app_lock/app_lock_gate.dart`), so a pane page is covered too; Files and server-care pages keep their lock cleanup (`FilesLockCleanup`, `ClosesWith`).
- Android back and the iOS swipe are not affected on those platforms (root navigator as before).

## Window size

- At 1100 x 760 and wider: nothing to decide; content is 800 or more.
- At 760 to about 840 wide (docked sidebar 280): content is 480 to 560, under `kMacSplitBreakpoint`; list-and-detail pages stack. That already holds for pages that read their box width. The pages that read the window width must read their own box: task 2.2 fixes the ones the audit finds (`tools_screen.dart:347` and `mcp_servers_screen.dart:80` are the known ones), each with a test at 760.
- Below 760 (compact, including the 640 minimum): no docked sidebar; the sub-page has the whole width and the sidebar opens over it from the toolbar button. This is today's width but the sidebar stays reachable.
- Minimum size: keep 640 x 480. The Kanban inspector docks from 760 of its own box (`kInspectorDockedMinWidth`); inside the pane it may overlay at window widths where it used to dock; the design pass checks Kanban's task panel at 900. If a page cannot work in 480 points of content, raise `kMacCompactWindowWidth` for that page's sake, never the window minimum.

## Risks

- A nested navigator changes `Navigator.of(context)` for every widget below it; code that expected the root (a `pop` that meant "close the shell page", `rootNavigator: true` lookups, `ModalRoute.of(context)`) needs a pass. A source scan (task 1.4) lists every `Navigator.of(context, rootNavigator: true)` and `Navigator.of(context)` under `lib/src/` that a sub-page can reach.
- Hero and shared-element transitions between the content pane and a page.
- Handoff and deep links open pages through the root navigator (`HandoffNavigationObserver`, notification targets); a link to Skills must still land in the pane, not over it.
- `DesktopNavigationHistory` and `PushedRoutes` were written for one navigator.
- Memory held by a page that used to cover the window is the same, but the chat behind it is now a visible, live pane: pages must not assume the chat is paused.

## Acceptance

- Catalog (`widgetbook/`): the pane frame (`ContentPaneFrame`: sidebar slot plus content slot plus toolbar) with Skills, Memory, Files and Tools content, at 1100 x 760, 760 x 480 and 640 x 480, light, dark, German, largest text, sidebar collapsed and expanded.
- Widget tests: a push from the chat keeps the sidebar and clears the chat row's selection; Back pops to the chat and selects it again; ⌘[ and ⌘] move through sub-pages; picking another chat from the sidebar pops the stack; a dialog opened from a sub-page uses the root navigator and covers the window.
- Lifecycle tests: sign-out, server change and session expiry remove an open sub-page in the same frame as today; App Lock covers it and Files' downloads are cleared (the existing `FilesLockCleanup` tests keep passing).
- Width tests at 760, 900 and 1100 for Tools and MCP servers.
- Workflow tests (`test/workflows/`) keep passing; look at the new screenshots.
- Architecture guard `arch.subpage-push`: a sub-page route pushed with `Navigator.of(context).push` or `rootNavigator: true` outside the helper fails, baseline of the current sites that ratchets down.
- Spec scenarios in `specs/mac-subpages/spec.md`.

## Telemetry

- Breadcrumb `nav.subpage.opened`, recorded by `pushSubpage` through `Breadcrumbs` when it pushes a sub-page, with one attribute, `kind`: a fixed slug per route (`skills`, `memory`, `files`, `tools`, ...), never a title, profile, path or id.
- Breadcrumb `nav.subpage.closed_by_sidebar`, recorded by `ContentPaneNavigator` when a pick in the sidebar pops the stack, with no attributes.
- No span and no log event: nothing crosses a boundary. None of these holds user content; a test checks the attribute set.

## Design pass

Canvas "Hermes: Mac Settings window, toast, sub-pages" (private, ask its owner for access): https://claude.ai/artifact/Q36fmBuDK9Gy3jkgBF2g5R. Its "C11" row, one decision per board:

- Today, Skills over the whole window: pushed on the root navigator; the sidebar and its toggle are gone until Back.
- Proposed, Skills in the content pane (1280 x 800): the sidebar stays live; the Chat destination stays current but no chat row is selected while a sub-page is open (open question 2); Back (Command-[) is the toolbar's leading button and the page has no traffic-light padding.
- Proposed at 760 x 480, the narrowest docked window: the sidebar still docks at 280 and the page gets 480. With the search field in the toolbar the subtitle was cut to "defaul…", so in a narrow pane the field becomes a 28 pt search button beside +; Back, title, tabs and + stay. `SettingsScaffold` needs that narrow mode on the Mac.

Still owed: 640 x 480 (compact, sidebar over the page), Memory, Files and Tools in the pane, the toolbar with the sidebar toggle beside Back, Kanban's task panel at 900, dark and German (the same list as the brief's "Not yet on the canvas").
