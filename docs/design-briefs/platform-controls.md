# Design brief: platform controls

Small decisions about how a shared control is sized on each platform. There is no openspec change for them; behaviour is recorded in the architecture file named in each entry.

## Mac button height

Decision: Mac push buttons are 28 pt tall (the AppKit regular control height and our macOS minimum target). The theme minimum allows for the compact density, so they render 28.

Why: the Mac theme already asked for 28 (`_kMacButtonHeight`, set as `minimumSize`), but ThemeData's desktop default density is compact (-2, -2), which takes 8 off a button's minimum size. A plain FilledButton, FilledButton.tonal, OutlinedButton or TextButton therefore measured 20 pt. A 20 pt button is under the Mac minimum target of 28 and looked small beside 28 pt toolbar buttons and the 48 pt text fields of forms. Buttons that carry their own style were already larger: `toolsButtonStyle` (standard density, so `SoulSaveActions` was 28), `AppBanner` actions (constrained to 28) and buttons with their own `minimumSize` kept their size, so only the plain ones were off.

Fix: `_kMacButtonMinHeightBeforeDensity` (28 + 8) is the Mac theme's `minimumSize` height, so the compact density takes it back to 28. Density and padding are not touched.

Measured, not assumed: a survey pumped every Widgetbook use case under the macOS light theme at 1280 x 800 (skipping the iPhone and Material ones) and measured each Text, Filled, Outlined and Elevated button with `origin/main`'s theme and with this one. Of 1,675 buttons, 1,054 are unchanged, 620 went from 20 to 28 in height with the same width, and one went from 26 to 28 (a Needs You dock button at 1.3x text, whose own height was above 20 and below 28). No width changed. The tables are `survey2-before.tsv` and `survey2-after.tsv`.

Alternatives considered:

- Keep 20 pt, like a small AppKit control. Rejected: 20 pt is the height of a mini or small control, not of a push button, and it misses the 28 pt target the rest of the app uses.
- Set `VisualDensity.standard` in the Mac button themes, with a 4 pt vertical padding on the Mac TextButton (tried, and rejected). A theme's density and padding apply to every button that sets only part of its own style: it indented a stacked `AppBanner` action by 12 pt (the banner merges the theme's style under its own), took buttons that set only `minimumSize: Size(0, 44)` from 36 to 44, took `toolsButtonStyle` TextButtons from 36 to 28, lost the scaled padding at large text and made `TextButton.icon` 4 pt narrower. Raising only the theme's `minimumSize` has none of these effects, because a button's own style replaces it.

`test/theme/mac_button_height_test.dart` asserts the 28 pt height and one case for each leak above.

Renders: macOS theme, 1280 x 800, light and dark, before and after (a row of every button type, a confirm dialog, the server update card, the gateway card and the German stacked banner). They are in the pull request, not in the repository.

## Design (done)

Claude Design canvas "Hermes: Mac button height" (private; ask the owner for access): https://claude.ai/artifact/LkzdBEQjLvdjXPWMf36iyQ
Date: 2026-11-21. Seven artboard files on the Hermes App design system, Mac (`platform="apple"`, `type-ramp="default"`), light and dark.

Artboards:

- Row 1 (`Main`, `DialogRow`): a Mac toolbar with a 28 pt Create beside a 26 pt search field and the 28 pt toolbar buttons; a dialog button row (Cancel outlined, one filled Save, 8 pt apart).
- Row 2 (`SettingsRow`, `DenseList`): a settings row (`GroupedRow device="mac"`, 40 pt) with a trailing 28 pt button; a 44 pt dense list row with an inline button.
- Row 3 (`FieldSegmented`): a 28 pt button, a 28 pt text field and a compact segmented control (28 pt in total) on one line.
- Row 4: the same five contexts at 20 pt and at 28 pt, side by side (light): `Compare`, which imports the shared `ButtonSet` board once per height.

Decisions:

