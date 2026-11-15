# Design brief: macOS menu and window fixes

Audit fixes C1, C5, C6, C8, C9 and the Windows and Linux note F1 (whose table is now in `windows-linux-platform-fixes.md`). They are fixes, not redesigns: each takes the smallest visual change. There is no openspec change for them (audit fixes with no new capability); behaviour changes are recorded in `docs/architecture/macos.md` by the PRs that make them.

## Design (done)

Claude Design canvas "Hermes: macOS menu and window", built on the Hermes App design system: https://claude.ai/artifact/LdX55xucj8KCrFPRTE8TVy (private; ask its owner for access). 12 artboards:

- C1 window sizes: default window light and dark (1100 x 760), minimum window (640 x 480), minimum window with the sidebar open.
- Menu bar: structure of every menu, current against proposed (1280 x 800); the German menu bar in dark; View menu before and after; Edit menu enabled and disabled.
- C9: Refresh in the toolbars; the Kanban task panel at the minimum width, current and proposed.
- F1: Windows and Linux shortcut table (superseded, see the corrections below).

The twelve artboards, in order: C1 default light, C1 default dark, C1 minimum, C1 minimum with the sidebar open; menu structure (current against proposed); German menu bar in dark; View menu before and after; Edit menu enabled and disabled; Refresh in the toolbars; Kanban task panel at the minimum, current; Kanban task panel at the minimum, proposed; F1 shortcut table.

Decisions taken in the design pass:

