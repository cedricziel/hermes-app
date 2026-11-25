# Settings bar at large text

Applies to `SettingsScaffold` and `AdaptiveBackButton` on iOS (F.107, F.265).

## Problem

At 3x text on a 320 pt phone the iOS bar's 88 pt leading slot clipped
"Cancel" to "Ca" and a form's Save was pushed off the screen. The German
"Speichern" label is the case the tests show going missing; the English
"Save" fits under the test font even without the fix, so the tests do not
claim it was lost.

## Options considered

1. Keep the text and truncate it. "Ca..." names nothing, and the slot still
   takes width the title and Save need.
2. Shrink the text with `FittedBox`. The label becomes smaller than the
   body text the user asked for and still cannot be read at 3x in 88 pt.
3. Collapse the leading item to an icon from 1.5x text.
4. Move the action below the form. The action leaves the bar, so it is no
   longer where every other form has it and it scrolls out of reach.

## Decision

Option 3, plus a capped, shrinking Save label (at most 42% of the window
width, `FittedBox`) so the action always stays in the bar.

From a text scale of 1.5 (`kLargeBarTextScale`, `largeBarText`) the iOS
leading item drops its label for a glyph: the back button becomes the
chevron alone, Cancel becomes a close glyph from the platform icon set
(`AppIcons.close`). Apple's own bars drop the back label and use glyphs when
space runs out. Each keeps a 44 pt target and its label (the previous title,
"Cancel") as its spoken name. The title takes the room left and ends in an
ellipsis. One shared button (`CollapsedBarIconButton`, built on
`NamedIconButton` and `SettingsScaffold.appleBarButtonStyle`) draws both.

## Unchanged

- Below 1.5x text: the bar is as before (labelled back, text Cancel).
- Android and other Material bars (stock `BackButton` and `CloseButton`).
- The Mac toolbar, which does not scale with text.
- Windows and Linux.

## States and where they are

- Catalog, "Settings pages / SettingsScaffold": use cases "Form action at
  1x text", "Form action at 2x text" and "Form action at 3x text", on each
  platform, both themes, phone and desktop width; and "Form with Cancel at
  2x text" and "Form with Cancel at 3x text", the collapsed Cancel icon.
- Catalog, "Adaptive bars": the detail bar with back and tabs.
- Tests: `test/widgets/settings_scaffold_text_size_test.dart` (320 pt, 3x,
  iOS and Android, LTR and RTL, English and German),
  `test/widgets/adaptive_back_button_large_text_test.dart` (1.5x, 2x, 3x,
  both themes) and the Cancel case of
  `test/workspaces/widgets/workspace_widgets_review_test.dart`.

## Not checked

- No canvas was published from this session (no Claude Design pass); see the exemption below.
- Nothing was run on a device or in the simulator.
- No render with the real system font; the tests use the test font, so the
  exact width at which a label would clip differs.

## Exemption

Owner's exemption, 2026-11-25 (given to the orchestrator in its session): this pull request merges without a design canvas; the written record is the design record.
