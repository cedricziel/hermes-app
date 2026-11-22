# Design brief: Windows and Linux desktop fixes

Audit fixes for the Windows and Linux builds: keyboard focus (F7), window size (F3), the Linux window icon (F5) and Ctrl shortcuts (F1). There is no openspec change; these are corrections to existing behaviour, and the decisions below are the spec for the fix.

## Design (done)

Claude Design canvas "Hermes: Windows and Linux desktop fixes", built on the Hermes App design system: https://claude.ai/artifact/7p2QX2TVYXLFQGSexYkuPD (private; ask its owner for access). Seven boards in three rows: the focus ring in light and dark (today beside after, for a filled, outlined and text button, an icon button, a list row and a menu item); the window at the 360 x 480 minimum, at 1280 x 720, and at the default on a 1366 x 768 laptop (1229 x 655); the Ctrl command set as a table beside the Mac keys; the optional menu bar and chord hints. The windows and the menu are plain markup drawn from design tokens (the shell is not a design system component). The canvas was not rendered locally.

Decisions taken in the design pass:

- F7 ring: 2 px solid, the theme's link colour (light #1565C0, 5.8:1 on white; dark #90CAF9, 11.4:1 on the dark page). It is blue on purpose: the primary colour is near black, so a primary ring would vanish on the filled button and look like a pressed state.
- F7 offset and radius: outside the control by 2 px, with the control's radius plus 2 (a button of 10 px gets 12). A list row and a menu item are clipped by their container, so their ring is inset by 2 px (negative offset) and follows the row's own radius.
- F7 when it shows: on keyboard focus only (Flutter's traditional highlight mode), never on a pointer press. The hover tint stays as it is, so hover and focus never look alike. A focused menu item also takes the hover fill.
- F7 targets: filled, outlined and text buttons, icon buttons, grouped list rows, menu items, tab and segment controls, text fields keep their own focus border.
- F7 on the Mac: the same ring when Full Keyboard Access moves focus; the blue sits next to the system accent. No Mac-specific colour. (The original line also said the 28 pt targets leave room for the offset; that does not hold for the 20 pt buttons in a Mac thread row, see the addendum.)
- F3 minimum: 360 x 480. At that size the shell is the compact layout (drawer below `kWideLayoutBreakpoint`, 900 px, read by `isWideLayout` in `lib/src/shell/app_shell.dart`; 760 is `kMacCompactWindowWidth`, which only the Mac sidebar uses), the composer and one message fit, and the title bar controls stay usable. Nothing smaller is allowed. Both runners apply it (GTK geometry hints on Linux, `WM_GETMINMAXINFO` on Windows).
- F3 default: 1280 x 720 as today, clamped to 90 percent of the monitor's work area and never below the minimum. A 1366 x 768 laptop (work area 1366 x 728) opens at 1229 x 655, so the window never covers the taskbar or runs off the screen. The window opens centred. Today the Windows runner opens at (10, 10) (`windows/runner/main.cpp:28`), so centring is a behaviour change, not the fix of an existing rule. On Windows `WM_GETMINMAXINFO` works in physical pixels, so scale 360 x 480 by the window's DPI.
- F5: the Linux title bar shows the Flutter icon. Set the Hermes icon on the GTK window in both paths of `linux/runner/my_application.cc` (the header bar and the plain title, lines 40-52), not in only one. Not a design question and not on the canvas.
- F1 command set: the table below, which is the single table for Windows and Linux and the one the Mac brief (`macos-platform-fixes.md`) points to. The Windows and Linux chords are not the Mac chords with Cmd swapped for Ctrl: a chord that clashes with text editing gets no shortcut (Ctrl+Backspace deletes a word), Ctrl+Alt+letter is AltGr on many layouts, and Ctrl+[ and Ctrl+] need AltGr on non-US layouts.
- F1 menu bar: a visible Material `MenuBar`, off by default. A Settings switch, "Show menu bar", adds a 40 px strip (the Material `MenuBar` default height; use 40 unless a style override is stated) under the title bar with File, View, Chat and Help. Without it the chat keeps its height. The "Commands" app-bar button on the canvas is dropped: with the bar off, F1 is the way in. F1 opens a "Keyboard shortcuts" page that Settings also links to. The menu bar, when on, lists the same commands; there is no separate commands button.
- F1 discoverability: every chord is in its menu item and in the tooltip of the matching button, written "New chat (Ctrl+N)". F1 opens the "Keyboard shortcuts" page, a read-only list of the table below.

Corrections after the pass: the canvas shows (a) a 32 px menu strip, now 40; (b) a "Commands" app-bar button, now dropped in favour of F1 and the Settings link; (c) Close conversation window as Ctrl+W and Open in new window as Ctrl+Alt+O, now n/a, because only macOS has conversation windows (`lib/src/windows/conversation_window_app.dart:31`; those commands are `_macOnly` in `lib/src/macos/menu_layout.dart`); (d) Back and Forward also on Ctrl+[ and Ctrl+], now Alt+Left and Alt+Right only; (e) the compact breakpoint, 900 and not 760. The canvas command table is superseded by the table below.

Corrections where this brief did not work: none beyond the corrections above.

Copy added: "Show menu bar" (Settings switch); "Keyboard shortcuts" (page title and the Settings row that opens it); tooltips with the chord in brackets ("New chat (Ctrl+N)", "Sidebar (Ctrl+B)").

### F7 addendum (recorded with the PR)

The pass above did not record these; they are checked against the real theme tokens (`hermes_theme.dart`) and recorded here, in the PR that builds the ring.

- Contrast of the ring (link colour: #1565C0 light, #90CAF9 dark) against what it sits on, WCAG 1.4.11 needs 3:1:

  | Surface | Light | Dark |
  | --- | --- | --- |
  | Page, grouped-section card and menu surface (`surface`) | 5.75 | 11.37 |
  | Selected list row (`outline`) | 4.53 | 8.51 |
  | Segmented-control track (Material pill, `surfaceContainerHighest`) | 5.23 | 8.51 |
  | iOS and Mac segment track (dark `surface`) | n/a | 11.37 |
  | Dialog surface (dark zinc900) | n/a | 10.13 |
  | Settings-row focus fill (onSurface at 0.10 over the page) | 4.69 | 9.19 |
  | Same fill over a selected row (0.12 at worst) | 3.59 | 5.91 |
  | Menu hover fill (onSurface at 0.08 over the page) | 4.91 | 9.72 |

  Every surface the ring touches is at or above 3:1. The filled button's own fill is not one of them: the ring sits 2 px outside it, so what it touches is the page (5.75 and 11.37). The ring against the fill itself would be 3.08 light and 1.68 dark, which does not matter because the 2 px gap of page separates them; the ring is never drawn on the fill.
- Pressed: a keyboard-focused button pressed with Space or Enter keeps the ring (the state is focused and pressed, and the shape resolves on focused only); the pressed overlay sits inside it. A mouse or touch press shows no ring: on a desktop Flutter's highlight mode stays traditional through a mouse click, so the ring also follows the last input (a pointer-down hides it, the next key-down shows it again).
- High contrast: the app has no high-contrast theme and does not read `MediaQuery.highContrast`. The ring is unchanged there and meets 3:1 on every surface above.
- Hover plus focus: both show. The ring is drawn on top of the hover tint (a menu item also takes the hover fill, painted under its text and the ring).
- Placement change, Mac thread row: the Archive and More buttons are 20 x 20 targets 4 pt apart (were 2). Their rings reach 4 pt out, so with 2 pt the Archive ring would cover the More button. The title gets 2 pt less width; a row without Archive (no `onArchive`) now has 4 pt of dead gap before More, where it had 2 (an older quirk: the gap is drawn either way). The buttons keep their 20 x 20 size and hit areas; the row's 28 pt height holds the ring.
- Implementation records: a list row's ring radius is the section radius minus the 2 px inset; the model popover's choice row keeps its edge outline (inset 0); not covered are the Android `SegmentedButton`, the Mac compact menu row and the iOS and Mac system segmented control. `docs/architecture/settings-screens.md` has the list.
- Addendum, checked menu items, list tiles and chips (same ring, no other visual change; no placement change was needed):

  | Control | Ring | Where |
  | --- | --- | --- |
  | Checked menu item (Material, Windows, Linux menus) | 2 px inside, radius 4, with the menu hover fill | The menu clips it, as for a plain menu item |
  | `ListTile`, `CheckboxListTile`, `SwitchListTile` | 2 px inside, radius 8 | A sheet, dialog or bordered box clips or abuts it; a tile fills its row |
  | `FilterChip`, `ChoiceChip` | 2 px outside, the chip's 8 px radius plus 2 | Not clipped: the chip row has room (the status chips scroll with 12 px of padding and 48 px of height) |

  The composer's `InputChip` has only a delete button, which keeps Material's focus fill.

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

Reload, Ctrl+B, Enclosing Folder and the change navigation are new menu commands (the Mac menu has no Reload today, so add it there too, as Cmd+R; the Mac brief covers it). `lib/src/macos/menu_layout.dart` knows only `MenuPlatform { mac, ipad }` with one `shortcut` per entry, so a command must declare its Windows and Linux chord once: either add a `desktop` value to `MenuPlatform` and a second activator on the entry, or hold the Ctrl chords in a separate list keyed by the same command. Pick one in the implementing PR; either way the `ipadShortcut` gate stays, so Cmd+Up does not bind on the iPad by accident (Reload keeps Cmd+R on the iPad, as the Mac brief says). The menu bar and the F1 page read the same list, so a command is declared once.

## Build notes

- Focus: set the ring once (the exact Flutter hook is still to be chosen: a `ButtonStyle` `side` or `overlayColor`, `focusColor`, or a focus-aware decoration; there is no `FocusOutlineStyle` API) in `lib/src/theme/hermes_theme.dart` (button themes, `ListTileTheme`, `MenuItemButton` style) instead of per widget, and add a Widgetbook use case with every control focused in both themes. Popup items suppress it today: `PopupMenuItem` draws no focus, so use `MenuItemButton` or give the item a focus decoration.
- Window: `linux/runner/my_application.cc` (`gtk_window_set_default_size(window, 1280, 720)` today) and `windows/runner/main.cpp` (`Win32Window::Point origin(10, 10)` and `Win32Window::Size size(1280, 720)`, lines 28-29).
- Tests: a widget test that tabs to each control and finds the ring; a unit test for the clamp (work area in, size out).

## Addendum: bordered row buttons at large text

The Mac "Check for Updates" button (`SkillUpdatesSection`) and the "Set up" button of `MessagingPlatformRow` (Material and Mac) overflowed a phone-width row at large text. Decision, not a canvas pass: this is a placement fix that reuses an existing pattern, so no new board.

- Where the button no longer fits beside the title, it moves to a line of its own under the text, at the start edge, with its own size and shape. This is `GroupedRow.trailingBelow`, already used by the Tools and Curator rows; nothing new is drawn.
- Where it fits, the row looks as it did: at the default text size on any width, and at large text on a wide window. `trailingActionStacks` (`lib/src/widgets/trailing_action_fit.dart`) measures the title and the button label at the current text scale, plus the button's own horizontal padding read from its `ButtonStyle` (the border adds no width), and answers. The title keeps at least a quarter of the row. The row cannot ask its trailing widget for its width before layout, which is why this is a helper and not a `GroupedRow` option.
- The button is a separate accessibility control at every text size (`separateTrailing`), so a screen reader finds "Hub skills" and "Check for Updates" as two nodes at 1x as well as at 3x. On the Mac Hub skills row this is a change at 1x: before, the static row and its button read as one node. The messaging row already had them apart, because the row itself opens the setup.
- The button is not capped and its label may wrap on its own line. Targets stay as they were: 48 dp on Material (`MaterialTapTargetSize.padded`), 28 pt on the Mac wherever the scaled label makes the button that tall (at 1x it is 22 pt, as before), and the iOS row is the whole row, which has no button.
- Labels are localized (`messagingSetUp`, `messagingSetUpMac`, `messagingSetUpValue`, `skillsCheckForUpdatesMac`); the German ones are checked beside the title at 1x.
- Catalog: `SkillUpdatesSection` (Mac, 1x, 2x, 3x) and `MessagingPlatformRow` ("Set up, text 2x/3x" on Mac and Material). Test: `test/widgets/large_text_button_rows_test.dart`.
