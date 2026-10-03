import type { CSSProperties } from "react";
import "./Icon.css";

export interface IconProps {
  /** Material Symbols name, snake_case as in Flutter's `Icons.*`: `arrow_upward`, `chat_bubble`, `schedule`. */
  name: string;
  /** Pixel size; the app uses 16 (inline), 20 (rows) and 24 (buttons). */
  size?: number;
  /** Filled glyph, like Flutter's plain `Icons.x`; outlined matches `Icons.x_outlined`. */
  filled?: boolean;
  /** CSS color; defaults to the current text color. */
  color?: string;
  /** Accessible name; without it the icon is decorative. */
  label?: string;
  className?: string;
  style?: CSSProperties;
}

/** A Material Symbols glyph, the icon set the Flutter app uses. */
export function Icon({
  name,
  size = 24,
  filled = false,
  color,
  label,
  className,
  style,
}: IconProps) {
  return (
    <span
      className={["h-icon", className].filter(Boolean).join(" ")}
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      style={{
        fontSize: size,
        width: size,
        height: size,
        color,
        fontVariationSettings: `'FILL' ${filled ? 1 : 0}, 'wght' 400, 'GRAD' 0, 'opsz' ${Math.min(48, Math.max(20, size))}`,
        ...style,
      }}
    >
      {name}
    </span>
  );
}
