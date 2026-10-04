import type { CSSProperties } from "react";
import { cx, usePlatform, type Platform } from "../../platform";
import "./Icon.css";

export interface IconProps {
  /** Material Symbols name, snake_case as in Flutter's `Icons.*`: `arrow_upward`, `chat_bubble`, `schedule`. The same name is used under `platform="apple"`, which swaps it for the closest SF-Symbols-like glyph. */
  name: string;
  /** Pixel size; the app uses 16 (inline), 20 (rows) and 24 (buttons). */
  size?: number;
  /** Filled glyph, like Flutter's plain `Icons.x`; outlined matches `Icons.x_outlined`. */
  filled?: boolean;
  /** CSS color; defaults to the current text color. */
  color?: string;
  /**
   * `material` (default): Material Symbols Outlined, weight 400. `apple`: the
   * Apple set. The app draws CupertinoIcons (SF-Symbols-style) on iOS and
   * macOS; this recreation approximates them with Material Symbols Rounded at
   * weight 300 and swaps a few names for their SF counterparts (`more_vert`
   * becomes the horizontal ellipsis, `arrow_back` a chevron, `send` an up
   * arrow). Inherits the provider's platform.
   */
  platform?: Platform;
  /** Accessible name; without it the icon is decorative. */
  label?: string;
  className?: string;
  style?: CSSProperties;
}

/** Material glyph name to the glyph SF Symbols draws for the same job. Anything not listed keeps its name. */
const appleGlyphs: Record<string, string> = {
  more_vert: "more_horiz",
  arrow_back: "arrow_back_ios_new",
  arrow_forward: "arrow_forward_ios",
  send: "arrow_upward",
  delete_outline: "delete",
  drag_indicator: "drag_handle",
  view_kanban: "view_column",
  power: "cable",
};

/**
 * A Material Symbols glyph, the icon set the Flutter app uses on Android,
 * Windows and Linux. With `platform="apple"` it draws the lighter, rounded
 * Apple approximation instead (see `platform`).
 */
export function Icon({
  name,
  size = 24,
  filled = false,
  color,
  platform,
  label,
  className,
  style,
}: IconProps) {
  const apple = usePlatform(platform) === "apple";
  const glyph = apple ? (appleGlyphs[name] ?? name) : name;
  return (
    <span
      className={cx("h-icon", apple && "h-icon--apple", className)}
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      style={{
        fontSize: size,
        width: size,
        height: size,
        color,
        fontVariationSettings: `'FILL' ${filled ? 1 : 0}, 'wght' ${apple ? 300 : 400}, 'GRAD' 0, 'opsz' ${Math.min(48, Math.max(20, size))}`,
        ...style,
      }}
    >
      {glyph}
    </span>
  );
}
