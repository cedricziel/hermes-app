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
- The tiers differ by weight of fill (solid, mid, faint), and the word carries the meaning. The Trusted and Community fills are one step apart, so a screen must never show the fill alone.

Corrections where this brief did not work: none.

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

- Give `AppBadge.filled` a required `labelColor` so a filled badge can never take a label colour it was not paired with. Update its other callers.
- The Trusted fill has no colour scheme role today. Either add `secondaryContainer` and `onSecondaryContainer` to both schemes in `lib/src/theme/hermes_theme.dart` (zinc200 and zinc900 in light, zinc700 and zinc50 in dark), or keep a private pair in `skill_badges.dart`. Prefer the scheme: it makes the fallback to `secondary` go away for every future use.
- Widgetbook: one use case showing all six badges, both themes. A test that computes the contrast of each pair in both themes and fails under 4.5.
- The ratios were computed with the WCAG relative luminance formula from the zinc values in `HermesColors`.