- C1 first-launch size: 1100 x 760 content, centred, only when no saved frame exists. 1100 is at least `kWideLayoutBreakpoint` (900), so `isWideLayout` is true, the 280 pt sidebar docks beside the chat and the chat toolbar is `wide` (search field, 1000 and up). Minimum content size: 640 x 480. 640 is under `kMacCompactWindowWidth` (760), so the window is compact: the sidebar leaves the layout and opens over the page from the toolbar button or Control-Command-S, and the toolbar folds Copy Transcript and Connection Details into a "..." menu. 640 is above `kMacSplitBreakpoint` (560), so list-and-detail pages still split, and below `kKanbanColumnsBreakpoint` (720), which matters for C9. The main window has no frame autosave today (`setFrameAutosaveName` is set only for conversation windows, `macos/Runner/MainFlutterWindow.swift:304`), so "a saved frame wins" is new work: set an autosave name on the main window (AppKit restores and clamps it), and apply the 1100 x 760 default only when AppKit finds no saved frame. The minimum content size applies either way.
- C1 saved frame, decided after the pass: the main window gets a frame autosave name, so its size and place survive Command-Q as on other Mac apps (the conversation windows already do this). The 1100 x 760 default and centring apply only when no saved frame exists. A saved frame that is off every screen is moved back onto the main screen, and one below the minimum grows to 640 x 480. PR #1132 ships the minimum and the first-launch default; the autosave and a CI step that measures both launches follow in the PR stacked on it.
- C8 and menus: no Go menu. Reload (Command-R) leads View as its own group. Enclosing Folder (Command-Up) joins Back and Forward. Previous Change (Option-Up) and Next Change (Option-Down) are their own group. All sit in View, which already carries the navigation. Enclosing Folder belongs to the Files page (`lib/src/files/files_screen.dart:437`). Previous and Next Change belong to the checkpoint file-change page (`lib/src/chat/checkpoints/pages/file_change_page.dart:162-164`, bound to Alt+Up and Alt+Down today), not to Files. Each stays dimmed where the page in front does not offer it, as Show Files is today; Reload is on whenever the page in front offers a reload. The menu command owns these chords: the local `CallbackShortcuts` that bind Cmd+R and Cmd+Up on the Mac (`files_screen.dart:437` and `:439`, and `lib/src/providers/providers_screen.dart:668` under `if (mac)`) are removed, so a chord has one handler. New `MacCommand` values: `reload`, `enclosingFolder`, `previousChange`, `nextChange`. On the iPad, Reload is offered with Cmd+R, Enclosing Folder is offered without a chord (`ipadShortcut: false`, so Cmd+Up does not bind there by accident), and Previous and Next Change are Mac only (Option-Up and Option-Down move by paragraph in iPad text).
- C6: every menu title and item label reads from the localizations, section titles included; the `menu_layout.dart` labels stay as English fallbacks. German strings are on the German board. Items macOS provides (Services, Hide, Quit, Minimize, Zoom, Full Screen) follow the system language once German is declared in `CFBundleLocalizations`.
- C5: Undo, Redo, Cut, Copy, Paste and Select All are on only while a text field has focus: Undo needs history, Redo needs an undone step, Cut and Copy need a selection, Paste needs text on the pasteboard, Select All is on for any focused field. Selected chat text in the transcript also keeps Copy on. Otherwise all six are dimmed.
- C9: the Mac has no pull-to-refresh. Schedules keeps its Refresh button; Kanban board, Active workers, Plugins tabs and Checkpoints gain a 28 pt Refresh toolbar button with the tooltip "Refresh, Command-R", and View > Reload runs the same call for the page in front. A running reload shows the busy indicator in place of the glyph. iPhone and iPad keep the pull gesture.
- C9 task panel: on a Mac, `showKanbanTask` never opens the iOS detent sheet. Below 720 pt it opens the same form-sheet dialog as above 720 pt (560 pt wide at most, 24 pt from the window edge). The board's 380 pt inspector (`kInspectorWidth`, `lib/src/widgets/inspector_layout.dart`) is unchanged where it fits. It docks only from 760 pt (`kInspectorDockedMinWidth`), so at the 640 pt minimum it does not dock: it opens as an overlay over the board's right side, 380 pt wide, leaving 260 pt of the board visible and tappable beside it. That is the current behaviour and stays; the dialog fix concerns the task panel opened from workers and links.
- F1: the Windows and Linux shortcut table lives in the Windows and Linux brief (`windows-linux-platform-fixes.md`, "F1 command set", PR #1141) and is not repeated here. Its chords are not the Mac chords with Command swapped for Control (Ctrl+Backspace deletes a word, so Delete the chat has none there). This brief owns only the Mac side and the shared menu code; `lib/src/macos/menu_layout.dart` declares or references the Windows and Linux chords, as that brief says. Focus rings on the Mac follow the focus ring decision in the same brief (F7: the same ring when Full Keyboard Access moves focus).

Corrections after the pass: the canvas board "F1: Windows and Linux shortcut table" is superseded by the table in #1141 (it lists Ctrl+W, Ctrl+Alt+Up and Down and other chords that were changed there). The C1 "saved frame wins" line is new work, not existing behaviour. Previous and Next Change are on the checkpoint file page, not Files.

Corrections where the brief did not work: none beyond the corrections above. The task panel on a narrow Mac was checked in the code: the board opens tasks in the inspector, so the detent sheet is reached from other entry points (workers, links), which is why the fix is in `showKanbanTask`.

Copy added by the design: "Reload", "Enclosing Folder", "Previous Change", "Next Change" (English), and the German menu strings on the canvas ("Neu laden", "Übergeordneter Ordner", "Vorherige Änderung", "Nächste Änderung" among them). The Refresh button's tooltip is "Refresh" with its chord, "Aktualisieren" in German; the chord is shown the way other Mac toolbar tooltips show it (for example "Refresh ⌘R").

New components needed: none. The menu pictures on the canvas are documentation markup, not app widgets.

## Who and why

People who use Hermes on a Mac as a desktop app, with a keyboard and a window they size themselves. Today the main window can be dragged to a size where the layout breaks, the menu bar is English only and offers editing commands that do nothing, and some pages cannot be reloaded because the only gesture is a touch one.

## Shared kit

`AppShell` with `compact`, `ThreadSidebar`, `ChatHeader` and `MacToolbar` / `MacToolbarButton`, `KanbanTaskPanel` (`frame="dialog"`), `showAdaptiveSheet`-style dialog on every Mac width (no bottom sheets on the Mac). Icons from `AppIcons`.

## Per item, before and after

- C1: before, no minimum and no first-launch size in the main window (conversation windows have 480 x 420). After: default 1100 x 760, minimum 640 x 480 as above.
- Menu bar C8, C6, C5: before and after on the structure, German and Edit boards.
- C9: before, pull-to-refresh only; below 720 pt a detent sheet. After: toolbar button, Command-R, dialog.
- F1: before, chords on Command only. After: the table in the Windows and Linux brief.

## Accessibility

Mac pointer targets stay at least 28 pt (Refresh is a 28 pt toolbar button). Dimmed menu items are disabled, not only grey. Refresh has an accessible label and names its chord. Status is never colour alone. Text size is honoured at every window size above the minimum.
