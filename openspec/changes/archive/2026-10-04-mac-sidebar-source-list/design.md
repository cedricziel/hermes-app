## Context

`ThreadSidebar` renders the threads for every platform; `ShellNavigation` the destinations. `MacSidebarController` already persists the sidebar's width and collapsed state in shared preferences. `AdaptivePopupMenuButton` (#383) is the one menu the app uses, with a compact macOS variant.

## Decisions

- **Sections** are computed by a pure `groupThreads(threads, now)` from the thread's last activity, by calendar day; pinned threads go to Pinned whatever their age. The sidebar's own order (drafts, pinned, recency) is kept inside each section.
- **Folded sections** live in `MacSidebarController` (key `hermes.mac_sidebar_folded_sections`), next to the width it already keeps, so they outlast a relaunch and are shared by the chat sidebar and the other pages' sidebars. Without a scope (the catalog) the list keeps them itself.
- **Menu**: `AdaptivePopupMenuButton` gains `AdaptiveMenuItem` (shortcut, destructive) and `open(at:)`, rather than a second menu system. On macOS each row is a 22 pt `MacMenuRow` that paints its own primary-colour highlight; iOS maps destructive items to Cupertino's destructive style; Material ignores shortcuts.
- **Copy Transcript** asks `ThreadHousekeeping.history`, which `ChatController` backs: loaded messages plus older pages for a loaded thread, every page for an unloaded one. The open thread is not fetched again.
- **Open in New Window** is a nullable callback; the item is left out without it.

## Risks / Trade-offs

- [Hover-only buttons keep their room] → the title ellipsises 44 pt earlier; the row does not jump when the pointer enters.
- [Copying a long unloaded chat reads every page] → only on request, one page after another, as loading older messages does.

## Platforms

Dart only; macOS chrome is gated on `platformChromeOf(context) == PlatformChrome.macos`. The transcript format change applies everywhere.
