import type { ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import { Switch } from "../Switch/Switch";
import { cx, PlatformScope, usePlatform, type Platform } from "../../platform";
import "./SwitchRow.css";

export interface SwitchRowProps {
  /** The setting: "Enabled", "Turn on after installing", "Hide from dashboard sidebar". */
  title: string;
  /** What it does, under the title in muted text: "Used from the next chat". Wraps over as many lines as it needs. */
  subtitle?: ReactNode;
  /** Material Symbols name of a leading 24px icon, for settings lists with icons (a bot's platform). Leave out in forms and detail panes. */
  icon?: string;
  /** On or off. */
  checked: boolean;
  /** Greyed out and not flippable, while a change is in flight. */
  disabled?: boolean;
  /** Called with the new value when the row or its switch is clicked. */
  onChange?: (checked: boolean) => void;
  /** Horizontal padding in px. 0 (default) for a row in a padded form or pane, 16 for a row edge to edge in a list or a `Card padding={0}`. */
  inset?: number;
  /**
   * The row is the same Material list tile everywhere, as the app's
   * `SwitchListTile.adaptive`; only the switch changes: the 51x31 toggle
   * under `apple`, the Material 3 switch otherwise. Inherits the provider's
   * platform.
   */
  platform?: Platform;
}

/**
 * A setting that is on or off: a title, an optional subtitle and a trailing
 * `Switch`, the whole row clickable. Use it for every labelled switch in a
 * form, a detail pane or a settings list instead of laying out a `Switch`
 * by hand.
 */
export function SwitchRow({
  title,
  subtitle,
  icon,
  checked,
  disabled = false,
  onChange,
  inset = 0,
  platform,
}: SwitchRowProps) {
  const resolved = usePlatform(platform);
  return (
    <PlatformScope platform={resolved}>
      <div
        className={cx("h-switch-row", disabled && "h-switch-row--disabled")}
        style={{ paddingInline: inset }}
        onClick={() => {
          if (!disabled) onChange?.(!checked);
        }}
      >
        {icon ? (
          <Icon name={icon} size={24} className="h-switch-row__icon" />
        ) : null}
        <div className="h-switch-row__text">
          <div className="h-switch-row__title">{title}</div>
          {subtitle ? (
            <div className="h-switch-row__subtitle">{subtitle}</div>
          ) : null}
        </div>
        <Switch
          checked={checked}
          label={title}
          disabled={disabled}
          onClick={(e) => e.stopPropagation()}
          onChange={onChange}
        />
      </div>
    </PlatformScope>
  );
}
