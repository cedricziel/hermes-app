# Design brief: Trust badge contrast

An audit fix, not a feature: there is no openspec change. The fix is a colour choice for badges that already exist.

## Design (done)

Claude Design canvas "Hermes: Trust badge contrast", built on the Hermes App design system: https://claude.ai/artifact/HyXy7vPNQbagbj41AmMkHc (private; ask its owner for access). Four boards in two rows: Before (light, dark) and After (light, dark). Each board lists the six badges (Official, Trusted, Community, Hub, Bundled, Agent) with the fill, the label colour, the contrast ratio and a pass or fail mark (icon and word, never colour alone). The canvas was not rendered locally.

Decisions taken in the design pass:

- Official: fill `primary`, label `onPrimary`. It stays the strongest fill. Light zinc900 with white, 17.7:1. Dark zinc50 with zinc900, 17.0:1.
- Trusted: one step above Community. Light fill zinc200, dark fill zinc700, label `onSurface` in both. Light 14.0:1, dark 10.0:1. `secondaryContainer` is no longer used, because the theme defines no container roles and it falls back to `secondary` (zinc700 in light, zinc300 in dark), which no label colour suits in both themes.
- Community, Hub, Bundled, Agent: fill unchanged (`surfaceContainerHighest`), label named `onSurface` instead of left to the default. Light 16.1:1, dark 14.3:1.
- Every label is at least 4.5:1 in both themes. The lowest is Trusted in dark at 10.0:1.
- Shape and size are unchanged: `AppBadge` 6 px radius, 12 px text, the same padding.
- The tiers differ by weight of fill (solid, mid, faint), and the word carries the meaning. The label text is never below 4.5:1 against its own fill; the fill is decoration only. The Trusted and Community fills are only 1.15:1 apart in light and 1.43:1 in dark, so they are not a distinction on their own and a screen must never show the fill alone.

Corrections after the pass: the canvas shows Trusted using a new `secondaryContainer` / `onSecondaryContainer` scheme pair; that is changed to a private pair (see the build notes). The colours, ratios and boards are unchanged.

Corrections where this brief did not work: none beyond the corrections above.

Copy added: none.

## The bug

`TrustBadge` and `SourceBadge` in `lib/src/skills/widgets/skill_badges.dart` build `AppBadge.filled(label, fill)`. `AppBadge.filled` draws its label in the theme's `labelSmall` colour, which is `onSurface`, whatever the fill.

| Badge                                                      | Light fill / label | Ratio | Dark fill / label | Ratio |
| ---------------------------------------------------------- | ------------------ | ----- | ----------------- | ----- |
| Official (`primaryContainer`, falls back to `primary`)     | zinc900 / zinc900  | 1.0   | zinc50 / zinc50   | 1.0   |
| Trusted (`secondaryContainer`, falls back to `secondary`)  | zinc700 / zinc900  | 1.7   | zinc300 / zinc50  | 1.4   |
| Community, Hub, Bundled, Agent (`surfaceContainerHighest`) | zinc100 / zinc900  | 16.1  | zinc800 / zinc50  | 14.3  |

Official is black on black in light and white on white in dark.

## After

| Badge                          | Light fill / label                        | Ratio | Dark fill / label | Ratio |
| ------------------------------ | ----------------------------------------- | ----- | ----------------- | ----- |
| Official                       | zinc900 / white (`primary` / `onPrimary`) | 17.7  | zinc50 / zinc900  | 17.0  |
| Trusted                        | zinc200 / zinc900 (`onSurface`)           | 14.0  | zinc700 / zinc50  | 10.0  |
| Community, Hub, Bundled, Agent | zinc100 / zinc900                         | 16.1  | zinc800 / zinc50  | 14.3  |

## Build notes

- Give `AppBadge.filled` a required `labelColor` so a filled badge can never take a label colour it was not paired with. The callers to update are `lib/src/skills/widgets/skill_badges.dart` (`TrustBadge`, line 27, and `SourceBadge`, line 44) and the "Filled, surface colours" use case in `widgetbook/app_badge_use_cases.dart` (lines 74-79, which still passes `primaryContainer` and `secondaryContainer`). `test/widgets/banner_badge_pins_test.dart` builds `TrustBadge` and `SourceBadge` rather than `AppBadge.filled`, so it needs no signature change, but its size pins must still pass.
- The Trusted fill has no colour scheme role today. Keep a private pair in `skill_badges.dart` (zinc200 and zinc900 in light, zinc700 and zinc50 in dark), not new `secondaryContainer` / `onSecondaryContainer` roles in `lib/src/theme/hermes_theme.dart`. Adding those roles would recolour every Material widget that reads them app-wide (SegmentedButton, the NavigationBar indicator, tonal buttons, profile avatars), a visual change nobody reviewed. The private pair changes only the badge. (The first draft of this brief preferred the scheme.)
- Widgetbook: one use case showing all six badges, both themes. A test that computes the contrast of each pair in both themes and fails under 4.5.
- The ratios were computed with the WCAG relative luminance formula from the zinc values in `HermesColors`.
