import type { ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import "./Badge.css";

export interface BadgeProps {
  /**
   * Color of the text on a 10% tint of the same color. `neutral` for tenants
   * and plain tags, `error` for priorities and failures, `success`/`warning`
   * for run outcomes, `strong` for an inverted near-black label ("Default").
   */
  tone?: "neutral" | "error" | "success" | "warning" | "strong";
  /** Optional leading Material Symbols icon name. */
  icon?: string;
  children: ReactNode;
}

/** A small rounded tag (6px radius, 11px text): P1, a tenant, "Enabled", "Failed". */
export function Badge({ tone = "neutral", icon, children }: BadgeProps) {
  return (
    <span className={`h-badge h-badge--${tone}`}>
      {icon ? <Icon name={icon} size={12} /> : null}
      {children}
    </span>
  );
}
