import type { CSSProperties } from "react";
import { cx, usePlatform, type Platform } from "../../platform";
import "./Spinner.css";

export interface SpinnerProps {
  /** Diameter in px: 12 to 16 inline (a tool call, a button, a row), 20 for a field, 36 to 40 for a screen that is loading. Default 20. */
  size?: number;
  /** Material ring width in px. Defaults to a tenth of `size`, at least 2. Ignored under `apple`. */
  strokeWidth?: number;
  /** A CSS color or token, e.g. `var(--h-muted)`. Defaults to `--h-primary` on Material and `--h-muted` under `apple`, as Flutter's adaptive indicator draws them. */
  color?: string;
  /** Accessible name, e.g. "Installing". Default "Loading". */
  label?: string;
  /**
   * `material`: a three-quarter ring turning. `apple`: the activity
   * indicator, eight spokes fading round (iOS and macOS). Both stand still
   * when the system asks to reduce motion. Inherits the provider's platform.
   */
  platform?: Platform;
  className?: string;
  style?: CSSProperties;
}

const SPOKES = 8;

/**
 * The busy indicator, wherever the app waits: a running tool call, a reply
 * that is thinking, a connecting screen, an installing plugin, a loading
 * panel. Use it instead of drawing a ring.
 */
export function Spinner({
  size = 20,
  strokeWidth,
  color,
  label = "Loading",
  platform,
  className,
  style,
}: SpinnerProps) {
  const apple = usePlatform(platform) === "apple";
  const box: CSSProperties = { width: size, height: size, color, ...style };
  if (apple) {
    const spoke = Math.max(1.5, size / 10);
    return (
      <span
        role="progressbar"
        aria-label={label}
        className={cx("h-spinner", "h-spinner--apple", className)}
        style={box}
      >
        {Array.from({ length: SPOKES }, (_, i) => (
          <span
            key={i}
            className="h-spinner__spoke"
            style={{
              width: spoke,
              marginLeft: -spoke / 2,
              transform: `rotate(${(360 / SPOKES) * i}deg)`,
              opacity: 1 - ((SPOKES - i) % SPOKES) * 0.1,
            }}
          />
        ))}
      </span>
    );
  }
  return (
    <span
      role="progressbar"
      aria-label={label}
      className={cx("h-spinner", "h-spinner--material", className)}
      style={{
        ...box,
        borderWidth: strokeWidth ?? Math.max(2, Math.round(size / 10)),
      }}
    />
  );
}
