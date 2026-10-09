import type { GroupedChrome } from "./platform";
import "./grouped.css";

/**
 * Internal: the sizes of a grouped settings list per look, as Flutter's
 * `GroupedMetrics` (lib/src/widgets/grouped_list.dart). `grouped.css` holds
 * the same numbers as `--hg-*` properties on the `h-gm--<chrome>` classes;
 * this table is for icon sizes and separator indents.
 */
export const groupedMetrics = {
  ios: {
    rowPadding: 16,
    titleSize: 17,
    subtitleSize: 15,
    leadingGap: 12,
    tileSize: 29,
    tileIconSize: 18,
    chevron: 16,
  },
  mac: {
    rowPadding: 12,
    titleSize: 13,
    subtitleSize: 11,
    leadingGap: 10,
    tileSize: 24,
    tileIconSize: 14,
    chevron: 12,
  },
  material: {
    rowPadding: 16,
    titleSize: 16,
    subtitleSize: 14,
    leadingGap: 16,
    tileSize: 32,
    tileIconSize: 20,
    chevron: 20,
  },
} as const;

/** The width of a shrink-wrapped Material radio button. */
export const RADIO_SIZE = 40;

/** Where a group's separators start, from the group's edge. */
export type DividerIndent = "text" | "leading" | "tile" | "choice" | number;

export function dividerIndentPx(
  chrome: GroupedChrome,
  indent: DividerIndent = "text",
): number {
  if (typeof indent === "number") return indent;
  const m = groupedMetrics[chrome];
  switch (indent) {
    case "leading":
      return m.rowPadding + m.titleSize + 5 + m.leadingGap;
    case "tile":
      return m.rowPadding + m.tileSize + m.leadingGap;
    case "choice":
      return chrome === "material"
        ? m.rowPadding + RADIO_SIZE + m.leadingGap
        : m.rowPadding;
    default:
      return m.rowPadding;
  }
}

/** The class that sets a grouped component's `--hg-*` sizes. */
export const metricsClass = (chrome: GroupedChrome) => `h-gm--${chrome}`;
