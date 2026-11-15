# Design brief: platform controls

Small decisions about how a shared control is sized on each platform. There is no openspec change for them; behaviour is recorded in the architecture file named in each entry.

## Mac button height

Decision: Mac push buttons are 28 pt tall (the AppKit regular control height and our macOS minimum target). Compact density no longer shrinks them.

Why: the Mac theme already asked for 28 (`_kMacButtonHeight`, set as `minimumSize`), but ThemeData's desktop default density is compact (-2, -2), which takes 8 off a button's minimum size. Every FilledButton, FilledButton.tonal, OutlinedButton and TextButton therefore measured 20 pt. A 20 pt button is under the Mac minimum target of 28 and looked small next to the 28 pt toolbar buttons and the 40 pt-high text fields in forms.

Fix: the Mac button themes use `VisualDensity.standard`, and the Mac TextButton gets 4 pt vertical padding so it is 28 and not 36. Nothing else changes: the global density stays compact on desktop, so list tiles, fields, checkboxes, chips and IconButton (40) keep their size, SegmentedButton stays 32, Windows and Linux buttons stay 32, Android and iOS stay 48. Measured with `test/theme/mac_button_height_test.dart`.

Alternative considered: keep 20 pt, like a small AppKit control. Rejected: 20 pt is the height of a mini or small control, not of a push button; it misses the 28 pt target the rest of the app and `AppBanner`, `DestructiveTintButton` and `toolsButtonStyle` already use, so those widgets were the only 28 pt buttons on a Mac.

Another alternative: raise `minimumSize` by 8 so the compact density cancels out. Rejected: the theme's `minimumSize` would read 36 and the existing assertion that it is 28 would be false.

Renders (macOS theme, 1280 x 800, a row of every button type, a field with a button, `SoulSaveActions`, a list tile, and a confirm dialog), before and after:

- `before/1-buttons-light.png`, `after/1-buttons-light.png`, `before/1-buttons-dark.png`, `after/1-buttons-dark.png`
- `before/2-dialog-light.png`, `after/2-dialog-light.png`, `before/2-dialog-dark.png`, `after/2-dialog-dark.png`

They were rendered by a throwaway test into a scratch folder `macbtn/` and are not checked in. The Apple-style dialog actions do not use Material buttons and look the same in both.
