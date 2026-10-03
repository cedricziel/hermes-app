import type { HTMLAttributes, ReactNode } from "react";
import "./Card.css";

export interface CardProps extends HTMLAttributes<HTMLDivElement> {
  /** Inner padding in px. 0 for cards that hold list rows edge to edge. */
  padding?: number;
  /** Hover and pointer cursor, for a card that opens something. */
  interactive?: boolean;
  /** Tinted `surface-high` background instead of the page surface. */
  tinted?: boolean;
  children?: ReactNode;
}

/** The app's card: page-colored surface, 1px border, 14px radius, no shadow. */
export function Card({
  padding = 16,
  interactive = false,
  tinted = false,
  className,
  style,
  children,
  ...rest
}: CardProps) {
  const classes = [
    "h-card",
    interactive ? "h-card--interactive" : null,
    tinted ? "h-card--tinted" : null,
    className,
  ]
    .filter(Boolean)
    .join(" ");
  return (
    <div className={classes} style={{ padding, ...style }} {...rest}>
      {children}
    </div>
  );
}
