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
