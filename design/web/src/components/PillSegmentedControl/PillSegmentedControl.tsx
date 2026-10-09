import { cx } from "../../platform";
import "./PillSegmentedControl.css";

export interface PillSegmentedControlProps {
  /** The segments in order: `["Installed", "Catalog", "Providers"]`, `["Low", "Medium", "High"]`. */
  labels: string[];
  /** Index of the selected segment. */
  value: number;
  /** Called with the index the user picks. */
  onChange?: (index: number) => void;
  /** Accessible name of the group: "Plugins". */
  label?: string;
  className?: string;
}

/**
 * Material's segmented control as a pill (Material only; Apple draws
 * `SegmentedControl`): a 36px stadium track in the tinted surface, the
 * segments sharing its width, the selected one on a surface-colored thumb
 * with a 1px border in 14px semibold, the rest 14px medium at 70%. The tabs
 * of a Material `SettingsScaffold` and the choice of a Material
 * `GroupedSegmentedRow`. Fills its parent's width.
 */
export function PillSegmentedControl({
  labels,
  value,
  onChange,
  label,
  className,
}: PillSegmentedControlProps) {
  return (
    <div
      className={cx("h-pill-segmented", className)}
      role="tablist"
      aria-label={label}
    >
      {labels.map((text, i) => (
        <button
          key={text}
          type="button"
          role="tab"
          aria-selected={i === value}
          className={cx(
            "h-pill-segmented__segment",
            i === value && "h-pill-segmented__segment--selected",
          )}
          onClick={() => onChange?.(i)}
        >
          {text}
        </button>
      ))}
    </div>
  );
}
