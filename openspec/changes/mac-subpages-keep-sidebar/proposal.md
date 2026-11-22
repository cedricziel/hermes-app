# Proposal

Audit item C11.

## Why

On a wide Mac window the shell shows the sidebar beside the content (`MacSplitView`, `lib/src/shell/app_shell.dart:860-864`). Kanban, Schedules, Bots, Profiles and Server are shell destinations, so they sit in the content pane and the sidebar stays. Every other sub-page is pushed with `Navigator.of(context).push(MaterialPageRoute(...))` on the one root navigator (`MaterialApp` at `lib/src/app.dart:173`; the shell is its `home`). A route on the root navigator covers the whole window, sidebar included. Pushed this way, from `lib/src/chat/chat_screen_navigation.dart`: Profiles (`:274`), Messaging (`:311`), Skills (`:327`), Plugins (`:351`), MCP servers (`:361`), Tools (`:404`), Providers (`:491`), Helper models (`:510`); and Memory (`lib/src/memory/memory_destination.dart:47`) and Files (`lib/src/files/open_files.dart:67`, with `rootNavigator: true`), which also push on the root navigator. Connection details (`:520`) is pushed the same way but is about the connection, not the shell, and stays full window. Kanban's board manager and task pages and the Settings-style pages of server care push the same way (`lib/src/kanban/kanban_screen.dart:206`, `:306`).

The code already knows this: `MacToolbar.clearTrafficLights` exists "for a page that covers the whole window, such as one pushed over the sidebar" (`lib/src/macos/mac_toolbar.dart:45-47`), and `SettingsScaffold` pads for the title bar when it is not in a pane (`lib/src/widgets/settings_scaffold.dart:271-276`). The sidebar's toggle and its source list disappear on those pages, because `MacSidebarScope` sits inside `AppShell` (`app_shell.dart:749`) and a pushed route is a sibling of the shell, not a child.

What a Mac user sees: the user clicks Skills in the sidebar and the sidebar vanishes. There is no way to jump to another chat or destination without going Back first (⌘[ or the toolbar's back button). Mac apps with a sidebar (Mail, Notes, System Settings) keep it while the detail changes.

Audit premises that are only partly true: "Settings sub-page" and "chat details" are not pushed pages. Settings is a dialog stack (see `mac-settings-window`), which keeps the sidebar visible behind its scrim. A chat's details are the Activity panel, a pane inside `ChatScreen` (`_activityOpen`), not a route.

## What Changes

On macOS, sub-pages that belong to the chat shell open in the content pane, with the sidebar kept, instead of over the whole window. Mechanically (design.md, option B): a nested `Navigator` in the shell's content pane; the sidebar stays outside it. Back, ⌘[, ⌘] and the window title keep working, and the sidebar can be used while a sub-page is open: picking a chat or a destination closes the sub-page stack and shows the pick.

Routes that stay full window: Connection details and sign-in (they are about the connection, not the shell), the voice call screen, the Bot Screen viewer, media and Quick Look viewers, and every dialog, sheet and popup (`showAppDialog` and friends use the root navigator on purpose).

Windows and Linux wide layouts use the same pushes and the same Row of sidebar and content (`app_shell.dart:866-872`); the nested navigator would serve them too. This change turns it on for macOS only; enabling the others is one switch in `keepsSidebarForSubpages` after the Windows and Linux brief owner agrees. iPad and phones are out of scope.

## Non-goals

- No change to which pages exist, their contents or their toolbar actions.
- No change to the first pages of the Kanban, Schedules, Bots, Profiles and Server destinations, which already sit in the content pane. Pages pushed from them (Kanban's board manager and task pages, the server-care pages) and the Profiles page pushed from the chat do move into the pane.
- No sidebar on a compact window: below `kMacCompactWindowWidth` (760, `lib/src/macos/mac_sidebar.dart:20`) the sidebar opens over the page from the toolbar, as today.
- No change to the minimum window size (640 x 480, `kMacMainWindowMinSize`, `lib/src/theme/breakpoints.dart`), see design.md.
- No new navigation history model: ⌘[ and ⌘] keep using `DesktopNavigationHistory`.

## Security and privacy impact

`ConnectionPageCloser` removes every page on the root navigator when the connection ends (`lib/src/navigation/connection_pages.dart`, wired in `app.dart`). A nested navigator lives inside `AppShell`, which unmounts at sign-out, session expiry and server change, so its pages go with it; the change must keep the guarantee that no old-session page survives, and must keep the App Lock cover over sub-pages (`AppLockGate` wraps the navigator, `app.dart:197`). Files stays under the rules in CLAUDE.md (downloads cleared on lock and sign-out, no path in any signal). No new data, no new request.

## Observability

- Breadcrumb `nav.subpage.opened` with a fixed `kind` slug per route (`skills`, `memory`, `files`, ...) and `nav.subpage.closed_by_sidebar`: a user step that explains later state. No title, profile, path or id.
- No span, no log event: nothing crosses a boundary.

## Design pass

Needed: this changes placement. Record a "Proposed:" note in `docs/design-briefs/macos-platform-fixes.md` (added by this change). Boards to ask for: Skills, Memory, Files and Tools in the content pane beside the docked sidebar at 1100 x 760, at 760 x 480 (sidebar 280 plus 480 of content, under `kMacSplitBreakpoint`, the narrowest case) and at 640 x 480 (compact, sidebar overlay); the sidebar's selected state while a sub-page is open (the "Skills" action row selected, or none); the toolbar with the sidebar toggle and a back button together; light, dark, German.

## Open questions for the owner

1. Windows and Linux: switch the nested navigator on there in the same release, or Mac only first?
2. Should the sidebar show a selected row for the open sub-page (Skills, Memory, ...)? Today those rows are actions, not destinations. The design pass chose none: while a sub-page is open the Chat destination stays current, no chat row is selected, and Back selects the chat the user came from again. This is the owner's call; the owner may overrule it.
3. Is Files a sub-page here, or a window-wide page? It is reached from the chat header and the Activity panel too; design.md keeps it in the pane.
