# Design brief: compact and medium navigation

Openspec change: `openspec/changes/compact-and-medium-navigation` (audit items D1 and E6, roadmap F.229 and F.210). The design pass ran (below). This brief says what to decide and where; the facts and the recommendation are in that change's `design.md`.

## Design (done)

Canvas: https://claude.ai/artifact/LDMhPqNsZKuVda2BaFUTex (private; ask its owner for access). It holds 16 artboards for three changes; row 1 is this one, seven artboards. Each recommendation below awaits the owner's decision; the alternative is named after it.

- **iPhone 390, tab bar, light:** Chats, Bots, Kanban, Schedules, More; selected = filled icon, bold label and the selected state, never tint alone; each item fills its column and the 49 pt bar; the server attention dot sits on More, whose accessible name adds "server needs attention".
- **iPhone 390, dark:** the same translucent bar on the dark surface with the Apple hairline; unselected items in muted text, which passes AA.
- **Chats and More only:** recommended: the bar is always there on a phone. Alternative: keep the drawer until a middle destination exists.
- **More page:** a page, not a sheet. Server first with its warning line ("Needs attention: …", icon and words), then one Manage group in the drawer's order, then one Settings row that pushes the Settings list (recommended; alternative: the Settings entries inline as one group), then Change server and Sign out (destructive text, no filled button).
- **iPhone 320 pt at text 2.0:** labels grow to 1.3x, then the one that does not fit ("Schedules") shrinks to one line; never wrapped or hidden; the bar grows to 56 pt. Recommended addition: the iOS large content viewer on long press. Hiding labels is rejected.
- **Android 412 dp:** Material 3 navigation bar, 80 dp, pill behind the selected icon, labels always shown. Recommended: Back on a tab root returns to Chats first, then leaves (a behaviour change from today). Alternative: leave the app from any tab root, as today.
- **Android tablet 800 dp:** 80 dp rail with items at the top and More last (alternative: More pinned to the bottom); the list fixed at 280 dp (alternative: collapsible). Correction after the pass: the canvas drew 300 dp, but 80 (rail) + 300 + a 360 dp conversation needs 740; 280 keeps the 720 dp threshold; the open chat beside it. Recommended: the rail on Android, Windows and Linux alike (alternative: Android only).
- **Not drawn, decided:** an iPad Split View window at 507 pt gets the iPhone tab bar.

New components needed: `ShellDestinationBar` in three forms (Cupertino tab bar, Material navigation bar, Material rail), drawn as plain markup on the canvas; the canvas's Cupertino icon subset has no filled glyph for Bots, Kanban, Schedules or More, so the build uses the `*_fill` CupertinoIcons glyphs. The Chats list on the canvas is drawn with grouped rows as a stand-in for `ThreadSidebar(fullPage: true)`, which this change does not restyle.

## Proposed:

A bottom tab bar on iPhone and Android phones, a navigation rail on Android, Windows and Linux at 600 to 899 dp, and list-detail Chats from 720 dp. The drawer goes on touch phones. A More tab holds the management entries, Server and Settings.

### Who and why

People on an iPhone or an Android phone who open Kanban or Schedules often, and people on an Android tablet or a foldable who today see a stretched phone screen.

### Kit to reuse

`SettingsScaffold`, `GroupedListView`, `GroupedActionRow`, `SidebarAction` rows for icon and label pairing, `ThreadSidebar` (full-page list), `ServerAttentionMark` and its accessible label, `AdaptiveTabBar` for the text-scale clamp precedent. New: `ShellDestinationBar` (tab bar, navigation bar, rail forms), the More page, a medium Chats layout.

### Screens and widths for the canvas

| Screen                                     | Platform       | Width                  | Notes                                                                       |
| ------------------------------------------ | -------------- | ---------------------- | --------------------------------------------------------------------------- |
| Tab bar, five items, each selected in turn | iPhone         | 390 pt, light and dark | Chats list with bar; Kanban; Schedules; Bots; More                          |
| Tab bar with Chats and More only           | iPhone         | 390 pt                 | server offers nothing extra                                                 |
| Tab bar at large text                      | iPhone         | 320 pt at 2.0 and 3.1  | all labels whole on one line                                                |
| Conversation open                          | iPhone         | 390 pt                 | bar hidden; keyboard up                                                     |
| More page                                  | iPhone         | 390 pt                 | every entry; Server with the attention mark; Settings group; Sign out group |
| Navigation bar, five items                 | Android phone  | 412 dp, light and dark | Material 3 pill indicator, labels always shown                              |
| Navigation bar, 360 dp at 2.0 text         | Android phone  | 360 dp                 |                                                                             |
| Rail with Chats single pane                | Android tablet | 600 and 719 dp         | rail 80 dp                                                                  |
| Rail with list and detail                  | Android tablet | 720, 800 and 899 dp    | list 280 dp; empty detail; conversation open                                |
| Rail and More                              | Android tablet | 800 dp                 | More as a page beside the rail                                              |
| Unchanged, for contrast                    | iPad full screen | 744 pt and 1024 pt     | sidebar as today                                                            |
| Unchanged                                  | Windows, Linux | 500 dp and 1000 dp     | drawer, sidebar                                                             |

### Decisions to take

- Is the bar always present on a phone (Chats and More when the server offers nothing else), or only when a middle destination exists?
- More as a grouped list page, or as a sheet? (The proposal says page.)
- Where Settings entries sit inside More: one group, or Settings as a row that pushes a Settings page.
- Whether the rail is Android only or also Windows and Linux windows of 600 to 899 dp.
- Rail alignment: items at the top with More last, or More pinned at the bottom.
- Android Back on a tab root: leave the app (today), or return to Chats first.
- The medium list width (280 dp, decided: see the design pass) and whether the list may collapse.
- An iPad Split View window at 507 pt: decided by the design pass, it gets the same tab bar as an iPhone.

### Accessibility

Every item has an accessible name and a `selected` state; the selected item is a filled icon with a bold label, not colour alone. Targets are 44 pt on iOS and 48 dp on Android at every text size. The attention mark carries the words "needs attention". Labels scale to 1.3x, then fit on one line. The bar is hidden, not merely covered, while App Lock covers the app.

### Differences by platform

iOS: translucent tab bar, hides in a conversation. Android: Material 3 navigation bar and rail, indicator pill. macOS: unchanged (sidebar). Windows and Linux: rail at medium width, drawer below 600.
