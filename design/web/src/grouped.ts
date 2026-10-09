import type { GroupedChrome } from "./platform";
import "./grouped.css";

/**
 * Internal: the sizes of a grouped settings list per look, as Flutter's
 * `GroupedMetrics` (lib/src/widgets/grouped_list.dart). `grouped.css` holds
 * the same numbers as `--hg-*` properties on the `h-gm--<chrome>` classes;
 * this table holds only the icon sizes.
 */
export const groupedMetrics = {
  ios: { titleSize: 17, subtitleSize: 15, tileIconSize: 18, chevron: 16 },
  mac: { titleSize: 13, subtitleSize: 11, tileIconSize: 14, chevron: 12 },
  material: { titleSize: 16, subtitleSize: 14, tileIconSize: 20, chevron: 20 },
} as const;

/** Where a group's separators start, from the group's edge. */
export type DividerIndent = "text" | "leading" | "tile" | "choice" | number;


/** The class that sets a grouped component's `--hg-*` sizes. */
export const metricsClass = (chrome: GroupedChrome) => `h-gm--${chrome}`;