- A Mac push button is 28 pt tall in every context shown. Width, 24 pt padding, 14 px label and 10 pt radius do not change.
- The toolbar stays 52 pt; a 28 pt Create sits level with the 28 pt toolbar buttons.
- A 40 pt Mac settings row holds a 28 pt button with 6 pt above and below, so the row does not grow.
- A dense row stays 44 pt with a 28 pt inline button centred on the title and meta lines.
- Dialog buttons are Cancel (outlined) and one filled primary, both 28 pt.

Accepted differences from the Flutter build:

- The label stays 14 px (AppKit uses 13 pt); this change is height only.
- The radius stays 10 pt (AppKit push buttons use about 6 pt); the app uses 10 everywhere. A separate follow-up if wanted.
- The Mac confirm dialog stays the Cupertino alert with split cells; those are not push buttons and do not change.
- Full-width stacked buttons that carry their own `minimumSize` (the update card at 36 pt) are unchanged.

Open (follow-ups, not part of this change):

- Form fields on Mac are 48 pt, so a 28 pt button beside one is centred on it. A Mac-compact 28 pt field is needed.
- On a Mac the Material `SegmentedButton` measures 32 pt (`test/theme/mac_button_height_test.dart`), 4 pt above the 28 pt line; the `CupertinoSlidingSegmentedControl` used in Mac toolbars is not measured yet.
- The design system's Mac `SettingsScaffold` `formAction` is a roughly 22 pt button with a 6 pt radius; it should become the 28 pt button.

Rendered locally with headless Chrome; not checked in the claude.ai viewer or on a device.

## Search fields at large text

The shared search fields clipped their placeholder and text at large text (iOS above about 1.4x, Material above about 1.8x, Mac above 1.3x), because their height was fixed.

Decisions:

- Phone (`SettingsSearchField` on iOS and Material): the height is a minimum that grows with the text scaler, `max(36 or 44, scaled line height + 8)`, from one function (`SettingsSearchField.heightFor`) that `SettingsScaffold`'s bar bottom also uses, so the bar grows with the field. At 1.0x the heights stay 36 and 44. The filter and clear buttons keep their platform size.
- Mac (`MacToolbarSearchField`, also what `SettingsSearchField` shows on macOS): the field stays a 26 pt toolbar control and its text scaling is clamped at 1.3x, and the line height shrinks only when a scaled line would not fit the border (below 1.5 from about 1.13x), so at 1.0x the field, caret and selection are as before.

Reason: a Mac toolbar control does not grow with the text size (AppKit toolbars stay at their set height); a phone search field has room to grow and the bar below the title can follow it.

Alternative considered: growing the Mac toolbar with the text. Rejected, because every toolbar button, the 52 pt toolbar and the window chrome would have to grow with it for one field.

Checked by `test/widgets/search_field_large_text_test.dart` and the catalog use cases `SettingsSearchField / Largest text`.

### Design (done)

Canvas: https://claude.ai/artifact/HPwY5Tj74AMWYYUYLrzeyH (private, ask its owner for access), 2026-11-21. Five artboards: iOS light and dark, Android light and dark (phone settings header with search at text scale 1.0 / 2.0 / 3.1, short hint "Search skills" and long hint "Search the skills hub" with the filter button), and the Mac toolbar (1.0x and the 1.3x clamp, light and dark). Text scale is simulated by scaling font sizes (the design system has no textScale prop).

Decisions:
- iOS and Android: the field's minimum height is max(36 or 44, scaled font x 1.5 + 8): iOS 36 / 59 / 87 pt and Android 44 / 56 / 82.4 dp at 1.0 / 2.0 / 3.1. The bar below the title grows with it (toolbar + field + 8). At 1.0x nothing changes.
- The hint stays on one line and ends in an ellipsis; it never wraps.
- Search, clear and filter icons keep their platform size.
- Mac: the field stays 26 pt in the 52 pt toolbar; text scale is clamped at 1.3x; the line height shrinks only when a scaled line would not fit the border.

Accepted differences from the Flutter renders: ellipsis position (Flutter breaks at a word, Chrome at a character); icons do not scale with text; the Flutter Mac field is wider than the design system's 180 / 240 pt field; the canvas stretches the filter button to the field's height, while Flutter keeps it at its platform size (36 / 44) centred in the taller field, which keeps its tap target and icon unchanged (tested in `search_field_large_text_test.dart` and shown in the "Largest text" use case).

