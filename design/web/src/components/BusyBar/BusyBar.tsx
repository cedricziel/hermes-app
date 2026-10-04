import "./BusyBar.css";

export interface BusyBarProps {
  /** Progress from 0 to 1. Leave out for an indeterminate bar that slides while the work runs. */
  value?: number;
  /** Bar height in px. Default 4, as Flutter's LinearProgressIndicator. */
  height?: number;
  /** Accessible name, e.g. "Installing web-scraper". Default "In progress". */
  label?: string;
}

/**
 * A thin linear progress bar (the app's `BusyBar`): a skill install or update
 * running, the job bar under the Skills screen's tabs. Without `value` it
 * slides; under `prefers-reduced-motion` it stops and shows a still, dimmed
 * full bar. The same on every platform.
 */
export function BusyBar({
  value,
  height = 4,
  label = "In progress",
}: BusyBarProps) {
  const indeterminate = value === undefined;
  return (
    <div
      className={
        indeterminate ? "h-busy-bar h-busy-bar--indeterminate" : "h-busy-bar"
      }
      role="progressbar"
      aria-label={label}
      aria-valuemin={indeterminate ? undefined : 0}
      aria-valuemax={indeterminate ? undefined : 100}
      aria-valuenow={
        indeterminate ? undefined : Math.round(Math.min(1, value) * 100)
      }
      style={{ height }}
    >
      <div
        className="h-busy-bar__value"
        style={
          indeterminate
            ? undefined
            : { width: `${Math.max(0, Math.min(1, value)) * 100}%` }
        }
      />
    </div>
  );
}
