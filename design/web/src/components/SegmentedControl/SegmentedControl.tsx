import { cx, usePlatform, type Platform } from "../../platform";
import "./SegmentedControl.css";

export interface SegmentedControlProps {
  /** The views to switch between, in order: `["Installed", "Catalog", "Providers"]`. */
  labels: string[];
  /** Index of the selected view. */
  value: number;
  /** Called with the index the user picks. */
  onChange?: (index: number) => void;
  /** Accessible name of the group, e.g. "Plugins". */
  label?: string;
  /**
   * `material`: a 48px tab bar across the full width, a 3px primary underline
   * under the selected label and a hairline under the bar. `apple` (iOS and
   * macOS alike, as the app's `CupertinoSlidingSegmentedControl`): a 32px
   * tinted track 16px in from the edges, the selected segment a raised
   * surface-colored thumb. Inherits the provider's platform.
   */
  platform?: Platform;
  className?: string;
}

/**
 * Switches between views of the same content, under a screen's bar: the
 * Plugins screen's Installed, Catalog and Providers, or any list with tabs.
 * Use it instead of drawing tabs; `ListDetailLayout` draws one from its
 * `tabs`.
 */
export function SegmentedControl({
  labels,
  value,
  onChange,
  label,
  platform,
  className,
}: SegmentedControlProps) {
  const apple = usePlatform(platform) === "apple";
  return (
    <div
      className={cx(
        "h-segmented",
        apple ? "h-segmented--apple" : "h-segmented--material",
        className,
      )}
    >
      <div className="h-segmented__track" role="tablist" aria-label={label}>
        {labels.map((text, i) => (
          <button
            key={text}
            type="button"
            role="tab"
            aria-selected={i === value}
            className={cx(
              "h-segmented__segment",
              i === value && "h-segmented__segment--selected",
            )}
            onClick={() => onChange?.(i)}
          >
            <span className="h-segmented__label">{text}</span>
          </button>
        ))}
      </div>
    </div>
  );
}
