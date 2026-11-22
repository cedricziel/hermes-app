# Design

## Context

Everything below was read in the code at the base commit of this branch.

### Breakpoints today

- `kWideLayoutBreakpoint = 900` (`lib/src/theme/breakpoints.dart:9`). `isWideLayout` (`:27`) is true from 900 dp on every platform, and from `kIpadRegularWidth = 700` (`:14`) on iOS chrome when the shortest side is at least `kIpadMinShortestSide = 600` (`:18`), so a full-screen iPad is wide in both orientations and an iPad in Split View or Slide Over is not.
- Other numbers that are not the shell's: `kMacSplitBreakpoint = 560` (`:38`), `kKanbanColumnsBreakpoint = 720` (`:42`), `kHeaderLargeTextScale = 1.3` (`lib/src/workspaces/widgets/working_directory_line.dart:14`).
- There is no medium form. About 30 call sites ask `isWideLayout` for a split or a dialog; they keep doing so.
- Window size classes in Material 3 are compact under 600, medium 600 to 839, expanded from 840. The app's 900 is its own and stays: moving it would change 30 call sites and the iPad rule. Medium here is 600 to 899.

### Shell today

- `AppShell._build` (`lib/src/shell/app_shell.dart:754-901`): destinations are `chat`, `bots`, `kanban`, `schedules` while the server offers them, and on a Mac `profiles` and `server` (`:771-778`). With one destination the shell is the chat alone.
- Wide (`:785-787`): a Mac always, else `isWideLayout(width: constraints.maxWidth)`. Non-chat pages sit in a `Row` beside `ShellSidebar` (`:866-871`, 280 pt, `lib/src/shell/shell_navigation.dart`). Chat draws its own sidebar from the same `navigation` widget.
- Narrow (`:885-897`): `Scaffold` with a `Drawer` and `ShellMenu`, which gives each page's bar a menu button (`ShellMenu.button`, used by `SettingsScaffold` at `lib/src/widgets/settings_scaffold.dart:379-385`, Kanban `kanban_screen.dart:258`, Schedules `schedules_screen.dart:252`, the chat bars).
- Pages live in an `IndexedStack` and a page is built when first opened (`_opened`, `:195`, `:878-883`), so filters and selection survive a switch. The chat is one `KeyedSubtree` on `_chatKey` (`:125`, `:757`).
- Chat on a compact iOS or Android layout is the "messenger" navigator: a full-page list, a pushed conversation, and a drawer on the list page with the destinations plus the management entries (`lib/src/chat/chat_screen_layout.dart:133`, `:360-470`). Those entries' callbacks (`_openProfiles`, `_openSkills`, `_openTools` and the rest) are private to `ChatScreen`.
- Server on a phone: account menu item `server` (`thread_sidebar.dart`, `AccountFooter`). On a Mac: a sidebar destination. Settings: the same account menu opens dialogs; there is no Settings page on a phone.
- Deep links: `parseDeepLink` yields `OpenChat`, `NewChat`, `OpenRequests`, `OpenKanban`, `OpenSchedules` (`lib/src/deep_links/deep_link_target.dart`). `_applyDeepLink` (`lib/src/shell/app_shell_deep_links.dart:55-103`) pops to the root and calls `_select` or `_showChat`. Kanban and Schedules links wait for their server check and are ignored when not offered.
- App Lock: `AppLockGate` wraps the whole navigator (`lib/src/app.dart:197`) and puts the app in an `Offstage` (`lib/src/app_lock/app_lock_gate.dart:37`), so anything the shell draws is hidden, unfocusable and out of the semantics tree while covered.
- No `NavigationBar`, `NavigationRail`, `CupertinoTabBar` or `CupertinoTabScaffold` is used anywhere in `lib/`.

## Options

### Compact (D1)

- **A. Tab bar with a More tab, the drawer retired on touch phones. (Recommended.)** One idiom per platform, the standard iOS and Android pattern, every destination one tap away. Cost: the management entries need a home, so a More page and a hand-over of the drawer's callbacks out of `ChatScreen`.
- **B. Tab bar for the destinations, drawer kept for the rest.** Smaller. Two navigation systems on a phone, and a menu button on every page that opens a second list; not an iOS idiom.
- **C. Keep the drawer.** Decline D1.

### Medium (E6)

