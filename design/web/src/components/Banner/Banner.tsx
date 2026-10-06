import type { ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import "./Banner.css";

export interface BannerProps {
  /** `success` (green: "Connected"), `warning` (orange: "Sign in needed", "Replaces all servers") or `error` (red: "Could not connect"). Tints the box, its border and the icon. */
  tone: "success" | "warning" | "error";
  /** Material Symbols name of the leading 18px icon: `check_circle`, `lock`, `warning`, `error`. Follows the platform like `Icon`. */
  icon: string;
  /** One bold line saying what happened. */
  title: string;
  /** Optional plain text under the title: the reason or what to do next. */
  detail?: ReactNode;
  /** A trailing action, usually a `Button variant="text"` ("Retry", "Sign in"). */
  action?: ReactNode;
}

/**
 * A tinted box that reports an outcome inline, in a detail pane or a form: a
 * connection test that worked or failed, a sign-in that is needed, a warning
 * before a risky save. 10% tint of the tone with a 35% border, 10px radius, an
 * 18px icon, a bold title, optional detail and a trailing action (the app's
 * `McpBanner`). The same on every platform. Use `StateMessage` for a whole
 * screen with nothing to show.
 */
export function Banner({ tone, icon, title, detail, action }: BannerProps) {
  return (
    <div className={`h-banner h-banner--${tone}`} role="status">
      <Icon name={icon} size={18} className="h-banner__icon" />
      <div className="h-banner__text">
        <div className="h-banner__title">{title}</div>
        {detail ? <div className="h-banner__detail">{detail}</div> : null}
      </div>
      {action ? <div className="h-banner__action">{action}</div> : null}
    </div>
  );
}