## Android switch off state

### Design (done)

- Canvas: https://claude.ai/artifact/X2xtELLCTgUqYCbN9L9b5S (private; ask the owner for access)
- Date: 2026-11-21
- Boards (6, Android 412 wide, light and dark): switch states in a grouped section; Memory settings with mixed switches; before and after.

Decisions:

- Scope: Material switch (Android, Windows, Linux).
- OFF outline is zinc500 (#71717A) in light and dark.
- OFF thumb is zinc400 (#A1A1AA) in dark and zinc500 in light.
- The track, the ON state and the disabled states are unchanged.
- Contrast (WCAG 1.4.11, 3:1): outline against the page 4.12:1 dark and 4.83:1 light; thumb against the track 5.81:1 dark and 4.40:1 light. Before: 1.34:1 dark and 1.27:1 light, with the thumb at 1.00:1 (dark) and 1.16:1 (light) on the track.
- Disabled switches are exempt from 1.4.11 and keep their dimmed look.

Accepted differences (canvas against Flutter):

- The design system's Switch component still draws the old OFF look; the canvas overrides it with token CSS on a wrapper. The design system needs the same change.
- The design system draws a darker ring on the disabled ON switch (translucent border over translucent fill); Flutter draws a flat track. Disabled is unchanged and exempt.
- Row height differs (subtitles in the canvas); the Flutter renders use the Ahem test font.

Open owner decision:

- iOS and macOS are unchanged. Their OFF colour is still undecided, because the same contrast question applies there (OFF track against the row: 1.43:1 dark, 1.20:1 light). The theme test holds them at those values so they cannot get worse.

## Mac dialog presentation

### Design (done)

- Canvas: https://claude.ai/artifact/N5cvQWnP2mbH7R5gUW1pwQ (private; ask the owner for access)
- Date: 2026-11-21
- Boards (6, Mac 1280 x 800, light and dark): the thread rename dialog over a chat window before (Cupertino barrier) and after (theme barrier), light and dark; the Kanban Priority choice dialog over the inspector after, light and dark.

Scope: macOS only. Nine dialogs that opened through `showAdaptiveDialog` (thread rename, Kanban "Board exported", Kanban error text, Kanban workers, Kanban task log, the Kanban assign and priority choices, plugin install report, hub skill confirm) open through `showAppDialog` (`lib/src/widgets/dialog_presentation.dart`). iOS, Android, Windows and Linux are unchanged. The decision is consistency with the other macOS dialogs that already use `showAppDialog` (for example the gateway restart confirm and `showConfirmDialog`).

Decisions:

- Transition: a 150 ms fade, none with reduced motion (was the Cupertino scale-in).
- Barrier: the theme's `DialogTheme.barrierColor`: 54% black in light (the light theme sets none, so `Colors.black54`) and `0x99000000`, 60% black, in dark. Cupertino's system barrier was 20% black light and 48% dark.
- Esc now closes all nine dialogs on macOS (new: the Cupertino route's non-dismissible barrier disabled it). A click outside closes all but the two dialogs with a text field (thread rename, Kanban text), so a stray click does not discard typed text; those two handle Esc themselves because their barrier is inert, and Cancel closes them too. This follows the new-profile dialog.
- SafeArea and closed-loop focus traversal inside the dialog.
- The dialog content (`AppAlertDialog`, `GroupedDialog`) does not change.

Contrast (panel against the dimmed page, from the local render): light 1.44:1 before and 3.94:1 after; dark 1.33:1 before and 1.34:1 after. Light dims visibly darker and the panel separates much more; dark is practically unchanged because the page is already near black.

Accepted differences from the Flutter build:

- Motion (the fade, reduced motion, the lost scale-in), click-outside-to-close, Esc, SafeArea and focus traversal are behaviour and are not shown on static boards.
- The canvas fakes the barrier by overriding `--h-apple-scrim` on the frame; the design system's `AlertDialog` and `GroupedDialog` have no barrier prop, and its Material `--h-scrim` (32% light, 60% dark) is not the theme barrier.
- The rename field is a plain token-styled input; the Flutter field is `AppDialogTextField`.
- Only the rename and the Priority choice are drawn; the other sites share the same route and barrier.

Rendered locally with headless Chrome; not checked in the claude.ai viewer or on a device.

## Settings dialog presentation

### Design (done)

- Canvas: https://claude.ai/artifact/Cej19PSApPQxiW9ScV9PzA (private; ask the owner for access)
- Date: 2026-11-21
- Boards (8): iPhone 390x844, Appearance over the chat, light and dark, before and after (4); iPhone after, Notifications (longest content) light; iPhone after, Memory choice dark; Mac 1280x800 after, Settings light and dark.

Scope: nine `GroupedDialog`s move from `showDialog` to `showAppDialog` (`lib/src/widgets/dialog_presentation.dart`): App Lock, About, Appearance, Settings (Mac only), Notifications, Spotlight (iOS and macOS), Dictation (iOS and macOS), Portable calls (not iOS) and Memory choice. Their content does not change. `KanbanTaskChoiceDialog` (Kanban Assign and Priority), already on `showAppDialog`, also gets the iOS Esc binding and the safe-area inset below, and the Kanban task log dialog (custom actions, no Esc binding) gets the inset.

- iOS: Material route (fade, `showDialog` barrier, tap outside closes) becomes the Cupertino route (scale-in, Cupertino barrier, tap outside does not close; Done stays, and Esc closes the dialog the same way Done does).
- macOS: Material route becomes the app's 150 ms fade, theme barrier, click outside closes, as in "Mac dialog presentation".
- Android, Windows and Linux: unchanged.

Decisions:

- Losing tap-outside on iOS is accepted. Every one of the nine has Done in its header. On iOS a modal panel with a Done button (a Settings-style sheet, a form or page sheet, an alert) is left through its button, and an outside tap is for popovers and action sheets. It also matches every other adaptive dialog in the app on iOS (`showAdaptiveDialog` defaults `barrierDismissible` to false there) and removes accidental closes. In Memory choice a row pick still closes with the value and Done closes with none.
- Esc keeps closing these dialogs on iOS (a hardware keyboard on iPad): `GroupedDialog` binds Esc to Done on iOS, because the Cupertino route's inert barrier does not.
- iOS barrier: Cupertino's (`kCupertinoModalBarrierColor`: 0.20 light, 0.478 dark; the design system's `--h-apple-scrim`) replaces `showDialog`'s (black54, 0.541, in light; the theme's 0.60 in dark). One barrier per platform, the same as the other iOS dialogs. Passing `barrierColor` on iOS to keep the old one was rejected: it would need a new `showAppDialog` parameter and would make these nine differ from the rest.
- On iOS a `GroupedDialog` keeps the safe-area inset (status bar, Dynamic Island, home indicator), as `showDialog` gave it.
- macOS barrier: unchanged (theme barrier: black54 in light, 0.60 in dark). Only the route and its 150 ms fade change.
- Android, Windows, Linux: unchanged.

Contrast (WCAG ratio, dialog panel against the dimmed chat page, iPhone):

| Theme | Barrier before | Barrier after | Before | After |
|---|---|---|---|---|
| Light | 0.541 (page #757575) | 0.200 (page #CCCCCC) | 4.61:1 | 1.61:1 |
| Dark | 0.600 (page #040404) | 0.478 (page #050506) | 1.03:1 | 1.02:1 |

In dark the panel is the page colour and is carried by its 1px zinc500 edge, which stands 4.24:1 off the page before and 4.22:1 after. In light the panel loses 3.0 points and falls below 3:1 (WCAG 1.4.11) if its boundary counts as required graphics; the shadow and 14 pt corners still separate it. Accepted for consistency with the other iOS dialogs.

Open owner decision: a hairline edge on the light panel on iOS (dark already has one) would restore the boundary for every iOS dialog at no cost to the barrier. It is not in this change.

Accepted differences (canvas against Flutter):

- Motion (scale-in on iOS, 150 ms fade on Mac), tap-outside and Esc cannot be shown in a static render.
- The Flutter dialog is a Material `Dialog` with an elevation shadow; the canvas draws an approximation (`0 6px 18px`), and adds the dark 1px edge (`hermesOverlayEdge`) the design system's inline dialog lacks.
- The design system's Notifications dialog has no "Messages from Hermes" group or background-check section, and its Settings dialog omits the Mac menu-bar and shortcut rows, so the canvas panels are shorter than the app's.
- Memory choice has no design-system component; the canvas builds it from `GroupedDialog` and `GroupedChoiceRow`.

Rendered locally with headless Chrome; not checked in the claude.ai viewer or on a device. Barrier values read from the Flutter SDK source and `lib/src/theme/hermes_theme.dart`; contrast computed and confirmed by pixel samples of the renders.

## Kanban dialog presentation

### Design (done)

- Canvas: https://claude.ai/artifact/2Y5jDgBmAMsX316sodvT9D (private; ask the owner for access)
- Date: 2026-11-22
- Boards (8, after only): Mac 1280 x 800 over the Kanban board: export light, import dark, edit task light, orchestration dark. iPhone 390 x 844 over the Kanban list: export dark, import light, edit task dark, orchestration light.

Scope: four `GroupedDialog`s with their own actions move from `showDialog` to `showAppDialog` (`lib/src/widgets/dialog_presentation.dart`) through `showKanbanDialog`: board export (`_ExportDialog`), board import (`_ImportDialog`), edit task (`_EditTaskDialog`) and orchestration (`KanbanOrchestrationDialog`). Their content and footers (Cancel and the filled action) do not change. iOS gets the Cupertino route and macOS the 150 ms fade, as in "Settings dialog presentation" and "Mac dialog presentation". Android, Windows and Linux are unchanged. `showKanbanDetentSheet` and `showKanbanFormSheet` stay hand-built (detents; the single edge pinned by `test/dialog_edge_test.dart`; the detent sheet is shared with the Activity panel) and are exempted from `style.dialog` in `tool/style_score_allowlist.yaml`.

Decisions:

- Route and barrier: as in "Settings dialog presentation" (iOS: scale-in, Cupertino barrier, tap outside does not close, safe area kept) and "Mac dialog presentation" (macOS: 150 ms fade, theme barrier). Not repeated here.
- Export, import and edit task have text fields. On macOS a click outside does not close them, so typed text is kept; Esc and Cancel close them (the rule of "Mac dialog presentation" for the thread rename and Kanban text dialogs).
- Orchestration has no text field, so on macOS a click outside closes it. Nothing typed can be lost; Save still sends only what changed.
- On iOS a tap outside closes none of the four. Their way out is Cancel in the footer, not Done in the header; the loss of tap-outside is accepted for the reasons in "Settings dialog presentation".
- Esc closes all four on iOS (a hardware keyboard) and macOS, closing with no result like Cancel.

Contrast (dialog panel against the dimmed page, from the local render):

| Theme | Platform | Before | After |
|---|---|---|---|
| Light | Mac | 4.61:1 | 4.61:1 (barrier unchanged) |
| Dark | Mac | 1.04:1 | 1.04:1 (barrier unchanged) |
| Light | iPhone | 4.61:1 | 1.61:1 |
| Dark | iPhone | 1.03:1 | 1.03:1 |

iPhone light falls below 3:1 as in the Settings dialogs; the shadow and 14 pt corners still separate the panel, and the open hairline-edge question in "Settings dialog presentation" covers it. In dark the panel is carried by its zinc500 edge (4.24:1 off the page), as before.

Accepted differences from the Flutter build:

- Motion, click-outside, Esc and focus are behaviour and are not shown on static boards.
- The design system's `GroupedDialog` has no actions prop: the canvas hides its Done with a CSS rule and draws the footer as plain markup. The barrier is an overlay div and the shadow an approximation.
- The design system's `GroupedSwitchRow` ellipsizes a long title on iPhone ("Auto-decompose triage ta..."); the Flutter row was not compared.
- Orchestration is drawn loaded with its pickers closed; its loading and error states are not drawn.

Rendered locally with headless Chrome; not checked in the claude.ai viewer or on a device.

## Kanban bulk picker

### Design (done)

- Canvas: https://claude.ai/artifact/PoFXDU6uzrwYHFde4gJCZz (private; ask the owner for access)
- Date: 2026-11-22
- Boards (9): iPhone 390 x 844 over the Kanban list in selection mode: Move to light (before), Move to light (after), Move to light at 1.5x text (after), Priority dark (after). Mac 1280 x 800 over the Kanban board: Assign to light (before and after), Move to dark (after). Android 412 x 915: Priority light (before and after).

Scope: the bulk bar's picker (`_pick` in `lib/src/kanban/widgets/kanban_bulk_bar.dart`, used for Move to, Assign to, Priority and Effort) moves from a raw Material `SimpleDialog` with `SimpleDialogOption`s to `KanbanTaskChoiceDialog` through `showAppDialog`, the way the task panel's assign and priority picks already open. `KanbanTaskChoiceDialog` gains a Cancel action (optional `actions`) as well as the optional footer and the nullable `selected`; the task panel's own callers keep their header Done. Archive keeps its confirmation. iOS gets the Cupertino route, macOS the 150 ms fade and Android the Material dialog, as in "Kanban dialog presentation", "Settings dialog presentation" and "Mac dialog presentation".

Decisions:

- A bulk action has no single current value, so no row is checked: `KanbanTaskChoiceDialog.selected` becomes nullable and the bulk bar passes null. On iOS and macOS no row carries a check mark. On Android the radios are all empty, an ordinary state of a Material group with no value. No other row form is used on any platform.
- The picker never reads the selected tasks' values, so Priority shows no mark even when every selected task has the same one.
- A pick closes the dialog and applies, as before (`onPicked` pops the value; the bar then calls `onMove`, `onAssign`, `onPriority` or `onEffort`). The radio is not redrawn as selected, because the group value stays null.
- A one-line footer under the rows names the scope: "Applies to the N selected tasks." (one task: "Applies to the selected task."). It needs an optional `footer` on `KanbanTaskChoiceDialog`. The old picker never named the count; with no current value to anchor on, this is the only context the dialog gives.
- Way out without a pick: the picker has no Done in the header, on any platform. A Done there would sit beside the "Done" status row of Move to (at 3x text the header read "Move to Done"). It has one Cancel text button in the footer (`GroupedDialog.actions`), like the other Kanban dialogs. Cancel, Esc (iOS with a hardware keyboard, and macOS) and Back on Android close it, and a click outside closes it on macOS and Android, applying nothing. On iOS a tap outside does not close it, as in "Settings dialog presentation".
- Effort ("Profile default", then the efforts) uses the same dialog and form.
- Cancel and the confirmation of Archive are unchanged. The four picks are one helper, not four dialogs.

Accepted differences from the Flutter build:

- The before boards are hand-drawn: the design system has no Material `SimpleDialog`, so they approximate Flutter's defaults (28 pt corners, 24 pt title, 48 pt options) with `--h-*` tokens.
- The design system's `KanbanTaskChoiceDialog` has no scope footer and no actions prop, so the after boards compose `GroupedDialog` (its Done hidden by a CSS rule), `GroupedSection` (with the footer) and `GroupedChoiceRow` directly, and draw the Cancel footer as plain markup. The 1.5x board is a CSS zoom of a 236 pt wide dialog, not a real text scale.
- On Android the after title is 18 pt semibold, where the old SimpleDialog title was 24 pt regular.
- iPhone light falls to about 1.6:1 between panel and page (Cupertino barrier 0.20), the accepted loss of "Settings dialog presentation". Dark panels are carried by their zinc-500 edge, as before.
- Motion, hover, focus rings, Esc and the radio's pressed state are behaviour and are not shown on static boards.

Rendered locally with headless Chrome; not checked in the claude.ai viewer or on a device. Contrast and large text sizes were not measured.

## AppBanner action stacking at large text

Recorded after the fact on 2026-11-24; describes what #1107 built. The look below is read from `lib/src/widgets/app_banner.dart` on main. No design canvas was made for it; the use cases named at the end are the record.

Box (every case): 12 pt padding, a 10 pt radius, a fill of the tone colour at 10% and a 1 px border of the tone colour at 35%. The icon is 18 pt with a 10 pt gap before the text. The title is semibold (w600), the detail follows in the body style. Tone colours are `HermesChatColors.success` (#166534 light, #4ADE80 dark), `HermesChatColors.warning` (#92400E, #FBBF24), the scheme's error colour and, for neutral, `subtleText`. The widget has no dark-specific branch; dark comes from those tokens.

Placement of the action:

- Beside the text (default): the action is the last child of the icon and text row. The text column takes the rest of the width.
- Stacked: the action moves under the text row and starts at the text's leading edge (the box's inner start plus 18 pt icon plus 10 pt gap, so 28 pt), not the box's edge. This applies when the text scaler turns 14 pt into more than 21 pt (above 150% text size) or when the locale's language is German, at any text size. A caller that caps its button's width while the action sits beside the text lifts the cap when `AppBanner.stacksAction(context)` is true (`_noteAction` in `lib/src/files/widgets/files_notes.dart` does: 150 pt cap beside, none stacked).
- A stacked button gets no inner side padding and 8 pt vertical padding, and is start-aligned, so its label lines up with the title above it while its target still reaches past the label. A button that sets its own side padding (through `style:`) is moved back toward the leading edge by that padding, clamped to 0 to 28 pt. The move is done in layout, so the whole target stays tappable. A button inside a Semantics, ExcludeSemantics or MergeSemantics wrapper is seen; one inside any other wrapper is not moved.
- A button action's minimum target, beside or stacked, is 44 pt on iOS (`kAppleMinTapTarget`), 48 dp on Material and 28 pt on a Mac, as a constraint around the button, so the Mac theme's compact density and a caller's own `minimumSize` cannot cut it. The tap target size is shrink-wrapped.
- An action that is not a button, such as a small spinner, is passed with `actionIsButton: false`; it keeps its own size and is not moved.

Large text: nothing is cut. The title and detail wrap in full at 2x and 3x; the stacked action sits under them. In German the banner is already stacked at 1.0x text, because long words would squeeze the text into a narrow column beside the action.

The banner is a polite live region; its container label is "title. detail" and the icon and text are excluded from the tree so it is read once. The action keeps its own node.

Use cases, in `widgetbook/app_banner_use_cases.dart` (the catalog shows each in light and dark, and the text scale addon covers 1x to 3x):

- `Largest text, with action` (2x, neutral, "You are offline" with "Try again")
- `Largest text (3x), long title, stacked action` (warning, "Couldn't confirm the save" with "Check")
- `German, stacked action` (warning, "Die Speicherung konnte nicht bestätigt werden" with "Erneut prüfen")
- `Action target (iPhone)`, `Action target (Mac)` and `Action target (Material)` (a pink outline marks the action's box: 44, 28 and 48)
- each tone with and without an action, title only, and `Custom icon`

Tests: `test/app_banner_test.dart` (stacking threshold, German, the three targets, the flush move and its tap target).

## Bot Screen viewer theme in Mac catalog previews

Recorded after the fact on 2026-11-24; describes what #1295 built. The Bot Screen viewer (`BotScreenViewerView`) builds its black theme with `buildHermesDarkTheme(platform: …)` for the platform of the surrounding theme, so a Mac catalog session no longer gives the iPhone and Material viewer use cases desktop tap-target size and density (and a flutter-test desktop case no longer gets phone sizing); the use cases that pick a platform (`onEachPlatform`, `_on` in `widgetbook/bot_screen_use_cases.dart`) go through `platformTheme` in `widgetbook/platform_theme.dart`, which keeps the surrounding brightness. Guarded by `arch.theme-platform-copy` and `test/bot_screen/viewer/bot_screen_viewer_view_test.dart` ("the viewer theme is built for ...").
