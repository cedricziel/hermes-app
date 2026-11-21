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
