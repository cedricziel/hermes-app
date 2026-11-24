# Design brief: macOS menu and window fixes

Audit fixes C1, C5, C6, C8, C9 and the Windows and Linux note F1. They are fixes, not redesigns: each takes the smallest visual change. There is no openspec change for them (audit fixes with no new capability); behaviour changes are recorded in `docs/architecture/macos.md` by the PRs that make them.

## Design (done)

Claude Design canvas "Hermes: macOS menu and window", built on the Hermes App design system: https://claude.ai/artifact/LdX55xucj8KCrFPRTE8TVy (private; ask its owner for access). 12 artboards:

- C1 window sizes: default window light and dark (1100 x 760), minimum window (640 x 480), minimum window with the sidebar open.
- Menu bar: structure of every menu, current against proposed (1280 x 800); the German menu bar in dark; View menu before and after; Edit menu enabled and disabled.
- C9: Refresh in the toolbars; the Kanban task panel at the minimum width, current and proposed.
- F1: Windows and Linux shortcut table.

Decisions taken in the design pass:

- C1 first-launch size: 1100 x 760 content, centred, only when no saved frame exists. 1100 is at least `kWideLayoutBreakpoint` (900), so `isWideLayout` is true, the 280 pt sidebar docks beside the chat and the chat toolbar is `wide` (search field, 1000 and up). Minimum content size: 640 x 480. 640 is under `kMacCompactWindowWidth` (760), so the window is compact: the sidebar leaves the layout and opens over the page from the toolbar button or Control-Command-S, and the toolbar folds Copy Transcript and Connection Details into a "..." menu. 640 is above `kMacSplitBreakpoint` (560), so list-and-detail pages still split, and below `kKanbanColumnsBreakpoint` (720), which matters for C9. A saved frame (frame autosave) wins over the default, clamped to the minimum.
- C8 and menus: no Go menu. Reload (Command-R) leads View as its own group. Enclosing Folder (Command-Up) joins Back and Forward. Previous Change (Option-Up) and Next Change (Option-Down) are their own group. All sit in View, which already carries the navigation. Enclosing Folder, Previous Change and Next Change are offered by the Files page and stay dimmed elsewhere, as Show Files is today; Reload is on whenever the page in front offers a reload.
- C6: every menu title and item label reads from the localizations, section titles included; the `menu_layout.dart` labels stay as English fallbacks. German strings are on the German board. Items macOS provides (Services, Hide, Quit, Minimize, Zoom, Full Screen) follow the system language once German is declared in `CFBundleLocalizations`.
- C5: Undo, Redo, Cut, Copy, Paste and Select All are on only while a text field has focus: Undo needs history, Redo needs an undone step, Cut and Copy need a selection, Paste needs text on the pasteboard, Select All is on for any focused field. Selected chat text in the transcript also keeps Copy on. Otherwise all six are dimmed.
- C9: the Mac has no pull-to-refresh. Schedules keeps its Refresh button; Kanban board, Active workers, Plugins tabs and Checkpoints gain a 28 pt Refresh toolbar button with the tooltip "Refresh, Command-R", and View > Reload runs the same call for the page in front. A running reload shows the busy indicator in place of the glyph. iPhone and iPad keep the pull gesture.
- C9 task panel: on a Mac, `showKanbanTask` never opens the iOS detent sheet. Below 720 pt it opens the same form-sheet dialog as above 720 pt (560 pt wide at most, 24 pt from the window edge). The board's 380 pt inspector is unchanged where it fits.
- F1: recommended default is no visible menu bar on Windows and Linux. The same chords are bound on Ctrl (Ctrl+N, Ctrl+F, Ctrl+, , Ctrl+W, Ctrl+R and F5, Alt+Left and Alt+Right, Alt+Up, Ctrl+Alt+Up and Down, Ctrl+Shift+F, Ctrl+Shift+P) from `menu_layout.dart`. Tooltips name the chord and Settings lists them. A Material `MenuBar` costs 40 pt and repeats the toolbar. Focus rings and window size on Windows and Linux are another pass.

Corrections where the brief did not work: none. The task panel on a narrow Mac was checked in the code: the board opens tasks in the inspector, so the detent sheet is reached from other entry points (workers, links), which is why the fix is in `showKanbanTask`.

Copy added by the design: "Reload", "Enclosing Folder", "Previous Change", "Next Change" (English), and the German menu strings on the canvas ("Neu laden", "Übergeordneter Ordner", "Vorherige Änderung", "Nächste Änderung" among them).

New components needed: none. The menu pictures on the canvas are documentation markup, not app widgets.

## Who and why

People who use Hermes on a Mac as a desktop app, with a keyboard and a window they size themselves. Today the main window can be dragged to a size where the layout breaks, the menu bar is English only and offers editing commands that do nothing, and some pages cannot be reloaded because the only gesture is a touch one.

## Shared kit

`AppShell` with `compact`, `ThreadSidebar`, `ChatHeader` and `MacToolbar` / `MacToolbarButton`, `KanbanTaskPanel` (`frame="dialog"`), `showAdaptiveSheet`-style dialog on every Mac width (no bottom sheets on the Mac). Icons from `AppIcons`.

## Per item, before and after

- C1: before, no minimum and no first-launch size in the main window (conversation windows have 480 x 420). After: default 1100 x 760, minimum 640 x 480 as above.
- Menu bar C8, C6, C5: before and after on the structure, German and Edit boards.
- C9: before, pull-to-refresh only; below 720 pt a detent sheet. After: toolbar button, Command-R, dialog.
- F1: before, chords on Command only. After: Ctrl table.

## Accessibility

Mac pointer targets stay at least 28 pt (Refresh is a 28 pt toolbar button). Dimmed menu items are disabled, not only grey. Refresh has an accessible label and names its chord. Status is never colour alone. Text size is honoured at every window size above the minimum.
