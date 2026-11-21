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
- A click outside closes the dialog, as Esc already does (the Cupertino route did not close on a click). Exception: the two dialogs with a text field (thread rename, Kanban text) do not close on a click outside on macOS, so a stray click does not discard typed text; Esc and Cancel close them. This follows the new-profile dialog.
- SafeArea and closed-loop focus traversal inside the dialog.
- The dialog content (`AppAlertDialog`, `GroupedDialog`) does not change.

Contrast (panel against the dimmed page, from the local render): light 1.44:1 before and 3.94:1 after; dark 1.33:1 before and 1.34:1 after. Light dims visibly darker and the panel separates much more; dark is practically unchanged because the page is already near black.

Accepted differences from the Flutter build:

- Motion (the fade, reduced motion, the lost scale-in), click-outside-to-close, Esc, SafeArea and focus traversal are behaviour and are not shown on static boards.
- The canvas fakes the barrier by overriding `--h-apple-scrim` on the frame; the design system's `AlertDialog` and `GroupedDialog` have no barrier prop, and its Material `--h-scrim` (32% light, 60% dark) is not the theme barrier.
- The rename field is a plain token-styled input; the Flutter field is `AppDialogTextField`.
- Only the rename and the Priority choice are drawn; the other sites share the same route and barrier.

Rendered locally with headless Chrome; not checked in the claude.ai viewer or on a device.