- **A. Rail on Material chrome, list-detail Chats from 720 dp. (Recommended.)** An 80 dp rail leaves 520 dp at 600; a 280 dp list plus a 360 dp conversation needs 720 with the rail, hence 720. Below that a single pane with the rail.
- **B. Widen "wide" to 600.** Gives a 280 pt sidebar plus a 320 pt conversation at 600: too narrow, and it moves 30 call sites.
- **C. Rail on iPad too.** Rejected for now: an iPad at 700 to 899 already has the sidebar and the audit found no fault there.

## Decisions

1. **One function decides.** `ShellForm shellFormOf(BuildContext, {double? width})` in `breakpoints.dart`, returning `compact`, `medium` or `expanded` by width alone: expanded is `isWideLayout || hasMacSidebar`, medium is 600 to 899 that is not expanded, compact is below 600. A test table over width, shortest side and platform pins it, and a guard test fails when `isWideLayout` and `expanded` disagree.
2. **What each form draws depends on the platform.** Bottom bar: iOS in compact and medium (an iPhone in landscape, an iPad in Split View), Android in compact. Rail: Android, Windows and Linux in medium. Drawer: Windows and Linux in compact, where a bottom bar is not a desktop idiom. Sidebar: expanded and every Mac window.
3. **Selection stays in `AppShell._current`.** The bar, rail, sidebar and drawer are views of it. No new state, so deep links, notification taps and the share entry (`_select`, `_showChat`) work unchanged.
4. **The tab bar hides while a conversation is open** (the pushed detail in the messenger navigator) and while the keyboard is up. The composer owns the bottom edge. A page pushed on the root navigator (Skills, a task, a settings page) covers the bar, as pushed pages cover the drawer today.
5. **More is a page the shell owns, fed by a list.** `ChatScreen` already knows which entries are offered. It publishes them as a plain `List<MoreEntry>` (icon, label, optional caption or badge text, callback) through an inherited widget the shell reads, and its own drawer disappears on touch phones. The settings entries and Server come from `AccountFooter`'s menu, moved into the same list type. The page uses `SettingsScaffold` and `GroupedListView`.
6. **Which tabs.** Order: Chats, Bots, Kanban, Schedules, More. Five at most, so no overflow. When the server offers none of the middle three, the bar is Chats and More. The bar is always present on a touch phone, so the kanban rule "chat alone, no navigation bar" changes (delta below). Option for the owner: show the bar only while at least one of the middle three is offered, and keep the drawer otherwise. That keeps two models on a phone, so it is not recommended.
7. **Visual forms.** Apple: `CupertinoTabBar` visuals (translucent, 49 pt plus the safe area, a 10 pt label that scales with text, a filled icon when selected). Material compact: `NavigationBar` (80 dp, `labelBehavior: alwaysShow`). Material medium: `NavigationRail` (`labelType: all`, 80 dp, More as the last item). The widget is `ShellDestinationBar` with a model of `{icon, selectedIcon, label, badge}` items, so the shell never imports either toolkit. `CupertinoTabScaffold` is not used: it gives each tab its own navigator and would break the one root navigator that `PushedRoutes`, `ConnectionPageCloser` and the external navigation queue rely on (`docs/architecture/app-shell.md`).
8. **Medium Chats.** `ChatScreen` gets a third layout beside compact and wide: the list (`ThreadSidebar(fullPage: true)`, today's compact list) at 300 dp beside the detail, with no destination rows because the rail has them. The selected conversation, the draft and an ongoing reply survive a resize between the three forms (`messenger-navigation` already requires this between compact and wide; the key `_chatKey` keeps one `ChatScreen`).
9. **Text size.** Tab and rail labels scale with the system up to 1.3x, the clamp `AdaptiveTabBar` uses (`lib/src/widgets/adaptive_tab_bar.dart:33-35`), then shrink to fit on one line with `FittedBox` instead of an ellipsis; the bar's height grows with the label. Icons keep 44 pt (iOS) or 48 dp (Android) targets at every scale. Every item keeps a full `Semantics` label, so nothing depends on the visible text. Checked at 320 pt and 2.0 text with five items.
10. **Status is not colour alone.** The selected item has a filled icon, a bold label and `Semantics(selected: true)`. The attention mark on More is a dot with the words "needs attention" in its semantics label (`serverMarkAccountLabel`), as the account button has today.

## Per-form behaviour

|                 | Compact, iPhone                                                     | Compact, Android phone                                            | Medium, Android tablet                                          | Expanded            |
| --------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------- | ------------------- |
| Navigation      | tab bar, More                                                       | navigation bar, More                                              | rail, More                                                      | sidebar (unchanged) |
| Chats           | list, push detail, bar hides in detail                              | same                                                              | under 720 dp as phone with rail; from 720 dp list beside detail | unchanged           |
| State on switch | pages stay alive; Chats keeps list scroll, search, open chat, draft | same                                                              | same                                                            | same                |
| Back            | iOS edge swipe pops detail, then reveals the list                   | system Back pops detail; on a tab root it leaves the app as today | same                                                            | unchanged           |

## Platforms

iOS, Android, Windows and Linux (medium rail and the unchanged compact drawer). macOS and watchOS are not affected. No native change.

## Invariants touched

- **App Lock.** The bar and rail sit inside the `AppLockGate` subtree, so they are hidden and unreachable while covered (`app_lock_gate.dart:37`). The queue holds external targets while covered (`app_shell_deep_links.dart:30-34`). Nothing new shows a chat title, a count or a profile name on a tab; the only dynamic mark is the existing server attention dot.
- **Deep links.** Built with `deepLinkUri`, read with `parseDeepLink`, never by hand. Each of the five targets must select the same destination as today in every form, popping pushed routes first.
- **Auth and sign-out.** Sign-out and server change already close pages above the shell (`ConnectionPageCloser`); the bar goes with the shell. The rebuild when the owner generation moves is unchanged.
- **Hands-free strip.** It sits above the navigator (`HandsFreeStripLayer`), so it stays above the bar and rail.
- **Telemetry.** Fixed names, flags and outcomes only, as in the proposal.
- **Touch targets.** 44 pt on iOS, 48 dp on Android, at every text scale.

## Risks

| Risk                                                                                                            | Rule                      | Mitigation                                                                                                                                                                 |
| --------------------------------------------------------------------------------------------------------------- | ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A tab label or badge leaks into the app switcher or a notification                                              | privacy, App Lock         | Labels are fixed words. The Offstage cover hides the shell. A test pumps a covered shell and finds no tab semantics.                                                       |
| Moving the drawer's callbacks out of `ChatScreen` drops a gate (Tools without the route, Memory without Skills) | capability gates          | One list type, and a test per gate on More that mirrors today's drawer test.                                                                                               |
| The bar rides above the keyboard and eats the composer                                                          | usability                 | Hidden while the keyboard is open and in a conversation; widget test with `viewInsets`.                                                                                    |
| Five tabs overflow at 320 pt and 2.0 text                                                                       | large text, 44/48 targets | `FittedBox` labels, tested at 320 x 568 and scale 2.0 and 3.1.                                                                                                             |
| Android Back on a tab root now has two plausible meanings                                                       | platform behaviour        | Unchanged: Back leaves the app from any tab root, as from Chats today. Decide in the design pass whether it should return to Chats first.                                  |
| Resize between forms duplicates `ChatScreen` or loses a draft                                                   | `messenger-navigation`    | `_chatKey` stays one `GlobalKey`; a resize test for each pair of forms.                                                                                                    |
| A rail on Windows or Linux surprises desktop users at 600 to 899                                                | platform fit              | The design pass decides whether the rail is Android only. The proposal ships it for all Material chrome because the width rule is the same; narrowing it is one condition. |

## Acceptance checks

Written before the code, carried by the tasks.

- **Catalog** (first): `ShellDestinationBar` as tab bar (Apple), navigation bar (Material) and rail (Material), each with 2, 4 and 5 items, selected on each, with and without the attention mark, light and dark, 320 pt at 2.0 text, 390 pt, 600 dp, 840 dp; the More page with every entry offered and with none of the optional ones; medium Chats with a conversation selected and with none.
- **Unit:** the form table (width, shortest side, platform to form), including 599.9, 600, 699.9, 700, 719.9, 720, 899.9 and 900, an iPhone at 932 x 430, an iPad at 744 x 1133 and in Split View, an Android tablet at 800 x 1280.
- **Widget, `AppShell`:** destinations offered per server answer produce the right items on each form; selecting keeps the other pages alive; a deep link of each of the five kinds selects the right tab in each form; the tab bar hides in a conversation and with the keyboard; covered by App Lock it is not in the semantics tree; a resize from compact to medium to expanded keeps the open chat and its draft and builds one `ChatScreen`.
- **Spec scenarios:** the ones in `specs/shell-navigation/spec.md`.
- **Revert check:** each behaviour test fails when its code is reverted, as the fleet rules ask.
- **Workflow screenshots:** `test/workflows/` rerun on phone and desktop sizes; look at them after the UI change.

## Open questions for the design pass

See `docs/design-briefs/compact-and-medium-navigation.md`.
