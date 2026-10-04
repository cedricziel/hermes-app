import type { ReactNode } from "react";
import { cx } from "../../platform";
import "./RadioRow.css";

export interface RadioRowProps {
  /** The choice: "Built-in", "honcho", "compressor". */
  title: string;
  /** Next to the title, usually a `Tag`: "Ready" (filled), "Needs setup". */
  titleTrailing?: ReactNode;
  /** What the choice means, in muted text under the title. Two lines, then ellipsis. */
  subtitle?: string;
  /** The picked choice of its group. */
  selected?: boolean;
  /** Greyed out and not pickable: a provider the server reports as not ready. */
  disabled?: boolean;
  /** The row was clicked. */
  onSelect?: () => void;
  /** Shown under the row, indented to line up with the title: what a choice that is not ready needs. */
  children?: ReactNode;
}

/**
 * One choice of a single-choice list, as Flutter's `RadioListTile`: a leading
 * 20px radio, a title with an optional trailing tag and a muted subtitle,
 * 16px side padding. Stack rows directly, one group per section under a
 * `SectionHeader`. It is the Material radio on every platform, as in the app
 * (the Plugins Providers tab).
 */
export function RadioRow({
  title,
  titleTrailing,
  subtitle,
  selected = false,
  disabled = false,
  onSelect,
  children,
}: RadioRowProps) {
  return (
    <>
      <div
        role="radio"
        aria-checked={selected}
        aria-disabled={disabled || undefined}
        tabIndex={disabled ? -1 : 0}
        className={cx(
          "h-radio-row",
          selected && "h-radio-row--selected",
          disabled && "h-radio-row--disabled",
        )}
        onClick={() => {
          if (!disabled) onSelect?.();
        }}
        onKeyDown={(e) => {
          if (!disabled && (e.key === "Enter" || e.key === " ")) {
            e.preventDefault();
            onSelect?.();
          }
        }}
      >
        <span className="h-radio-row__radio" aria-hidden />
        <div className="h-radio-row__text">
          <div className="h-radio-row__title">
            <span className="h-radio-row__name">{title}</span>
            {titleTrailing}
          </div>
          {subtitle ? (
            <div className="h-radio-row__subtitle">{subtitle}</div>
          ) : null}
        </div>
      </div>
      {children ? <div className="h-radio-row__extra">{children}</div> : null}
    </>
  );
}
