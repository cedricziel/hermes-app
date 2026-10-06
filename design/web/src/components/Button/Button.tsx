import type { ButtonHTMLAttributes, ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import "./Button.css";

export interface ButtonProps extends Omit<
  ButtonHTMLAttributes<HTMLButtonElement>,
  "children"
> {
  /**
   * `filled`: the one primary action (near-black in light, near-white in dark).
   * `outlined`: secondary actions next to it. `text`: quiet actions such as
   * Cancel or Deny. `danger`: a destructive confirm. `danger-outlined`: a
   * destructive secondary action in the error color ("Uninstall", "Ask agent
   * to delete").
   */
  variant?: "filled" | "outlined" | "text" | "danger" | "danger-outlined";
  /** Leading Material Symbols icon name. */
  icon?: string;
  /** Stretch to the parent's width. */
  fullWidth?: boolean;
  /** Smaller 32px button for dense rows and cards. */
  compact?: boolean;
  children?: ReactNode;
}

/** Text button in the app's four styles: 40px tall, 10px radius, no shadow. */
export function Button({
  variant = "filled",
  icon,
  fullWidth = false,
  compact = false,
  className,
  children,
  type = "button",
  ...rest
}: ButtonProps) {
  const classes = [
    "h-button",
    `h-button--${variant}`,
    icon ? "h-button--with-icon" : null,
    fullWidth ? "h-button--full" : null,
    compact ? "h-button--compact" : null,
    className,
  ]
    .filter(Boolean)
    .join(" ");
  return (
    <button type={type} className={classes} {...rest}>
      {icon ? <Icon name={icon} size={18} /> : null}
      {children}
    </button>
  );
}
