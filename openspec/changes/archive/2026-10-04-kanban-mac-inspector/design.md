## Context

`KanbanScreen` opens a task with `showKanbanTask`, which on Apple platforms presents `KanbanTaskPanel` as a detent sheet or a form sheet (#379). The Mac window already has the unified 52 pt toolbar area and a sidebar that can be hidden (`MacSplitView`), and #389 adds the shared `MacToolbar` and `MacToolbarButton`.

## Decisions

- **Inspector state**: `KanbanInspector`, a `ChangeNotifier` owned by `KanbanScreen`, holds the open task id and whether the panel is shown. Only "shown" is saved (`hermes.kanban.inspector_shown`), loaded once; a change before the load finishes wins, as in `MacSidebarController`. The task is not saved: the board refetches on start, and the task may be gone.
- **Layout**: `KanbanInspectorLayout` is a plain-model widget (board, shown, inspector panel). At 760 pt or more it is a `Row` with the 380 pt panel; below it a `Stack` with the panel over the board from the right, with a shadow. The overlay shows only with a task open, so a narrow window does not open on an empty panel covering the board; a docked panel without a task says how to pick one.
- **Panel reuse**: the inspector is `KanbanTaskPanel`, keyed by board and task id so another task gets a fresh controller. Archive and delete used to `Navigator.pop`; a new `onClose` callback lets the inspector clear the task instead.
- **Toolbar**: `KanbanMacToolbar` is plain-model (counts, boards, profiles, flags, callbacks). The board switcher, profile filter and More menu are `MacToolbarMenu`s, a `MacToolbarButton` that opens an `AdaptivePopupMenuButton` through its controller, so the menus keep the compact Mac rows. The search field, tenant and archived filters stay in the bar under the toolbar.
- **Shortcuts**: a `HardwareKeyboard` handler on the page, active only on macOS while the board is the visible page and its route is on top, as `MacSidebarScope` does for ⌃⌘S. When the menu bar's command registry lands, these move there.
- **Columns**: on macOS the board always shows columns (232 pt, 12 pt gaps, 16 pt padding), because the docked inspector narrows the board below the 720 pt column breakpoint in a medium window.

## Risks / Trade-offs

- [A Mac window under 720 pt now shows columns, not status chips] → columns scroll sideways, which is how a Mac board reads; chips stay on every other platform.
- [⌘N on the page may collide with a future menu-bar ⌘N for New Chat] → the menu bar stream registers New Task for ⌘N while Kanban is in front.

## Platforms

macOS only; every change is gated on `platformChromeOf(context) == PlatformChrome.macos`. No native, entitlement or Xcode change.
