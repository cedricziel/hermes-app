import { Icon } from "../Icon/Icon";
import { cx } from "../../platform";
import "./SegmentedButton.css";

export interface SegmentedButtonProps {
  /** The choices, in order: `["Remote (URL)", "Command"]`. */
  labels: string[];
  /** Index of the picked choice. */
  value: number;
  /** Called with the index the user picks. */
  onChange?: (index: number) => void;
  /** Read-only while a request runs. */
  disabled?: boolean;
  /** Accessible name of the group: "Server type", "Authentication". */
  label?: string;
}

/**
 * A single choice between a few options inside a form, as Flutter's Material
 * 3 `SegmentedButton`, which the app draws the same on every platform: a
 * 40px outlined pill split into segments that share the width (a longer
 * label, or the picked one with its check, gets the room it needs), the
 * picked one tinted with a check before its label. Use it for "Remote (URL)" / "Command" or the
 * authentication kind. To switch between views of a screen use
 * `SegmentedControl` instead.
 */
export function SegmentedButton({
  labels,
  value,
  onChange,
  disabled = false,
  label,
}: SegmentedButtonProps) {
  return (
    <div
      role="radiogroup"
      aria-label={label}
      className={cx("h-segbutton", disabled && "h-segbutton--disabled")}
    >
      {labels.map((text, i) => (
        <button
          key={text}
          type="button"
          role="radio"
          aria-checked={i === value}
          disabled={disabled}
          className={cx(
            "h-segbutton__segment",
            i === value && "h-segbutton__segment--selected",
          )}
          onClick={() => onChange?.(i)}
        >
          {i === value ? <Icon name="check" size={18} apple={false} /> : null}
          <span className="h-segbutton__label">{text}</span>
        </button>
      ))}
    </div>
  );
}
