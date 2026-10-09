import type { ButtonHTMLAttributes } from "react";
import { cx, usePlatform, type Platform } from "../../platform";
import "./Switch.css";

export interface SwitchProps extends Omit<
  ButtonHTMLAttributes<HTMLButtonElement>,
  "children" | "onChange"
> {
  /** On or off. */
  checked: boolean;
  /** Called with the new value when the user flips it. */
  onChange?: (checked: boolean) => void;
  /** Accessible name, e.g. "Pause" or the row's title. Required: the switch has no text. */
  label: string;
  /**
   * `material`: the Material 3 switch, 52x32, a thumb that grows from 16 to
   * 24px when on. `apple`: the iOS and macOS toggle, 51x31, a 27px thumb that
   * keeps its size. Both draw on in the primary color (near-black in light,
   * near-white in dark), not Apple's green, as the app does. Inherits the
   * provider's platform.
   */
  platform?: Platform;
  /** Apple only: the small 36x22 toggle of a Mac settings row (`GroupedSwitchRow` on a Mac). */
  small?: boolean;
}

/**
 * An on/off switch for a setting or a row (a scheduled job, an MCP server, a
 * Kanban notify channel). Its `onClick` runs before `onChange`, so a row can
 * stop the click from also opening the row.
 */
export function Switch({
  checked,
  onChange,
  label,
  platform,
  small = false,
  className,
  onClick,
  type = "button",
  ...rest
}: SwitchProps) {
  const apple = usePlatform(platform) === "apple";
  return (
    <button
      type={type}
      role="switch"
      aria-checked={checked}
      aria-label={label}
      className={cx(
        "h-switch",
        apple && "h-switch--apple",
        apple && small && "h-switch--small",
        checked && "h-switch--on",
        className,
      )}
      onClick={(e) => {
        onClick?.(e);
        onChange?.(!checked);
      }}
      {...rest}
    >
      <span className="h-switch__thumb" />
    </button>
  );
}
