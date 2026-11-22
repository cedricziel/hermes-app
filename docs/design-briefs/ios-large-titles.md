# Design brief: iOS large titles

Openspec change: `openspec/changes/ios-large-titles` (audit item D5, roadmap F.230). The design pass ran (below). This brief says what to decide and where; the facts and the recommendation are in that change's `design.md`.

## Design (done)

Canvas: https://claude.ai/artifact/LDMhPqNsZKuVda2BaFUTex (private; ask its owner for access). Row 2, four artboards. Each recommendation awaits the owner's decision; the alternative is named after it.

- **Server at rest (390 pt):** 34 pt bold title and a 15 pt muted subtitle as the first thing in the list, at the grouped gutter; no bar title and no hairline at rest (confirms decision 6). Recommended: Server's attention state stays a warning line in its first group, not a mark beside the title. Alternative: a mark beside the title.
- **Server collapsed:** the header has scrolled off, the 17 pt bar title has faded in, and the hairline shows once content is under the bar; back chevron, Refresh and the bar height are unchanged.
- **Chats list at rest:** recommended: the search field sits under the large title and scrolls away with it, and, while focused or holding a query, pins under the bar once it reaches it. Alternative: pinned in the bar always, which puts the field above the title. New chat stays a bar button.
- **320 pt at text 2.0:** "Helper models" wraps over two lines with no clamp; the subtitle and rows grow with it; bar buttons stay 44 pt.
- **Not drawn, decided:** size and weight as proposed (34 pt bold, 15 pt muted). iPad at regular width and Android `SliverAppBar.large` stay out of scope; a later change can take them.

Corrections to the brief: none; the canvas followed it. Copy the design added: the Server page's section headers "Status", "Details" and "Host" and the footer "Read from the server when this page opened.", stand-ins for the page's real copy, which this change does not alter.

New components needed: `LargeTitleHeader` (plain markup on the canvas: an `h1` at 34 pt over a muted subtitle, placed as the list's first child). The bar title fade and the hairline are `SettingsScaffold` states the design system does not draw yet.

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
| Any of the above   | iPad full screen | 1024 pt                | unchanged, for contrast                                                          |
| Any of the above   | Android  | 412 dp                 | unchanged, for contrast                                                          |

### Decisions to take

- Search field: recommended under the title, scrolling with it, and pinning under the bar once it reaches it while focused or holding a query (design pass; the owner confirms).
- Hairline: only once content scrolls under the bar (design pass).
- Sizes: decided by the design pass, a 34 pt bold title and a 15 pt muted subtitle.
- Server's attention state: recommended as a warning line in its first group, not beside the title (design pass).
- iPad at regular width and Android `SliverAppBar.large`: out of scope; a later change may take them.

### Accessibility

One heading per page at every scroll position. The header wraps at any text size, with no clamp. Reduce Motion replaces the fade with a switch. Bar buttons stay at 44 pt.

### Differences by platform

iOS layouts that are not expanded only (`isWideLayout` false: iPhone, iPad Split View and Slide Over). Android, macOS, Windows, Linux and iPad regular width are unchanged.
