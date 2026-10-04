import type { ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import { cx, PlatformScope, usePlatform, type Platform } from "../../platform";
import "./ListRow.css";

export interface ListRowProps {
  /** Leading Material Symbols icon name (24px, the paired CupertinoIcons glyph on Apple): `check_circle`, `radio_button_unchecked`, `tune`. */
  icon?: string;
  /** Draw `icon` filled (a checked board, a selected item). */
  iconFilled?: boolean;
  /** Any leading node instead of `icon`, such as an avatar or a `Spinner`. */
  leading?: ReactNode;
  /** The row's title, one line with an ellipsis. */
  title: string;
  /** Muted text under the title; wraps over as many lines as it needs ("default · 4 tasks", "t_run · run #7 · coder · started 3 min ago"). */
  subtitle?: string;
  /** Monospace subtitle, for ids, paths and commands. */
  monoSubtitle?: boolean;
  /**
   * Right side of the row: a `Switch`, a `Spinner`, a `Badge`, an
   * `IconButton` (the "…" of a row menu inside a `MenuAnchor`) or any node.
   * For a row that opens another screen use `disclosure` instead.
   */
  trailing?: ReactNode;
  /**
   * The row opens another screen. Apple: a muted chevron at the right, as iOS
   * draws disclosure. Material: nothing, as Flutter's ListTile. Drawn after
   * `trailing` when both are set.
   */
  disclosure?: boolean;
  /** Highlighted as the item open in a detail pane. */
  selected?: boolean;
  /** Greyed out and not pressable. */
  disabled?: boolean;
  /** The row was pressed; without it the row is static text. */
  onClick?: () => void;
  /**
   * `material`: Flutter's ListTile (56px, or 72px with a subtitle; 16px side
   * padding; a full-width row, separate rows with a 1px divider if needed).
   * `apple`: a row of an iOS inset grouped list: 44px minimum, the iOS type
   * ramp, rows stacked as siblings share a tinted group with 10px corners
   * 16px in from the edges and hairlines between them (see `grouped`).
   * Inherits the provider's platform.
   */
  platform?: Platform;
  /** Apple only: draw the row as part of an inset grouped list (default true). Set false for a plain full-width row, as in a sheet. */
  grouped?: boolean;
}

/**
 * The app's list tile: an optional leading icon, a title, a muted subtitle
 * and a trailing control or chevron. Use it for any plain list (Kanban
 * boards and workers, settings rows, pickers). Stack rows as siblings in one
 * container: under `apple` they form one inset grouped list by themselves.
 */
export function ListRow({
  icon,
  iconFilled = false,
  leading,
  title,
  subtitle,
  monoSubtitle = false,
  trailing,
  disclosure = false,
  selected = false,
  disabled = false,
  onClick,
  platform,
  grouped = true,
}: ListRowProps) {
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const interactive = !!onClick && !disabled;
  const chevron = disclosure && apple;
  const lead =
    leading ??
    (icon ? <Icon name={icon} filled={iconFilled} size={24} /> : null);
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div
        className={cx(
          "h-list-row",
          apple && "h-list-row--apple",
          apple && grouped && "h-list-row--grouped",
          subtitle && "h-list-row--two-line",
          selected && "h-list-row--selected",
          interactive && "h-list-row--interactive",
          disabled && "h-list-row--disabled",
        )}
        role={interactive ? "button" : undefined}
        tabIndex={interactive ? 0 : undefined}
        aria-disabled={disabled || undefined}
        onClick={interactive ? onClick : undefined}
        onKeyDown={
          interactive
            ? (e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  onClick?.();
                }
              }
            : undefined
        }
      >
        {lead ? <span className="h-list-row__leading">{lead}</span> : null}
        <span className="h-list-row__text">
          <span className="h-list-row__title">{title}</span>
          {subtitle ? (
            <span
              className={cx("h-list-row__subtitle", monoSubtitle && "h-mono")}
            >
              {subtitle}
            </span>
          ) : null}
        </span>
        {trailing || chevron ? (
          <span
            className="h-list-row__trailing"
            onClick={(e) => e.stopPropagation()}
          >
            {trailing}
            {chevron ? (
              <Icon
                name="chevron_right"
                size={20}
                className="h-list-row__chevron"
              />
            ) : null}
          </span>
        ) : null}
      </div>
    </PlatformScope>
  );
}
