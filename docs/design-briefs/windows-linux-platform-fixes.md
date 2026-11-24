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
- F3 minimum: 360 x 480. At that size the shell is the compact layout (drawer under 760 px), the composer and one message fit, and the title bar controls stay usable. Nothing smaller is allowed. Both runners apply it (GTK geometry hints on Linux, `WM_GETMINMAXINFO` on Windows).
- F3 default: 1280 x 720 as today, clamped to 90 percent of the monitor's work area and never below the minimum. A 1366 x 768 laptop (work area 1366 x 728) opens at 1229 x 655, so the window never covers the taskbar or runs off the screen. The window opens centred.
- F5: the Linux title bar shows the Flutter icon. Set the Hermes icon on the GTK window. Not a design question and not on the canvas.
- F1 command set: the Mac menu with Ctrl in place of the Command key (table below). A chord that clashes with text editing gets no shortcut: Delete the chat has none, because Ctrl+Backspace deletes a word.
- F1 menu bar: recommend a visible Material `MenuBar`, off by default. A Settings switch, "Show menu bar", adds a 32 px strip under the title bar with File, View, Chat and Help. Without it the chat keeps its height, and a "Commands" button (three dots) in the app bar opens the same list as a Material menu.
- F1 discoverability: every chord is in its menu item and in the tooltip of the matching button, written "New chat (Ctrl+N)". Help (F1) opens the same list.

Corrections where this brief did not work: none.

Copy added: "Show menu bar" (Settings switch); "Commands" (app bar button label); tooltips with the chord in brackets ("New chat (Ctrl+N)", "Sidebar (Ctrl+B)").

## F1 command set

| Command                   | Mac           | Windows and Linux                                         |
| ------------------------- | ------------- | --------------------------------------------------------- |
| New chat                  | Cmd+N         | Ctrl+N                                                    |
| Find in chat              | Cmd+F         | Ctrl+F                                                    |
| Settings                  | Cmd+,         | Ctrl+,                                                    |
| Close conversation window | Cmd+W         | Ctrl+W (the main window keeps its title bar close button) |
| Open in new window        | Opt+Cmd+O     | Ctrl+Alt+O                                                |
| Back                      | Cmd+[         | Alt+Left, Ctrl+[                                          |
| Forward                   | Cmd+]         | Alt+Right, Ctrl+]                                         |
| Reload the open page      | none today    | Ctrl+R, F5                                                |
| Show or hide the sidebar  | Ctrl+Cmd+S    | Ctrl+B                                                    |
| Show Files                | Shift+Cmd+F   | Ctrl+Shift+F                                              |
| Pin the chat              | Shift+Cmd+P   | Ctrl+Shift+P                                              |
| Delete the chat           | Cmd+Backspace | none                                                      |
| Help                      | none          | F1                                                        |

Reload and Ctrl+B are new commands (the Mac menu has no Reload, so add it there too, as Cmd+R); the other rows exist on the Mac already, so check against `lib/src/macos/menu_layout.dart`, which holds the Mac commands (`MenuEntry` with `metaActivator`), before adding the Ctrl twin. The menu bar and the app bar menu read the same list, so a command is declared once.

## Build notes

- Focus: set `focusColor` / a `FocusOutlineStyle` once in `lib/src/theme/hermes_theme.dart` (button themes, `ListTileTheme`, `MenuItemButton` style) instead of per widget, and add a Widgetbook use case with every control focused in both themes. `popup items suppress it` today: `PopupMenuItem` draws no focus, so use `MenuItemButton` or give the item a focus decoration.
- Window: `linux/runner/my_application.cc` (`gtk_window_set_default_size(window, 1280, 720)` today) and `windows/runner/main.cpp` (`Win32Window::Size size(1280, 720)`).
- Tests: a widget test that tabs to each control and finds the ring; a unit test for the clamp (work area in, size out).
