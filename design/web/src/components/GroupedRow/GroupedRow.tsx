import type { ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import {
  cx,
  useGroupedChrome,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { groupedMetrics, metricsClass } from "../../grouped";
import "./GroupedRow.css";

export interface GroupedRowProps {
  /** The row's name: "netbox", "Vision", "Remove plugin". iOS 17px, Mac 13px, Material 16px. */
  title: string;
  /** Muted text right after the title, in the subtitle size: a version ("v1.2.0"), "Official", "Ready". */
  meta?: string;
  /** One muted line under the title, cut with an ellipsis: "Bundled · Run shell commands." iOS 15px, Mac 11px, Material 14px. */
  subtitle?: string;
  /** Sets `subtitle` in the monospace font at the footer size (13px, Mac 11px), for a command line: "npx -y @acme/mcp". */
  monospaceSubtitle?: boolean;
  /** A smaller muted line under the subtitle (13px, Mac 11px): "Remote · OAuth · 2 tools". */
  caption?: string;
  /** A line in the warning color with a warning triangle, up to two lines: "Needs login", "Sign in needed". */
  warning?: string;
  /** A line in the error color with an error glyph, one line: "Invalid bot token". */
  error?: string;
  /** Material Symbols name of a leading icon, drawn muted at the title size + 5 (22 / 18 / 21px). Pair with `dividerIndent="leading"` on the section. */
  icon?: string;
  /** Any leading element instead of `icon`, usually a `GroupedTile` (pair with `dividerIndent="tile"`). */
  leading?: ReactNode;
  /** A short status in muted text before the chevron: "On", "Off", "Inactive", "3 tools", "Update available". */
  value?: string;
  /** A control at the trailing edge instead of the chevron: a `Switch`, a small `Button`, a `Spinner`. Next to a row that opens something it stays its own control. */
  trailing?: ReactNode;
  /** The row opens something (details, a picker). Draws the hover/press fill and, without `trailing`, the disclosure chevron. */
  onClick?: () => void;
  /** Whether to draw the disclosure chevron (iOS 16px, Mac 12px, Material 20px, muted). By default when the row has `onClick` and no `trailing`. */
  chevron?: boolean;
  /** Highlights the row whose details show beside the list (filled with the border color). */
  selected?: boolean;
  /** Draws the title in the error color, for "Remove plugin", "Delete profile". */
  destructive?: boolean;
  /** Dims the row and ignores clicks. */
  disabled?: boolean;
  /**
   * `apple` + `touch`: rows at least 44px, 16px padding. `apple` + `mac`:
   * 40px rows, 12px padding, 13px titles. `material`: 56px rows, 16px
   * padding. Inherits the provider's platform and the enclosing scope's
   * device.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`. Inherited from the enclosing `GroupedListView`/`GroupedSection`/`SettingsScaffold`, else `touch`. */
  device?: AppleDevice;
}

/**
 * A row of a `GroupedSection`: a title with optional inline `meta`, a
 * one-line `subtitle`, a `caption`, and `warning`/`error` lines under it;
 * at the trailing edge a muted `value` with a disclosure chevron, or a
 * `trailing` control. Status reads as text, never as a pill.
 */
export function GroupedRow({
  title,
  meta,
  subtitle,
  monospaceSubtitle = false,
  caption,
  warning,
  error,
  icon,
  leading,
  value,
  trailing,
  onClick,
  chevron,
  selected = false,
  destructive = false,
  disabled = false,
  platform,
  device,
}: GroupedRowProps) {
  const chrome = useGroupedChrome(platform, device);
  const m = groupedMetrics[chrome];
  const showChevron = chevron ?? (onClick !== undefined && !trailing);
  const apart = trailing !== undefined && trailing !== null && !!onClick;
  const lead =
    leading ?? (icon ? <Icon name={icon} size={m.titleSize + 5} /> : null);
  const body = (
    <>
      {lead ? <span className="h-grouped-row__leading">{lead}</span> : null}
      <span className="h-grouped-row__text">
        <span
          className={cx(
            "h-grouped-row__title",
            destructive && "h-grouped-row__title--destructive",
          )}
        >
          {title}
          {meta ? <span className="h-grouped-row__meta">{meta}</span> : null}
        </span>
        {subtitle ? (
          <span
            className={cx(
              "h-grouped-row__subtitle",
              monospaceSubtitle && "h-grouped-row__subtitle--mono",
            )}
          >
            {subtitle}
          </span>
        ) : null}
        {caption ? (
          <span className="h-grouped-row__caption">{caption}</span>
        ) : null}
        {warning ? (
          <span className="h-grouped-row__status h-grouped-row__status--warning">
            <Icon name="warning" size={m.subtitleSize} />
            <span className="h-grouped-row__status-text">{warning}</span>
          </span>
        ) : null}
        {error ? (
          <span className="h-grouped-row__status h-grouped-row__status--error">
            <Icon name="error_outline" size={m.subtitleSize} />
            <span className="h-grouped-row__status-text">{error}</span>
          </span>
        ) : null}
      </span>
      {value ? <span className="h-grouped-row__value">{value}</span> : null}
      {trailing && !apart ? (
        <span className="h-grouped-row__trailing">{trailing}</span>
      ) : null}
      {showChevron ? (
        <Icon
          name="chevron_right"
          size={m.chevron}
          className="h-grouped-row__chevron"
        />
      ) : null}
    </>
  );
  const rowClass = cx(
    "h-grouped-row",
    metricsClass(chrome),
    selected && "h-grouped-row--selected",
    disabled && "h-grouped-row--disabled",
    apart && "h-grouped-row--apart",
  );
  if (!onClick) {
    return (
      <div className={rowClass}>
        <div className="h-grouped-row__main">{body}</div>
      </div>
    );
  }
  return (
    <div className={rowClass}>
      <button
        type="button"
        className="h-grouped-row__main h-grouped-row__main--button"
        aria-current={selected || undefined}
        disabled={disabled}
        onClick={onClick}
      >
        {body}
      </button>
      {apart ? (
        <span className="h-grouped-row__trailing h-grouped-row__trailing--apart">
          {trailing}
        </span>
      ) : null}
    </div>
  );
}

export interface GroupedTileProps {
  /** Material Symbols name of the glyph: "smart_toy" for a messaging bot, "hub". */
  icon?: string;
  /** A letter or two instead of the icon: a server's or profile's initial, "G". */
  children?: ReactNode;
  platform?: Platform;
  device?: AppleDevice;
}

/**
 * A row's leading picture in a rounded square filled with the tinted
 * surface: iOS 29px (7px corners, 18px glyph), Mac 24px (6px, 14px),
 * Material 32px (10px, 20px). Letters are 3/4 of the glyph size, semibold.
 * Pass it as a row's `leading` and `dividerIndent="tile"` on the section.
 */
export function GroupedTile({
  icon,
  children,
  platform,
  device,
}: GroupedTileProps) {
  const chrome = useGroupedChrome(platform, device);
  return (
    <span className={cx("h-grouped-tile", metricsClass(chrome))}>
      {icon ? (
        <Icon name={icon} size={groupedMetrics[chrome].tileIconSize} />
      ) : (
        children
      )}
    </span>
  );
}
