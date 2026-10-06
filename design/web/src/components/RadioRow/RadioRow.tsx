import {
  Children,
  createContext,
  isValidElement,
  useContext,
  type KeyboardEvent,
  type ReactNode,
} from "react";
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
  /** The row was clicked, or reached with the arrow keys inside a `RadioGroup`. */
  onSelect?: () => void;
  /** Shown under the row, indented to line up with the title: what a choice that is not ready needs. */
  children?: ReactNode;
}

export interface RadioGroupProps {
  /** The group's accessible name, usually the `SectionHeader` above it: "Memory provider". */
  label: string;
  /** The `RadioRow`s, top to bottom. */
  children?: ReactNode;
}

/** Inside a `RadioGroup`: whether this row is the group's one Tab stop. */
const RovingTab = createContext<boolean | undefined>(undefined);

/**
 * One choice of a single-choice list, as Flutter's `RadioListTile`: a leading
 * 20px radio, a title with an optional trailing tag and a muted subtitle,
 * 16px side padding. Stack rows inside a `RadioGroup`, one group per
 * section under a `SectionHeader`. It is the Material radio on every
 * platform, as in the app (the Plugins Providers tab).
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
  const tabStop = useContext(RovingTab);
  return (
    <>
      <div
        role="radio"
        aria-checked={selected}
        aria-disabled={disabled || undefined}
        tabIndex={disabled || tabStop === false ? -1 : 0}
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

const keys: Record<string, 1 | -1> = {
  ArrowDown: 1,
  ArrowRight: 1,
  ArrowUp: -1,
  ArrowLeft: -1,
};

/**
 * Groups `RadioRow`s into one radio group: a single Tab stop (the picked
 * row, else the first enabled one), and the arrow keys move to and pick the
 * next or previous enabled row, as the platform's radio groups do.
 */
export function RadioGroup({ label, children }: RadioGroupProps) {
  const rows = Children.toArray(children).filter(isValidElement<RadioRowProps>);
  const picked = rows.findIndex((r) => r.props.selected && !r.props.disabled);
  const stop = picked >= 0 ? picked : rows.findIndex((r) => !r.props.disabled);

  const move = (e: KeyboardEvent<HTMLDivElement>) => {
    const step = keys[e.key];
    if (!step) return;
    const radios = Array.from(
      e.currentTarget.querySelectorAll<HTMLElement>(
        '[role="radio"]:not([aria-disabled="true"])',
      ),
    );
    const at = radios.indexOf(document.activeElement as HTMLElement);
    if (at < 0 || radios.length === 0) return;
    e.preventDefault();
    const next = radios[(at + step + radios.length) % radios.length];
    next.focus();
    next.click();
  };

  return (
    <div role="radiogroup" aria-label={label} onKeyDown={move}>
      {rows.map((row, i) => (
        <RovingTab.Provider key={row.key ?? i} value={i === stop}>
          {row}
        </RovingTab.Provider>
      ))}
    </div>
  );
}
