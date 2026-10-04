import type { ReactNode } from "react";
import "./SectionHeader.css";

export interface SectionHeaderProps {
  /** The heading. `overline` sets it in small spaced capitals ("Tools · 4" reads "TOOLS · 4"). */
  title: string;
  /** `title` only: a muted line under the heading, "Where the agent keeps long-term memory". */
  caption?: string;
  /**
   * `title`: a 16px heading with an optional caption, padded 16px at the sides
   * and 20px above, that opens a section of a full-width list (the Providers
   * tab's "Memory provider"). `overline`: an 11px label with letter spacing
   * and no padding, over a card or a group of fields in a padded pane.
   * `label`: a 14px medium label with no padding, over a control in a form
   * ("Authentication", "Environment variables", "Tools").
   */
  variant?: "title" | "overline" | "label";
  /** Trailing content on the heading's line, e.g. a text button. */
  action?: ReactNode;
}

/**
 * The heading of a group in a list, a detail pane or a form. Pick the
 * `variant` by where it sits; it is the same on every platform.
 */
export function SectionHeader({
  title,
  caption,
  variant = "title",
  action,
}: SectionHeaderProps) {
  return (
    <div className={`h-section-header h-section-header--${variant}`}>
      <div className="h-section-header__text">
        <div className="h-section-header__title">{title}</div>
        {caption && variant === "title" ? (
          <div className="h-section-header__caption">{caption}</div>
        ) : null}
      </div>
      {action}
    </div>
  );
}
