import type { ButtonHTMLAttributes } from "react";
import { Icon } from "../Icon/Icon";
import "./IconButton.css";

export interface IconButtonProps extends Omit<
  ButtonHTMLAttributes<HTMLButtonElement>,
  "children"
> {
  /** Material Symbols icon name; under `platform="apple"` the paired CupertinoIcons glyph (see `Icon`). */
  icon: string;
  /** Accessible name, also shown as the tooltip. Required: the button has no text. */
  label: string;
  /**
   * `standard`: bare glyph (toolbars, rows). `filled`: round primary button,
   * as the composer's send arrow. `outlined`: bordered square.
   */
  variant?: "standard" | "filled" | "outlined";
  /** `muted` draws the glyph in the subtle text color (attach, row overflow menus). */
  tone?: "default" | "muted";
  /** 40 (default), 32 for dense rows, or 44 for an iOS bar button (22px glyph). */
  size?: 32 | 40 | 44;
}

/** An icon-only button with a circular hover state. */
export function IconButton({
  icon,
  label,
  variant = "standard",
  tone = "default",
  size = 40,
  className,
  type = "button",
  ...rest
}: IconButtonProps) {
  const classes = [
    "h-icon-button",
    `h-icon-button--${variant}`,
    tone === "muted" ? "h-icon-button--muted" : null,
    className,
  ]
    .filter(Boolean)
    .join(" ");
  return (
    <button
      type={type}
      className={classes}
      aria-label={label}
      title={label}
      style={{ width: size, height: size }}
      {...rest}
    >
      <Icon name={icon} size={size === 32 ? 18 : 22} />
    </button>
  );
}
