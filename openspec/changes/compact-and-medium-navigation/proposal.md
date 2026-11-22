# Proposal

**Owner decides:** whether iPhone and Android phones get a bottom tab bar with a More tab in place of today's drawer, and whether Android and desktop windows of 600 to 899 dp get a navigation rail with a list-detail Chats page, both as one change in three PRs; and what Android Back does on the root of a destination other than Chats: select Chats first (recommended by the design pass), or leave the app as from Chats today.

Audit items D1 (roadmap F.229) and E6 (roadmap F.210).

## Why

Both audit findings are true in the code today.

- **Phones navigate by drawer.** Below the wide breakpoint the shell is a `Scaffold` with a 280 pt `Drawer` and no bottom bar (`lib/src/shell/app_shell.dart:885-897`). Kanban and Schedules are two taps away: the menu button, then the row. Chats has its own drawer that repeats the destinations and adds Profiles, Skills, Memory, Messaging, Plugins, MCP servers, Providers, Tools and Helper models (`lib/src/chat/chat_screen_layout.dart:370-440`). Server on a phone sits in the account menu (`lib/src/chat/widgets/thread_sidebar.dart`, `AccountFooter`). The kanban spec says so outright: "there is no bottom navigation bar" (`openspec/specs/kanban/spec.md:58`).
- **600 to 899 dp is a stretched phone.** `isWideLayout` is true from 900 dp everywhere, and on iOS from 700 dp for a window whose shortest side is at least 600, such as a full-screen iPad (`lib/src/theme/breakpoints.dart:9-36`). An Android tablet in portrait (about 800 dp), a foldable's inner screen, or a Windows or Linux window of 700 dp gets the phone layout: a full-page chat list, then a pushed conversation, with a drawer.

## What Changes

One rule picks the shell's form from the available width, in one function next to `isWideLayout`. Expanded follows `isWideLayout` (`lib/src/theme/breakpoints.dart:27-34`): 900 and up everywhere, and on iOS 700 and up when the window's shortest side is at least 600, which takes in a full-screen iPad and an iPad Split View pane of that size; every Mac window is expanded too.

| Form     | Width         | iPhone, iPad Split View, Android phone        | Android tablet, foldable, Windows, Linux                      | iPad full screen                                   | macOS             |
| -------- | ------------- | --------------------------------------------- | ------------------------------------------------------------- | -------------------------------------------------- | ----------------- |
| Compact  | under 600 dp  | bottom tab bar on iOS, bottom navigation bar on Android | bottom navigation bar on Android, drawer on Windows and Linux | not reachable (a full-screen iPad is at least 700) | sidebar, as today |
| Medium   | 600 to 899 dp | tab bar on iOS (an iPhone in landscape up to 899 pt, such as 852 x 393; an iPad Split View pane under 700, or one whose shortest side is under 600); navigation rail on an Android phone in landscape | navigation rail, with Chats as list and detail from 720 dp    | sidebar, as today (700 dp and up with a shortest side of 600 or more counts as wide, Split View included) | sidebar           |
| Expanded | 900 dp and up | sidebar, as today                             | sidebar, as today                                             | sidebar, as today                                  | sidebar           |

Details of the compact and medium forms:

- **Destinations.** Chats; then Bots, Kanban and Schedules only while the server offers them (the existing gates); then **More**. More is a grouped page, in the order of the design pass: **Server** first (with the attention mark and its words), then what the drawer holds today (Profiles, Skills, Memory, Messaging, Plugins, MCP servers, Providers, Tools, Helper models, each with its current gate), then one **Settings** row that pushes a Settings page with the account menu's entries (Appearance, Notifications, Dictation, Voice calls, Spotlight, App lock, Connection details, About), then Change server, then Sign out.
- **Cupertino and Material.** The Apple form is a translucent tab bar with a filled icon and a bold label for the selected tab. The Material form is a Material 3 `NavigationBar` (compact) or `NavigationRail` (medium) with labels always shown and the indicator pill. Both live behind one plain-model widget so the shell does not know which it draws.
- **Expanded from 900 everywhere.** An iPhone in landscape that is 900 pt or wider (932 x 430) is expanded and keeps today's sidebar, as `isWideLayout` already makes it.
- **The drawer goes away** on touch phones. Windows and Linux windows under 600 dp keep their drawers as they are today, with no More row: on Chats the chat's drawer (destinations, management entries and the account menu, which holds Server), on other pages the shell's drawer (destinations and the account menu), because a bottom bar is not a desktop idiom; a window with no destination beyond Chats keeps the chat alone with the chat's own drawer.
- **Chats at 720 to 899 dp** on Android, Windows and Linux shows the thread list (the existing full-page list) beside the conversation, with the rail at the left. From 600 to 719 dp it stays a pushed conversation with the rail. On iOS the medium form (an iPhone in landscape, an iPad in Split View) has no rail: Chats is the full-page list and pushed conversation with the tab bar, as on compact. The other destinations keep their own layouts: they measure their own width, which the rail narrows.
- The existing rule stays: a Mac window always has its sidebar, and a full-screen iPad keeps today's sidebar.

## Non-goals

- Changing the Mac, the expanded sidebar or an expanded iPad window. An iPad window of 700 to 899 dp with a shortest side of at least 600 keeps the sidebar it has, and this change gives it no rail; a narrower Split View or Slide Over pane gets the tab bar, as above.
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
- `memory-navigation`: "Memory entry in the chat sidebar" names the More page instead of the phone drawer.
- `mcp-servers`: "Sidebar entry" adds the More page, and closes the drawer only where one is open.
- `chat`: the block also corrects two stale statements it restates: the thinking indicator is a spinner with the elapsed time and the activity, not three dots (`lib/src/chat/widgets/thinking_indicator.dart:7`, `:55-62`), and it shows only while nothing else of the reply does. The "Responsive layout" scenario of "Rendering of messages" says that below 900 the thread rail opens as a drawer; it now names the list beside the conversation at 720 to 899 on the rail platforms, the full-page list on phones and iOS, and the drawer only on Windows and Linux under 600.
- `deep-links`: "Opening the oldest request" no longer says "open the chat drawer" on a phone. Today a non-Mac layout that is not wide already closes the chat and shows the full-page list (`chat_screen_external_openings.dart:181-184`), so the drawer branch (`:190`) is never reached there. The delta keeps that and adds the rail's list-detail Chats from 720, where the open chat stays.

Two specs mention the chat drawer and still hold unchanged: `chat` ("Opening a thread from a notification") and `notifications` ("Tapping a notification opens its chat") close the thread drawer only "when it is open". On a touch phone there is no drawer to close, and a Windows or Linux window under 600 keeps it, so both read true in every form; selecting Chat for a notification tap is what the bar does too.

## Impact

- Code: `lib/src/theme/breakpoints.dart` (the form function), `lib/src/shell/` (the bar and rail widgets, the shell's build, a More page), `lib/src/chat/chat_screen_layout.dart` and `chat_screen_navigation.dart` (the drawer's entries become a list the More page reads; the medium list-detail), `lib/src/widgets/settings_scaffold.dart` and the pages that call `ShellMenu.button` (`kanban_screen.dart:258`, `schedules_screen.dart:252`). Widgetbook use cases in `widgetbook/`. Tests in `test/app_shell_test.dart`, `test/messenger_navigation_test.dart`, `test/chat_screen_shell_menu_test.dart`.
- Backend: none. No route, no Hermes version.
- Native: none. No entitlement, manifest or Xcode change.
- Security and privacy: None. Tab and rail labels are fixed words. The only dynamic part is the server attention mark, which already exists and is covered by App Lock with the rest of the shell.
- Observability: the existing breadcrumb `nav.destination` (`lib/src/shell/app_shell_navigation.dart:52`) gains the fixed attributes `form` (`compact`, `medium`, `expanded`) and `via` (`bar`, `rail`, `drawer`, `sidebar` for a tap on that control, `link` for a deep link, notification target or share, `fallback` when a destination went away). One new breadcrumb `nav.more.opened` (no attributes). No span or log event: switching a tab does no work that takes time. Fixed names and flags only.
- Delivery: three PRs (see tasks.md).
