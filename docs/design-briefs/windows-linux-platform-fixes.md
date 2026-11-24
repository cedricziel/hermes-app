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

F.441 popup trigger (iOS `AdaptivePopupMenuButton` custom child, keyboard focus ring): canvas "Hermes: popup trigger focus ring", https://claude.ai/artifact/Y7J5DHdX6iPc9gpsADJj4S (private; ask its owner for access), 7 artboards (five iPhone callers, the iPad footer in light and dark). Separate from the F7 canvas above and the F.427 canvas in its addendum. Per caller: pill, subtitle and footer outside; value row and chip inside (the chip on a shrink-wrapped box, so the ring is the painted chip); three optional parameters on the widget. Full record: "F.441 popup trigger (design pass)" below.

Corrections: the chip was first decided against the 48 pt padded box, then against a fixed 32 pt painted chip with an inset parameter; both were wrong (the app's 16 pt label paints the chip at about 39 pt, and more at larger text), so the chip is shrink-wrapped and the ring needs no inset.

Copy added: none.

F.441 thread row actions by keyboard (the iOS thread row on an iPhone or iPad with a hardware keyboard; roadmap F.462): canvas "Hermes: thread row actions by keyboard", 9 artboards (iPad 1180 x 820: today, the menu open, the Cmd-hold overlay, then today and the menu open in dark; iPhone 390 x 844: today and the action sheet open, light and dark). The canvas could not be created in the session that ran the pass (the Artifact call was refused), so there is no link yet; the artboards were rendered locally in headless Chrome. Decision: Ctrl+Return on the focused row opens the row's actions, the same popover or sheet a long press opens, with nothing new at rest. Full record: "F.441 thread row actions by keyboard (design pass)" below.

Copy added: "Show Chat Actions" (a menu entry on iPad only; German "Chat-Aktionen anzeigen").

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
- Implementation records: a list row's ring radius is the section radius minus the 2 px inset; the model popover's choice row keeps its edge outline (inset 0). `docs/architecture/settings-screens.md` has the list of what is covered.
- Addendum, checked menu items, list tiles and chips (same ring, no other visual change; no placement change was needed):

  | Control | Ring | Where |
  | --- | --- | --- |
  | Checked menu item (Material, Windows, Linux menus) | 2 px inside, radius 4, with the menu hover fill | The menu clips it, as for a plain menu item |
  | `ListTile`, `CheckboxListTile`, `SwitchListTile` | 2 px inside, radius 8 | A sheet, dialog or bordered box clips or abuts it; a tile fills its row |
  | `FilterChip`, `ChoiceChip` | 2 px outside, the chip's 8 px radius plus 2 | Not clipped: the chip row has room (the status chips scroll with 12 px of padding and 48 px of height) |

  The composer's `InputChip` has only a delete button, which keeps Material's focus fill.
- Addendum, segmented controls, tap targets, floating buttons, disclosure tiles and Mac menus (same ring, no other visual change; no placement change was needed):

  | Control | Ring | Where |
  | --- | --- | --- |
  | Android `SegmentedButton` segment | 2 px inside the segment, radius 12 | The control crops its segments to its own outline and height (28 dp, though the button lays out 32) |
  | iOS and Mac sliding control (`CupertinoSlidingSegmentedControl`, six sites) | Round the whole control, 2 px outside the 9 pt track | The track clips its segments and the thumb marks the selection; a hardware keyboard on an iPad moves focus into it, so a ring belongs. The Mac pill control already had it per segment |
  | Model pill (`ComposerSelectorChip`) | 2 px inside, radius 18 | The pill (radius 20) clips its main area; the Retry button keeps its own button ring |
  | Weekday toggles | 2 px outside, the pill's radius plus 2 | Not clipped; the toggles are 4 pt apart, so a ring touches the next toggle's edge without covering it |
  | Bot Screen key, copy buttons (tool value, code block), voice orb, "What's the difference" link | 2 px outside | Not clipped |
  | `new_chat_fab`, scroll-to-latest, "New task" | 2 px outside the button | Not clipped; a floating button's shape is not state-aware, so a wrapper, not `FloatingActionButtonThemeData.shape` |
  | `DisclosureTile` header | 2 px inside the header row, radius 8 | The tile's `Material` clips; only the header row, never the tile with its children |
  | Mac compact menu row, Mac checked menu item, row context menu | 2 px inside, radius 4 | The row's own fill (primary) stays; the checked item has no hover fill on a Mac (the theme clears it). The context menu is a plain Material menu, so its focused item takes `Theme.hoverColor` (alpha 0.04) under the ring |

  On a filled row (the Mac menu row, whose focused fill is `colorScheme.primary`) the ring is `onPrimary`, not the link colour, which measures only 1.68:1 against that fill in dark and 3.08:1 in light. `onPrimary` is 17.72:1 in light (white on zinc900) and 16.97:1 in dark (zinc900 on zinc50).

  An outside ring follows the painted shape, not the layout box: the mini scroll-to-latest button is laid out 48 dp on Android and iOS (padded tap target) and 40 dp on macOS, Windows and Linux (shrink-wrapped), round a 40 dp painted circle, so `MiniFabFocusRing` picks the ring from the theme (a circle with its outer edge on the 48 box, or `FocusRing.outside(radius: 20)`); the extended "New task" button paints a 16 px rounded rectangle, not a stadium; the "What's the difference" link is a plain rectangle (radius 0). `test/focus_ring_geometry_test.dart` checks the drawn ring of every outside ring in this addendum, and of the buttons, chips, tiles and menu items merged earlier, on Android (padded tap targets) and on macOS and Linux (shrink-wrapped); Windows is not run, since it shares Linux's shrink-wrap default. Exceptions to "all three": the sliding controls run on iOS and macOS, the weekday toggles also on iOS, the Android segments on Android only, the Mac menu row on macOS only, and the Material menu items on Android and Linux. Skipped there: the model popover's choice row, the Mac checked menu item and the Mac row context menu items. The tool-value copy button and the link paint no fill, so their ring follows the ink (hover) area.

  iOS pull-down menu items are not given a ring: `CupertinoMenuItem` is focusable by keyboard and draws Apple's own focus fill. Hand-rolled `InkWell` list rows and tap targets are decided in the F.427 addendum below.

### F.427 addendum: focus rings on rows and tap targets

Decision only; no code in this change. Canvas (private; ask its owner for access): https://claude.ai/artifact/5jiNCpJ6Wgpn33EKrFGjAe, one section per control with today's light and dark shot, grouped by the three PRs below. The ring, rule and colour are the F7 ones: 2 px, link colour, keyboard only; inside (the row's radius minus 2, inset 2) when a container clips the control, it is full-bleed in a list, or something flush against it would be covered; outside (the control's radius plus 2) otherwise. Answers marked "owner may overrule" are line-manager defaults.

**Method.** `grep -rn "InkWell\|InkResponse\|GestureDetector" lib` gave 61 hits in 51 files at the inventory base (`828d580`), each read in context; 14 of those files contain a `FocusRing`, and the controls already inside one were dropped; a second grep for `ListTile`, `CupertinoButton`, `TextButton`, `MenuItemButton` found nothing new (`CupertinoButton`, the non-Mac `ThreadSectionHeader`, draws Apple's own focus outline). Result: 26 focusable controls with no ring, in 24 files. No item has a primary-filled face, so the ring is the link colour everywhere (no `onPrimary` case).

**Corrections to the brief.**

- `CheckpointRow` is a `GroupedRow` (already ringed); its `GestureDetector` is only the Mac secondary click. The changed-files row is a `GroupedRow` too. Neither is an item.
- `FileRow` already has a hand-rolled 2 px `primary` border on any focus (also after a click). It is an item: replace it.
- The attachment card's open tap is off on a Mac (click selects, `QuickLookTarget` opens), but the failed-download retry card passes `onTap: _load` with no Mac check (`attachment_views.dart:125`), so the `InkWell` takes focus there too: the card is focusable on every platform. The image thumbnail was a `GestureDetector`; F.441 made it focusable off the Mac (`FocusRing.outside`, see `docs/architecture/settings-screens.md`).
- Items found beyond the brief: `SidebarAction`, `MacSourceListTile`, `MacSearchHitRow`, `ToolJsonTree` rows, the sub-agent header and lines, `ActivityLine`, the working-folder row and line, the Kanban card, the effort pills, the iOS `GroupedValueRow` wrapper and the Mac pop-up value.

**Contrast of the link ring** (WCAG 1.4.11, 3:1; fills composited from the theme tokens; "with tint" adds Flutter's default `InkWell` focus tint, `onSurface` at 0.12, which stays under the ring).

| Surface                                                                   | Light       | Dark         | With tint, light | With tint, dark |
| ------------------------------------------------------------------------- | ----------- | ------------ | ---------------- | --------------- |
| Page (`surface`)                                                          | 5.75        | 11.37        | 4.48             | 8.63            |
| Sidebar background                                                        | 5.51        | 10.13        | 4.31             | 7.20            |
| Selected `SidebarRow` (`surfaceContainerHighest` at 0.7 over the sidebar) | 5.32        | 9.06         | 4.15             | 6.28            |
| Selected Mac tile (`onSurface` at 0.10 over the sidebar)                  | 4.48        | 7.64         | 3.54             | 5.30            |
| `surfaceContainerHighest` solid (activity line, working-folder row)       | 5.23        | 8.51         | 4.11             | 5.91            |
| Sub-agent card (fill 0.4) and attachment card (0.6) over the page         | 5.55 / 5.41 | 10.42 / 9.82 | n/a              | n/a             |
| Selected file row (`outline`)                                             | 4.53        | 8.51         | n/a              | n/a             |
| Restart banner (link at 0.08 over `surfaceContainerHighest`)              | 4.70        | 7.16         | 3.70             | 4.95            |
| Dialog surface (model picker pills)                                       | 5.75        | 10.13        | n/a              | n/a             |

Lowest: 3.54 (light, selected Mac tile with the tint). The Kanban selected border is `primary`, against which link is 3.08 and 1.68, so the Kanban ring keeps a 2 px gap from it.

**A. Sidebar rows (PR 1)**

| Item                                     | File:line                     | Platforms                             | Ring                      | Reason                                                                                         |
| ---------------------------------------- | ----------------------------- | ------------------------------------- | ------------------------- | ---------------------------------------------------------------------------------------------- |
| Thread and search hit row (`SidebarRow`) | `sidebar_row.dart:31`         | iPhone, iPad, Android, Windows, Linux | inside, radius 6, inset 2 | Rows touch, the list clips                                                                     |
| `SidebarAction`                          | `thread_sidebar.dart:497`     | same                                  | inside, 6, 2              | Same list                                                                                      |
| `MacSourceListTile`                      | `mac_source_list.dart:59`     | macOS                                 | inside, 4, 2              | Rows touch, the sidebar clips; serves Mac thread, destination, Profiles and recent-search rows |
| `MacSearchHitRow`                        | `mac_search_results.dart:227` | macOS                                 | inside, 4, 2              | As the tile                                                                                    |

**B. Rows of sections and lists (PR 2)**

| Item                          | File:line                     | Platforms    | Ring                                                                 | Reason                                                  |
| ----------------------------- | ----------------------------- | ------------ | -------------------------------------------------------------------- | ------------------------------------------------------- |
| `GroupedActionRow`            | `grouped_action_row.dart:225` | all          | inside, section radius minus 2 (iOS 10, Mac 8, Material 12), inset 2 | Section clips; working and done rows take no focus      |
| iOS `GroupedValueRow` wrapper | `grouped_form.dart:116`       | iPhone, iPad | inside, 10, 2                                                        | Inner `GroupedRow` has no `onTap`, so it takes no focus |
| Schedules Advanced row        | `job_form_screen.dart:342`    | all          | inside, section radius minus 2, 2                                    | Same wrapper pattern                                    |
| `FileRow`                     | `file_row.dart:226`           | all          | inside, 0, 2; replaces the primary border                            | Full-bleed list row                                     |

**C. Rows in the chat and its panels (PR 2)**

| Item                    | File:line                         | Platforms | Ring                                         | Reason                                                                     |
| ----------------------- | --------------------------------- | --------- | -------------------------------------------- | -------------------------------------------------------------------------- |
| Activity line           | `activity_line.dart:225`          | all       | inside, 0, 2                                 | Full-bleed bar                                                             |
| Agent row               | `agent_row.dart:188`              | all       | inside, 0, 2                                 | Rows touch                                                                 |
| Context row             | `context_row.dart:192`            | all       | inside, 0, 2                                 | Full-width, when openable                                                  |
| File checkpoints row    | `file_checkpoints_row.dart:148`   | all       | inside, 0, 2                                 | As above                                                                   |
| Sub-agent group header  | `subagent_card.dart:85`           | all       | inside, 8, 2 (header row only)               | The card clips; its own focus tint is nearly invisible under the card fill |
| Sub-agent line          | `subagent_card.dart:295`          | all       | inside, 0, 2                                 | Inside the clipped card                                                    |
| Tool-call JSON tree row | `tool_json_tree.dart:321`         | all       | inside, 0, 2                                 | Rows touch, scroll area clips                                              |
| Restart banner          | `server_restart_banner.dart:175`  | all       | inside, 0, 2                                 | Flush with the window edge                                                 |
| Working-folder row      | `working_directory_row.dart:256`  | all       | inside, 10, 2                                | Composer bar flush below                                                   |
| Working-folder line     | `working_directory_line.dart:176` | all       | inside, 0, 2                                 | In an app bar with no room for 4 px                                        |
| Kanban card             | `kanban_card.dart:47`             | all       | inside, inset 3 (4 selected), radius 11 (10) | Board columns clip an outside ring; the inset clears the selected border   |

**D. Tap targets nothing clips (PR 3)**

| Item                   | File:line                     | Platforms | Ring                               | Reason                                                                                  |
| ---------------------- | ----------------------------- | --------- | ---------------------------------- | --------------------------------------------------------------------------------------- |
| Tool-call group header | `tool_call_group.dart:202`    | all       | outside, radius 8                  | Hug-width                                                                               |
| Reasoning toggle       | `reasoning_block.dart:95`     | all       | outside, 8                         | Hug-width, 4 px below                                                                   |
| Attachment card        | `attachment_views.dart:394`   | all (Mac: failed-retry state) | outside, 14                        | Nothing clips it                                                                        |
| Bot Screen preview     | `bot_screen_preview.dart:242` | all       | outside, 8                         | A ring on the picture could not be held at 3:1; the top edge has no room (see answer 4) |
| Welcome card           | `welcome_view.dart:180`       | all       | outside, 14                        | Cards 10 apart inside 24 px padding                                                     |
| Effort pill            | `model_picker.dart:702`       | all       | outside; radius half the painted height on Material (a `StadiumBorder` with only a minimum height, so it grows with text size), 9 iOS, 7 Mac | Around the painted pill, not the 44/48 hit area; a fixed 20 would stop following the shape at large text |
| Mac pop-up value       | `grouped_form.dart:172`       | macOS     | outside, 6                         | 12 pt of row padding                                                                    |

**Own-focus ring.** `FocusRing` follows focus anywhere inside its child, so a thread row with its inline More button (non-iOS) or the Mac thread row with Archive and More would draw the row ring around a focused button that draws its own. PR 1 adds a mode that follows only the row's own focus node.

**Answers to the open questions** (owner may overrule).

1. File row: replace the `primary` border with the link ring, keyboard only.
2. The Mac sidebar is translucent; the solid sidebar colour is an acceptable proxy. Check on a real Mac under "Not verified on a device".
3. Kanban ring inset 3 or 4: accepted.
4. Bot Screen preview: the ring paints 4 px into the empty padding above; accepted, no layout room added.
5. The not-focusable list below is out of scope here; reported to the orchestrator for a roadmap row.
6. The new geometry cases include `TargetPlatform.windows`.

**Not focusable at all (out of scope).** These `GestureDetector` buttons take no keyboard focus, so a ring has nothing to follow: the popup menu's custom `trigger` (`adaptive_popup_menu_button.dart:395`), the Bot Screen card's Enlarge wrapper (`bot_screen_card.dart:408`), the voice hold control (`voice_recording_controls.dart:83`), the Tools switch hit area (`tools_switch.dart:97`).

**Three PRs** (independent; any order, except the guard).

1. Sidebar rows (A, 4 items): `FocusRing` plus the own-focus mode; catalog use cases for the sidebar row and the Mac thread row focused.
2. Inside rows (B and C, 15 items): `FocusRing` with the row's radius, and the grouped-row ink extracted from `GroupedRow` so `GroupedActionRow`, the iOS value wrapper and the Advanced row share it.
3. Outside tap targets (D, 7 items): `FocusRing.outside`, plus the guard `arch.inkwell-without-focus-ring`, which lands last with an empty baseline (an `InkWell(` or `InkResponse(` with a non-null `onTap` outside a `FocusRing`, `GroupedRow` or button fails; rings owned by other widgets go on the allowlist) and rewrites the "Not covered" paragraph of `docs/architecture/settings-screens.md`.

Each PR adds a catalog use case per shape (light and dark, phone and desktop width) before any screen is touched, and a geometry-test case per ring on Android, macOS, Linux and Windows, including a macOS case for the attachment retry card and a 3x text-scale case for the Material effort pill.

## F.441 popup trigger (design pass)

Decision only; no code in this change. Canvas (private; ask its owner for access): https://claude.ai/artifact/Y7J5DHdX6iPc9gpsADJj4S. Read at `origin/main` `e181b672` (file and line of every caller re-checked there; first read at `17a3ae29`). The ring and its rule are the F.427 ones above: 2 px, link colour, keyboard only; inside (the control's radius minus 2, inset 2) when a container clips the control or it is full-bleed, outside (the control's radius plus 4 for the ring's outer edge, as `FocusRing.outside` computes it) otherwise.

**Problem.** On iOS `AdaptivePopupMenuButton` builds `_pullDown` (`adaptive_popup_menu_button.dart`, the `trigger` branch near line 395) as a `Semantics` over a bare `GestureDetector`. It takes no focus, so a keyboard user (iPad, or an external keyboard on an iPhone) cannot reach five menus. F.427 listed it under "Not focusable at all". It becomes focusable (Tab, Enter and Space open the menu) and draws a ring. The icon path (`IconButton`) already rings and is not touched; Mac and Material build a `PopupMenuButton`, also untouched.

**Artboards** (7, 390 wide unless noted; each shows today and keyboard focus, light and dark):

1. Log level pill.
2. Settings subtitle menu: today, focus with no room (rejected), focus with 4 pt of room (decision).
3. Grouped value row.
4. Kanban filter chip: today, ring on the padded 48 pt box (rejected), outside the chip (rejected), inside a shrink-wrapped chip (decision).
5. Account footer, iPhone drawer.
6. Account footer, iPad, light (1180 x 820, persistent sidebar).
7. Account footer, iPad, dark.

The iPad case differs only for the footer (a persistent sidebar, so the ring is the only cue of where Tab landed); the other four sit in the same layout on iPad, only wider.

**Callers** (paths and lines checked at the base above; every one passes a custom `child`):

| Caller                               | File:line                                           | Ring                             | Control radius                                                                    | Reason                                                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------------------ | --------------------------------------------------- | -------------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Log level pill                       | `server_care/widgets/log_level_menu_button.dart:49` | outside                          | stadium (half the painted height, so it follows text size)                        | Sliver padding 16 / 8 / 16 / 8 leaves room for 4 pt                                                                                                                                                                                                                                                                                                                                             |
| Settings subtitle menu               | `widgets/settings_scaffold.dart:160`                | outside                          | 4                                                                                 | Text only, hugs its width. On iOS the trigger gets 4 pt of padding all round so the ring sits in it; without it the ring runs through the title's descender (artboard 2)                                                                                                                                                                                                                        |
| Grouped value row (`GroupedMenuRow`) | `widgets/grouped_form.dart:222`                     | inside                           | 12 (iOS section radius), ring 10, inset 2                                         | The section clips; rows touch. Same ring as `GroupedRowInk`; the inner `GroupedRow` has no `onTap`, so no second ring                                                                                                                                                                                                                                                                           |
| Kanban filter chip                   | `kanban/widgets/kanban_board_toolbar.dart:150`      | inside, on a shrink-wrapped chip | 8 (chip theme), ring 6, inset 2 from the chip, `minTapTarget: 44` for the hit box | The padded tap target lays the `Chip` out 48 pt round a chip that paints about 39 pt (more at larger text), so the caller sets `materialTapTargetSize: shrinkWrap` and the ring hugs the chip; the widget adds a 44 pt hit box outside the ring, inside the anchor. Outside needs 4 pt the first chip's left edge does not have: the horizontal scroll view clips there. See the chip paragraph |
| Account footer                       | `chat/widgets/thread_sidebar.dart:936`              | outside                          | 8 (as the sidebar rows)                                                           | The footer's own 8 pt padding takes the 4 pt; thread list above stays clear                                                                                                                                                                                                                                                                                                                     |

Not a caller of the new ring: `chat/widgets/quick_look_target.dart:200` is an `ExcludeFocus` anchor with a zero-size child and stays unfocusable (a test pins it). The Mac callers with a `child` (`mac_toolbar.dart`, `mac_profile_switcher.dart`, `mac_account_footer.dart`, and `windows/widgets/conversation_window_toolbar.dart:164`, whose child is a `MacToolbarButton`) take the Mac path and are unchanged.

**The chip is laid out bigger than it paints.** The iOS theme keeps Material's padded tap target, so Flutter lays the `Chip` out at least 48 pt high round the chip it paints. The painted chip is not a fixed size: the app's `labelLarge` is 16 pt, so with the M3 chip padding of 8 and a line height of 1.43 it paints about 39 pt, and at larger text it reaches 48 pt and the gap is 0 (read in Flutter's `chip.dart`, not measured in a running app). A ring on the 48 pt box sits off the chip (artboard 4, state 2), and any constant inset would draw through the label at large text, so no inset is used. Decision: the caller gives the chip `materialTapTargetSize: MaterialTapTargetSize.shrinkWrap`, so the trigger's box is the painted chip and the inside ring (control radius 8, ring 6, inset 2) goes directly round it at any text size. The 44 pt touch target is kept by a minimum-size hit box outside the ring and inside the menu anchor, built by the widget's iOS trigger from a new `minTapTarget` parameter (below): `GestureDetector > ConstrainedBox(min) > Center > FocusRing > child`, with the `ConstrainedBox` and `Center` built only when `minTapTarget > 0`. A `Center` under bounded loose constraints grows to fill them, which would stretch a hug-width trigger such as the settings subtitle (it sits in `Align(widthFactor: 1)`, `settings_scaffold.dart:153`) to the whole bar; building the wrapper only on request leaves the four other callers with exactly today's layout, and is clearer than `Center(widthFactor: 1, heightFactor: 1)`, which would still add a node and a constraint to every trigger. A caller-side box round the whole button was considered and rejected: it sits outside `CupertinoMenuAnchor`'s `TapRegion` group (`RawMenuAnchor.buildAnchor` wraps only the anchor child), so while the menu is open a tap on the margin closes it on pointer-down and the outer tap then reopens it; a `toggle` or `isOpen` check cannot fix that, because the menu is already closed when the tap completes. (That design would also have needed `excludeFromSemantics: true` on its outer `GestureDetector`, not an `ExcludeSemantics` widget, which would hide the chip's button node.) Putting the box inside the anchor is the simpler fix: a margin tap is then a tap on the trigger and toggles like a chip tap, the ring still hugs the chip, and `AdaptiveMenuController` stays as it is. Both the shrink-wrap and the hit box are iOS only, the `_pullDown` path: the caller sets `materialTapTargetSize` to `shrinkWrap` only when the chrome is iOS, so Android keeps its 48 dp padded chip and its `PopupMenuButton` path unchanged. The toolbar row stays 48 high on iOS, because the neighbouring `FilterChip` keeps its padded box. Outside is still rejected: the horizontal scroll view clips at the first chip's left edge (and the last chip's right edge when scrolled), so an outside ring loses its left 4 pt (state 3); 4 pt of scroll padding would fix that but changes the toolbar's layout for a ring. The neighbouring `FilterChip` already draws its own ring from the chip theme. If the nested tap proves awkward in the implementation, the next-best option is to measure the painted chip at runtime and draw the ring against it; never a constant.

**Focus goes back from the menu.** The trigger's new `FocusNode` is passed as `CupertinoMenuAnchor.childFocusNode` (a constructor parameter; `_pullDown` builds the anchor at `adaptive_popup_menu_button.dart:366` and can pass it), so the arrow keys move focus from the open menu back to the trigger; without it focus would not return to the button.

**No double tab stop.** Read at the base: none of the five children holds a focusable control. The pill, the subtitle row and the footer are `Padding`, `Row`, `Text`, icons and an avatar; the `Chip` has no `onPressed` or `onDeleted`, so it takes no focus; `GroupedValueRow._inMenu` passes `onTap: null`, so it builds no ink.

**API decision.** Three optional parameters on `AdaptivePopupMenuButton`, used only with a `child`:

- `focusRadius` (double, default 8): the control's own corner radius. The widget derives the ring from it, as `GroupedRowInk` does (inside: radius minus `kFocusRingOffset`; outside: `FocusRing.outside(radius:)`). A stadium passes a large value (999); Flutter scales an oversized radius down.
- `focusInside` (bool, default false): inside placement, for a trigger a container clips.
- `minTapTarget` (double, default 0): the least width and height of the trigger's hit box. The box is centred round the ring, outside it and inside the anchor's tap region, so the ring stays on the painted child. It exists because a caller cannot add that box itself without leaving the tap region. Only the chip passes it (`kAppleMinTapTarget`); the other four already reach 44 or sit where growing them would change their layout (the subtitle in its 44 pt bar). The four other callers get no wrapper at the default of 0. iOS trigger only.

The default (outside, 8) is the account footer's, so it needs nothing. The other four pass values explicitly: pill `focusRadius: 999`; subtitle `focusRadius: 4`; value row `focusRadius: 12, focusInside: true`; chip `focusRadius: 8, focusInside: true, minTapTarget: kAppleMinTapTarget` on a shrink-wrapped chip. Three plain parameters, no new type: a radius, a side and, for the chip, a hit-box size; none is a measurement of the painted shape. The trigger becomes a `Focus` with an activate action (Enter, Space) inside the `FocusRing`; `ExcludeFocus` above it still wins for the quick-look anchor. The subtitle's iOS padding is the caller's change (`SettingsSubtitleMenu`), not the widget's.

**Tests to carry.** A geometry case per caller on iOS with a keyboard (ring present, radius and side as above; for the chip, the ring's rect equals the painted chip's rect deflated by 2 at 1x and at 3x text, and the hit size is at least 44 at both; a margin tap while the menu is open closes it and does not reopen it, a chip tap opens it once, a margin tap while closed opens it once; Android keeps its padded chip), each of the four non-chip callers keeps its size at `minTapTarget` 0, each caller has exactly one tab stop and one button semantics node carrying its child's label, and focus returns from the open menu to the trigger with the arrow keys, Enter and Space open the menu, no ring after a pointer tap, the quick-look anchor takes no focus, and 3x text for the pill.

**Could not check.** The canvas was rendered locally in headless Chrome as HTML, not Flutter, so type, anti-aliasing and the ring's stroke are approximate; it was not looked at in the claude.ai viewer. Not checked: the chip's painted height (about 39 pt, from Flutter's `chip.dart` and the app's 16 pt label, not measured in a running app) and the nested tap of the chip's hit box; real iPad or an external keyboard on an iPhone; Tab order and the Enter and Space handling against `CupertinoMenuAnchor`; the subtitle at large text sizes (the bar is 44 pt and the padded content 42.8 pt, so it grows past that at larger sizes, and at 1x the title's `g` still grazes the ring by about 1 pt, so look at it in the catalog first and fall back to a ring inside the padded box); right-to-left; the iPad sidebar width (320) and the footer copy are assumptions. Read and fine: `ServerAttentionBadge` is a `Stack` with a positioned dot and nothing focusable. Contrast is the F.427 table (link on the sidebar and page surfaces, 4.3 to 11.4); the chip's `outline` border and the pill's outline sit under the ring and were not measured separately.
## F.441 thread row actions by keyboard (design pass)

Decision only; no code in this change. Read at `origin/main` `825d6a18`. Canvas: none published yet (see "Could not check"). The ring is the F.427 one (2 px, link colour, inside the row, keyboard only); this pass does not touch it.

**Problem, as read.** `_ThreadRowState.build` (`thread_sidebar.dart`) wraps a row with housekeeping in `SwipeableThreadRow` on iOS chrome and builds the inline More button (`ThreadActionsButton`) only when `!ios`; the row's own long press and secondary tap go to the menu only with that button. The swipeable row has its own ways in, which F.462 did not list: on a phone a long press opens a `CupertinoActionSheet` (`_showSheet`), on an iPad layout (`isWideLayout`) `TouchRowMenu` opens a `CupertinoMenuAnchor` popover at the row's trailing edge by a long press and at the pointer by a secondary click. All of those are touch or pointer. A keyboard has none: `SidebarRow` takes focus and shows the ring, Return and Space select the row, and nothing else happens. The Chat menu on iPad (`menuLayout`, `MenuPlatform.ipad`) offers Pin (⇧⌘P), Rename and Archive without a chord, and Delete with no iPad chord (`ipadShortcut: false`, ⌘⌫ moves a text caret), and all four act on the selected chat, so a chat that is not selected is out of reach. VoiceOver is not part of the gap: `SwipeableThreadRow` gives the row custom actions Rename (not for a canonical Bot Chat), Pin or Unpin, Archive or Retire, and Delete.

**Decision: option (a), with Ctrl+Return.** On a thread row that has keyboard focus (iOS chrome, with housekeeping), Ctrl+Return (⌃↩) opens the row's actions, the same menu a long press opens: the iPad popover at the row's trailing edge, level with the row, with its first item focused; the iPhone action sheet with Cancel as the default. The actions and their confirmations are `runThreadAction` as today; Delete still asks, Cancel is the default, and Delete is a red label, never a filled button. Opening the menu does not select the row or navigate. Nothing changes at rest: no button, no hint, no new tab stop. It works for any row, selected or not, and for a canonical Bot Chat (no Rename, Archive reads Retire).

**Discoverability (option (c) as part of (a), not alone).** A new Chat-menu entry, "Show Chat Actions" with ⌃↩, on iPad only (`platforms: {MenuPlatform.ipad}`, so the Mac menu bar and the Windows and Linux layout do not get it), makes the chord show in the iPad menu bar and in the list shown while ⌘ is held. It acts on the focused row, unlike its neighbours, which act on the selected chat, and it is enabled only while a thread row holds keyboard focus. `IpadMenuBridge` does not hand a disabled item's key to UIKit and drops a command while a text field is composing (`_composing()`), so with the composer focused ⌃↩ reaches the app as it would without the entry.

**Menu-layout check.** No iPad chord of `menuLayout` collides: ⌘, ⌘N ⌘R ⌘[ ⌘] ⌃⌘S ⇧⌘F ⌘F ⇧⌘P are the iPad ones (⌘⌫, ⌘↑ and ⌥↑/⌥↓ are left to the text field or the Mac), and none is Ctrl+Return. The overlay lists only commands with a chord, so the entry needs one. The Mac and desktop layouts are unchanged; the Mac has hover buttons and a right click, and its keyboard is a separate question.

**Chord, and why the others lose.**

- Ctrl+Return: on every keyboard an iPad takes; the app binds nothing to it; the composer is not focused when a row is; VoiceOver's modifier is Ctrl+Option, so plain Ctrl does not meet it. The owner may overrule.
- Cmd+Return: rejected. The composer sends on Enter with any modifier but Shift (`chat_composer.dart`, the key handler near line 164), and Cmd+Return is send in Messages and Mail, so a row would answer "send" with a menu.
- Shift+F10 and the context-menu key: rejected as the chord. The Magic Keyboard for iPad (2020 to 2022) and the Smart Keyboard have no function row and no Application key; only a PC keyboard does, and whether the iOS embedder reports it is not checked. They may follow as aliases, with no menu entry; they are not part of this decision and carry no test.
- Shift+Return and Option+Return: rejected. Shift+Return is the composer's newline, and the pair would read as the composer's keys.

**Rejected options.**

- (b) The inline More button on iPad while a keyboard is in use, or on focus only. Flutter has no signal for an attached keyboard, only the highlight mode, which flips on every touch. A button that appears on Tab moves the title's ellipsis on every step through the list, and a permanent one adds a second tab stop per row (2N stops) and puts back the control the iOS row gave up for swipe. It is a placement change for a keyboard-only gap.
- (c) alone. The overlay shows menu commands with chords; it opens nothing for a row, and Pin, Rename, Archive and Delete in it act on the selected chat.
- (d) Make Pin, Rename, Archive and Delete act on the focused row. It changes what they mean (selected or focused), reaches only Pin by chord, and puts Delete one chord from a non-selected row.
- (e) Select with Return, then use the Chat menu. Selecting navigates (the phone drawer closes), and Rename and Archive have no chord on iPad.
- (f) Arrow keys that reveal the swipe panes. It invents a key language for a swipe, and puts Delete one arrow from a row.

**Focus return after the menu closes.**

- Escape, a tap outside, a chosen item that opens nothing (Pin) and Cancel in the sheet: focus is on the row, ring shown (the keyboard has just been used). The row's `FocusNode` is given to `SidebarRow` (an optional parameter) and passed as the `CupertinoMenuAnchor`'s `childFocusNode`, as the F.441 popup trigger does.
- Rename: the dialog is a route, so on Save or Cancel focus returns to the row, which keeps its key.
- Pin or Unpin: the row moves into or out of the Pinned section. Focus follows the thread, not the index: after the frame the row is focused again and scrolled into view.
- Archive, Retire and Delete: the row leaves the list. Focus goes to the next row of the same list, else the previous one, else the first control of the sidebar; never to the composer, never to nothing. A Delete that is cancelled in the confirmation returns to the row, and nothing was deleted. If the removed row was the selected chat, the existing selection fallback runs as today.
- No ring after a pointer press, as everywhere (F7).

**VoiceOver.** The row's custom actions stay as they are and remain the way in with VoiceOver. A keyboard opening announces the menu the way the long press does (`TouchRowMenu._announce`, "Actions for ..."); the sheet carries the title. The chord is not read out; the Cmd-hold overlay is its cue. No new semantics node is added.

**Settled rules.** Rows are already 44 pt on touch (`minTapTargetOf`) and nothing is added; Delete is red text and the sheet's default is Cancel (the popover has Escape); a keyboard focus ring is not a status, and the menu items are words; fixtures use invented names (Release notes, Kanban triage, Nightly backup report, Invoice reminders); the watch is untouched; the existing confirmations are the only path to Delete and to retiring a Bot Chat.

**Build shape (for the PR, not decided here).** `SwipeableThreadRow` (or `_ThreadRowState`) binds the chord on the row with `CallbackShortcuts` and calls an `open()` on `TouchRowMenu` (the anchor's `_openAtRowEnd`) or `_showSheet`; `open()` ignores a call while the menu is open (today `_openAt` closes and reopens, which would flicker if both paths fired). The menu entry runs the same `open()` on the focused row, which the sidebar tracks. Plain-model widget first, in the catalog: a row use case with the ring and the popover open, phone and iPad, both themes, text 1x and 3x.

**Tests to carry.**

- A non-selected row with housekeeping, focused by keyboard: Ctrl+Return opens the popover at iPad width and the action sheet at phone width; `onTap` is not called and the selection is unchanged.
- Return still selects and opens nothing; the chord on a row without housekeeping does nothing; a canonical Bot Chat shows no Rename and "Retire".
- Escape closes the popover and focus is back on the row with the ring; Cancel in the sheet does the same.
- Delete from the keyboard shows the existing confirmation with Cancel as the default; `housekeeping.delete` is not called before confirming nor after Cancel; Cancel returns focus to the row.
- After Archive or Delete focus is on the next row (the previous at the end, the sidebar's first control when the list is empty); after Pin it is on the same thread in its new section.
- With the composer focused the chord does nothing; a layout test over `menuLayout`: the iPad entry has ⌃↩, the Mac and desktop layouts do not have it, and no two iPad chords are equal.
- One opening when the row binding and the menu entry both fire; the menu entry is disabled while no row is focused.
- The row keeps its custom semantics actions (four, three for a canonical Bot Chat); no extra tab stop and no extra node at rest.
- Android, Mac and desktop keep the inline More button and long press, unchanged; no ring after a pointer press.
- Catalog use cases build in both themes (`test/widgetbook_test.dart`); the new ARB key exists in `app_en.arb` and `app_de.arb`.

**Could not check.** The canvas was not created: the Artifact call that starts a design canvas was refused in the session that ran this pass, so the nine artboards exist only as local files (generated HTML on the Hermes App design system tokens, rendered in headless Chrome, all looked at; not at the claude.ai viewer). They are plain markup, not Flutter, so type and the ring's stroke are approximate. Not checked: Flutter was not run; a real iPad or an external keyboard on an iPhone; whether UIKit or the iOS embedder passes Ctrl+Return as a key event, and whether iPadOS keeps it for itself; the Application key and Shift+F10 on iOS; `CupertinoMenuAnchor` focusing its first item and honouring `childFocusNode` on return; whether `CupertinoActionSheet` takes keyboard focus (the canvas draws a ring on Rename as an assumption); whether the custom actions merge into the row's button node under VoiceOver; whether a row keeps its focus when Pin moves it between sections; whether `IpadMenuBridge` also runs on an iPhone (it starts on iOS chrome, so a held ⌘ may list the entry there too); the 262 pt popover width and the sidebar width (320) are the existing values, not measured here; contrast is the F.427 table.

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

Why these: Ctrl+Alt+letter is AltGr on many layouts; Ctrl+Alt+Up/Down is workspace switching on GNOME and KDE; Ctrl+[ and Ctrl+] need AltGr on non-US layouts; Alt+Left, Alt+Right and Alt+Up are text-editing keys in Flutter on Windows and Linux (line start, line end, document start), so while a text field has focus the field keeps them and the commands run only when none has; F8 and Shift+F8 are free. The checkpoint file-change page (`lib/src/chat/checkpoints/pages/file_change_page.dart:162-164`) owns Previous and Next Change; only Enclosing Folder belongs to Files (`lib/src/files/files_screen.dart:437`).

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
