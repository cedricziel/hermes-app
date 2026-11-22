# Proposal

**Owner decides:** whether iPhone and Android phones get a bottom tab bar with a More tab in place of today's drawer, and whether Android and desktop windows of 600 to 899 dp get a navigation rail with a list-detail Chats page, both as one change in three PRs.

Audit items D1 (roadmap F.229) and E6 (roadmap F.210).

## Why

Both audit findings are true in the code today.

- **Phones navigate by drawer.** Below the wide breakpoint the shell is a `Scaffold` with a 280 pt `Drawer` and no bottom bar (`lib/src/shell/app_shell.dart:885-897`). Kanban and Schedules are two taps away: the menu button, then the row. Chats has its own drawer that repeats the destinations and adds Profiles, Skills, Memory, Messaging, Plugins, MCP servers, Providers, Tools and Helper models (`lib/src/chat/chat_screen_layout.dart:370-440`). Server on a phone sits in the account menu (`lib/src/chat/widgets/thread_sidebar.dart`, `AccountFooter`). The kanban spec says so outright: "there is no bottom navigation bar" (`openspec/specs/kanban/spec.md:58`).
- **600 to 899 dp is a stretched phone.** `isWideLayout` is true from 900 dp everywhere, and from 700 dp only for a full-screen iPad (`lib/src/theme/breakpoints.dart:9-36`). An Android tablet in portrait (about 800 dp), a foldable's inner screen, or a Windows or Linux window of 700 dp gets the phone layout: a full-page chat list, then a pushed conversation, with a drawer.

## What Changes

One rule picks the shell's form from the available width, in one function next to `isWideLayout`:

| Form     | Width         | iPhone, iPad Split View, Android phone        | Android tablet, foldable, Windows, Linux                      | iPad full screen                                   | macOS             |
| -------- | ------------- | --------------------------------------------- | ------------------------------------------------------------- | -------------------------------------------------- | ----------------- |
| Compact  | under 600 dp  | bottom tab bar                                | bottom navigation bar on Android, drawer on Windows and Linux | not reachable (a full-screen iPad is at least 700) | sidebar, as today |
| Medium   | 600 to 899 dp | tab bar (an iPhone in landscape is under 700) | navigation rail, with Chats as list and detail from 720 dp    | sidebar, as today (700 dp and up counts as wide)   | sidebar           |
| Expanded | 900 dp and up | sidebar, as today                             | sidebar, as today                                             | sidebar, as today                                  | sidebar           |

Details of the compact and medium forms:

- **Destinations.** Chats; then Bots, Kanban and Schedules only while the server offers them (the existing gates); then **More**. More is a grouped page that holds what the drawer holds today: Profiles, Skills, Memory, Messaging, Plugins, MCP servers, Providers, Tools, Helper models (each with its current gate), **Server** (with the attention mark) and **Settings** (the account menu's entries: Appearance, Notifications, Dictation, Voice calls, Spotlight, App lock, Connection details, About, then Sign out and Change server).
- **Cupertino and Material.** The Apple form is a translucent tab bar with a filled icon and a bold label for the selected tab. The Material form is a Material 3 `NavigationBar` (compact) or `NavigationRail` (medium) with labels always shown and the indicator pill. Both live behind one plain-model widget so the shell does not know which it draws.
- **The drawer goes away** on touch phones. Windows and Linux windows under 600 dp keep it, because a bottom bar is not a desktop idiom.
- **Chats at 720 to 899 dp** shows the thread list (the existing full-page list) beside the conversation, with the rail at the left. From 600 to 719 dp it stays a pushed conversation with the rail. The other destinations keep their own layouts: they measure their own width, which the rail narrows.
- The existing rule stays: a Mac window always has its sidebar, and a full-screen iPad keeps today's sidebar.

## Non-goals

- Changing the Mac, the expanded sidebar or the iPad layout. An iPad at 700 to 899 dp keeps the sidebar it has; this change gives it no rail.
- A rail on iOS, or a tab bar on desktop.
- New deep links or a Settings deep link. `hermes://` stays as in `docs/architecture/deep-links.md`.
- Badges for unread chats or open requests on the Chats tab. Only the server attention mark moves, to More.
- Re-tap to scroll to top or to pop to root. The first version does nothing on a re-tap.
- List-detail for Schedules, Server, Providers and the other split screens below 900 dp.
- Per-tab navigators (`CupertinoTabScaffold`). The shell keeps one root navigator.

## Capabilities

### New Capabilities

- `shell-navigation`: the three forms and where each applies, the destination set and its gates, the More page, state kept across switches and resizes, deep link and notification targets, App Lock, text size and accessibility.

### Modified Capabilities

- `kanban`: the requirement "Chat and Kanban navigation adapts to screen width" no longer says there is no bottom bar.
- `messenger-navigation`: "Chats is the compact home" reaches other destinations through the tab bar, rail or More instead of a menu.

## Impact

- Code: `lib/src/theme/breakpoints.dart` (the form function), `lib/src/shell/` (the bar and rail widgets, the shell's build, a More page), `lib/src/chat/chat_screen_layout.dart` and `chat_screen_navigation.dart` (the drawer's entries become a list the More page reads; the medium list-detail), `lib/src/widgets/settings_scaffold.dart` and the pages that call `ShellMenu.button` (`kanban_screen.dart:258`, `schedules_screen.dart:252`). Widgetbook use cases in `widgetbook/`. Tests in `test/app_shell_test.dart`, `test/messenger_navigation_test.dart`, `test/chat_screen_shell_menu_test.dart`.
- Backend: none. No route, no Hermes version.
- Native: none. No entitlement, manifest or Xcode change.
- Security and privacy: None. Tab and rail labels are fixed words. The only dynamic part is the server attention mark, which already exists and is covered by App Lock with the rest of the shell.
- Observability: the existing breadcrumb `nav.destination` (`lib/src/shell/app_shell_navigation.dart:52`) gains the fixed attributes `form` (`compact`, `medium`, `expanded`) and `via` (`bar`, `rail`, `drawer`, `sidebar`, `more`). One new breadcrumb `nav.more.opened` (no attributes). No span or log event: switching a tab does no work that takes time. Fixed names and flags only.
- Delivery: three PRs (see tasks.md).
