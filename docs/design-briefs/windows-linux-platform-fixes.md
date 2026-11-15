# Design brief: Windows and Linux desktop fixes

Audit fixes for the Windows and Linux builds: keyboard focus (F7), window size (F3), the Linux window icon (F5) and Ctrl shortcuts (F1). There is no openspec change; these are corrections to existing behaviour, and the decisions below are the spec for the fix.

## Design (done)

Claude Design canvas "Hermes: Windows and Linux desktop fixes", built on the Hermes App design system: https://claude.ai/artifact/7p2QX2TVYXLFQGSexYkuPD (private; ask its owner for access). Seven boards in three rows: the focus ring in light and dark (today beside after, for a filled, outlined and text button, an icon button, a list row and a menu item); the window at the 360 x 480 minimum, at 1280 x 720, and at the default on a 1366 x 768 laptop (1229 x 655); the Ctrl command set as a table beside the Mac keys; the optional menu bar and chord hints. The windows and the menu are plain markup drawn from design tokens (the shell is not a design system component). The canvas was not rendered locally.

Decisions taken in the design pass:

- F7 ring: 2 px solid, the theme's link colour (light #1565C0, 5.8:1 on white; dark #90CAF9, 11.4:1 on the dark page). It is blue on purpose: the primary colour is near black, so a primary ring would vanish on the filled button and look like a pressed state.
- F7 offset and radius: outside the control by 2 px, with the control's radius plus 2 (a button of 10 px gets 12). A list row and a menu item are clipped by their container, so their ring is inset by 2 px (negative offset) and follows the row's own radius.
- F7 when it shows: on keyboard focus only (Flutter's traditional highlight mode), never on a pointer press. The hover tint stays as it is, so hover and focus never look alike. A focused menu item also takes the hover fill.
- F7 targets: filled, outlined and text buttons, icon buttons, grouped list rows, menu items, tab and segment controls, text fields keep their own focus border.
- F7 on the Mac: the same ring when Full Keyboard Access moves focus; the blue sits next to the system accent and the 28 pt targets leave room for the offset. No Mac-specific colour.
- F3 minimum: 360 x 480. At that size the shell is the compact layout (drawer below `kWideLayoutBreakpoint`, 900 px, read by `isWideLayout` in `lib/src/shell/app_shell.dart`; 760 is `kMacCompactWindowWidth`, which only the Mac sidebar uses), the composer and one message fit, and the title bar controls stay usable. Nothing smaller is allowed. Both runners apply it (GTK geometry hints on Linux, `WM_GETMINMAXINFO` on Windows).
- F3 default: 1280 x 720 as today, clamped to 90 percent of the monitor's work area and never below the minimum. A 1366 x 768 laptop (work area 1366 x 728) opens at 1229 x 655, so the window never covers the taskbar or runs off the screen. The window opens centred. Today the Windows runner opens at (10, 10) (`windows/runner/main.cpp:27`), so centring is a behaviour change, not the fix of an existing rule. On Windows `WM_GETMINMAXINFO` works in physical pixels, so scale 360 x 480 by the window's DPI.
- F5: the Linux title bar shows the Flutter icon. Set the Hermes icon on the GTK window in both paths of `linux/runner/my_application.cc` (the header bar and the plain title, lines 40-52), not in only one. Not a design question and not on the canvas.
- F1 command set: the table below, which is the single table for Windows and Linux and the one the Mac brief (`macos-platform-fixes.md`) points to. The Windows and Linux chords are not the Mac chords with Cmd swapped for Ctrl: a chord that clashes with text editing gets no shortcut (Ctrl+Backspace deletes a word), Ctrl+Alt+letter is AltGr on many layouts, and Ctrl+[ and Ctrl+] need AltGr on non-US layouts.
- F1 menu bar: a visible Material `MenuBar`, off by default. A Settings switch, "Show menu bar", adds a 40 px strip (the Material `MenuBar` default height; use 40 unless a style override is stated) under the title bar with File, View, Chat and Help. Without it the chat keeps its height. The "Commands" app-bar button on the canvas is dropped: with the bar off, F1 is the way in. F1 opens a "Keyboard shortcuts" page that Settings also links to. One entry point, not two.
- F1 discoverability: every chord is in its menu item and in the tooltip of the matching button, written "New chat (Ctrl+N)". F1 opens the "Keyboard shortcuts" page, a read-only list of the table below.

Corrections after the pass: the canvas shows (a) a 32 px menu strip, now 40; (b) a "Commands" app-bar button, now dropped in favour of F1 and the Settings link; (c) Close conversation window as Ctrl+W and Open in new window as Ctrl+Alt+O, now n/a, because only macOS has conversation windows (`lib/src/windows/conversation_window_app.dart:31`; those commands are `_macOnly` in `lib/src/macos/menu_layout.dart`); (d) Back and Forward also on Ctrl+[ and Ctrl+], now Alt+Left and Alt+Right only; (e) the compact breakpoint, 900 and not 760. The canvas command table is superseded by the table below.

Corrections where this brief did not work: none.

Copy added: "Show menu bar" (Settings switch); "Keyboard shortcuts" (page title and the Settings row that opens it); tooltips with the chord in brackets ("New chat (Ctrl+N)", "Sidebar (Ctrl+B)").

## F1 command set

| Command                                       | Mac               | Windows and Linux                                                 |
| --------------------------------------------- | ----------------- | ----------------------------------------------------------------- |
| New chat                                      | Cmd+N             | Ctrl+N                                                            |
| Find in chat                                  | Cmd+F             | Ctrl+F                                                            |
| Settings                                      | Cmd+,             | Ctrl+,                                                            |
| Back                                          | Cmd+[             | Alt+Left                                                          |
| Forward                                       | Cmd+]             | Alt+Right                                                         |
| Reload the open page                          | Cmd+R             | Ctrl+R and F5                                                     |
| Show or hide the sidebar                      | Ctrl+Cmd+S        | Ctrl+B                                                            |
| Show Files                                    | Shift+Cmd+F       | Ctrl+Shift+F                                                      |
| Enclosing Folder (Files page)                 | Cmd+Up            | Alt+Up                                                            |
| Previous / Next change (checkpoint file page) | Opt+Up / Opt+Down | F8 / Shift+F8 (the existing Alt+Up/Down binding becomes Mac-only) |
| Pin the chat                                  | Shift+Cmd+P       | Ctrl+Shift+P                                                      |
| Delete the chat                               | Cmd+Backspace     | none (Ctrl+Backspace deletes a word)                              |
| Show Inspector (Kanban)                       | Opt+Cmd+I         | none                                                              |
| Open in new window                            | Opt+Cmd+O         | n/a (no secondary windows off the Mac)                            |
| Close conversation window                     | Cmd+W             | n/a                                                               |
| Help / keyboard shortcuts                     | none              | F1                                                                |

Why these: Ctrl+Alt+letter is AltGr on many layouts; Ctrl+Alt+Up/Down is workspace switching on GNOME and KDE; Ctrl+[ and Ctrl+] need AltGr on non-US layouts; Alt+Left, Alt+Right and Alt+Up are not text-editing keys on Windows and Linux; F8 and Shift+F8 are free. The checkpoint file-change page (`lib/src/chat/checkpoints/pages/file_change_page.dart:162-164`) owns Previous and Next Change; only Enclosing Folder belongs to Files (`lib/src/files/files_screen.dart:437`).

Reload, Ctrl+B, Enclosing Folder and the change navigation are new menu commands (the Mac menu has no Reload today, so add it there too, as Cmd+R; the Mac brief covers it). `lib/src/macos/menu_layout.dart` knows only `MenuPlatform { mac, ipad }` with one `shortcut` per entry, so a command must declare its Windows and Linux chord once: either add a `desktop` value to `MenuPlatform` and a second activator on the entry, or hold the Ctrl chords in a separate list keyed by the same command. Pick one in the implementing PR; either way the `ipadShortcut` gate stays, so Cmd+R and Cmd+Up do not bind on the iPad by accident. The menu bar and the F1 page read the same list, so a command is declared once.

## Build notes

- Focus: set the ring once (the exact Flutter hook is still to be chosen: a `ButtonStyle` `side` or `overlayColor`, `focusColor`, or a focus-aware decoration; there is no `FocusOutlineStyle` API) in `lib/src/theme/hermes_theme.dart` (button themes, `ListTileTheme`, `MenuItemButton` style) instead of per widget, and add a Widgetbook use case with every control focused in both themes. `popup items suppress it` today: `PopupMenuItem` draws no focus, so use `MenuItemButton` or give the item a focus decoration.
- Window: `linux/runner/my_application.cc` (`gtk_window_set_default_size(window, 1280, 720)` today) and `windows/runner/main.cpp` (`Win32Window::Point origin(10, 10)` and `Win32Window::Size size(1280, 720)`, lines 28-29).
- Tests: a widget test that tabs to each control and finds the ring; a unit test for the clamp (work area in, size out).
