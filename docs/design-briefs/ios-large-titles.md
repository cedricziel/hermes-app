# Design brief: iOS large titles

Openspec change: `openspec/changes/ios-large-titles` (audit item D5, roadmap F.230). The design pass has not run. This brief says what to decide and where; the facts and the recommendation are in that change's `design.md`.

## Proposed:

On iPhone, list and overview pages show their title at 34 pt as the first thing in the list. It scrolls away and the bar's 17 pt title fades in. Pages with tabs, details, forms, the conversation, Kanban and Files keep the small centred title.

### Who and why

People on an iPhone, who today cannot tell a list root from a pushed detail page, and people at large text sizes, whose bar titles are cut off.

### Kit to reuse

`SettingsScaffold`, `SettingsBarTitle`, `GroupedListView`, `GroupedSection`, `AdaptiveBackButton`, `SettingsSearchField`. New: `LargeTitleHeader` and its scope.

### Screens and widths for the canvas

| Screen             | Platform | Width                  | States                                                                           |
| ------------------ | -------- | ---------------------- | -------------------------------------------------------------------------------- |
| Server overview    | iPhone   | 390 pt, light and dark | at rest, half collapsed, collapsed                                               |
| Same at large text | iPhone   | 320 pt at 2.0 and 3.1  | wrapped header, collapsed bar title shrunk                                       |
| Tools              | iPhone   | 390 pt                 | at rest and collapsed, with the subtitle                                         |
| Schedules          | iPhone   | 390 pt                 | subtitle menu (profile scope) under the title; filter and new in the bar         |
| Chats list         | iPhone   | 390 pt                 | large "Chats" with the profile label, New message in the bar, `NewChatFab` below |
| Providers or Bots  | iPhone   | 390 pt                 | the search field options below                                                   |
| Skills             | iPhone   | 390 pt                 | unchanged, small title with tabs, for contrast                                   |
| Any of the above   | iPad     | 1024 pt                | unchanged, for contrast                                                          |
| Any of the above   | Android  | 412 dp                 | unchanged, for contrast                                                          |

### Decisions to take

- Where the search field sits with a large title: under the title and scrolling away (iOS), pinned in the bar, or pinned once focused or holding a query.
- Whether the bar has a hairline at rest, or only once content scrolls under it.
- The large title's size and weight (34 pt, bold proposed) and the subtitle's (15 pt, muted).
- Whether Server, which is a destination on a Mac and a row in More on a phone, shows its attention state beside the title.
- Whether iPad at regular width should follow later, and whether Android gets `SliverAppBar.large`.

### Accessibility

One heading per page at every scroll position. The header wraps at any text size, with no clamp. Reduce Motion replaces the fade with a switch. Bar buttons stay at 44 pt.

### Differences by platform

iOS compact only. Android, macOS, Windows, Linux and iPad regular width are unchanged.
