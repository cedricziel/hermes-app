import type { CSSProperties } from "react";
import { cx, usePlatform, type Platform } from "../../platform";
import {
  cupertinoGlyphs,
  materialToCupertino,
  type CupertinoIconName,
} from "./cupertinoIcons";
import "./Icon.css";

export interface IconProps {
  /** Material Symbols name, snake_case as in Flutter's `Icons.*`: `arrow_upward`, `chat_bubble`, `schedule`. The same name works under `platform="apple"`, which draws the CupertinoIcons glyph the app pairs with it. */
  name: string;
  /** Pixel size; the app uses 16 (inline), 20 (rows) and 24 (buttons). */
  size?: number;
  /** Filled glyph, like Flutter's plain `Icons.x`; outlined matches `Icons.x_outlined`. On Apple it picks the paired glyph of the filled Material icon (`check_circle` filled is a solid circle). */
  filled?: boolean;
  /** CSS color; defaults to the current text color. */
  color?: string;
  /**
   * `material` (default): Material Symbols Outlined, weight 400. `apple`: the
   * CupertinoIcons glyph (SF Symbols style) the app draws on iOS and macOS,
   * from its own Material-to-Apple pairs (AppIcons): `more_vert` and
   * `more_horiz` become the horizontal ellipsis, `delete` a trash can,
   * `schedule` a clock. A name the app has no pair for keeps its Material
   * glyph, as it does in the app. Inherits the provider's platform.
   */
  platform?: Platform;
  /**
   * The Apple glyph by Flutter's `CupertinoIcons.*` name, for spots where the
   * app draws a Cupertino icon with no Material twin (`back`, the navigation
   * bar's back chevron; `checkmark`, the menu's selected mark). `false` keeps
   * the Material glyph on Apple too, for spots the app draws with Material
   * icons everywhere (code block headers, expansion chevrons).
   */
  apple?: CupertinoIconName | false;
  /** Accessible name; without it the icon is decorative. */
  label?: string;
  className?: string;
  style?: CSSProperties;
}

/**
 * Material Symbols names whose icon the app draws as a differently named
 * Flutter `Icons.*` glyph, so the pairing finds them.
 */
const flutterNames: Record<string, string> = {
  draft: "insert_drive_file",
  left_panel_close: "view_sidebar",
  left_panel_open: "view_sidebar",
  person_add: "person_add_alt",
  warning: "warning_amber",
};

/** The paired Apple glyph for a Material name, trying the outlined variants first unless `filled`. */
function appleGlyph(symbol: string, filled: boolean): CupertinoIconName | null {
  const name = flutterNames[symbol] ?? symbol;
  const outlined =
    materialToCupertino[`${name}_outlined`] ??
    materialToCupertino[`${name}_outline`];
  const plain = materialToCupertino[name];
  return (filled ? (plain ?? outlined) : (outlined ?? plain)) ?? null;
}

/**
 * An icon in the platform's set: Material Symbols on Android, Windows and
 * Linux, the paired CupertinoIcons glyph on iOS and macOS (see `platform`).
 */
export function Icon({
  name,
  size = 24,
  filled = false,
  color,
  platform,
  apple,
  label,
  className,
  style,
}: IconProps) {
  const isApple = usePlatform(platform) === "apple";
  const glyph =
    isApple && apple !== false ? (apple ?? appleGlyph(name, filled)) : null;
  return (
    <span
      className={cx("h-icon", glyph && "h-icon--apple", className)}
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      style={{
        fontSize: size,
        width: size,
        height: size,
        color,
        fontVariationSettings: glyph
          ? undefined
          : `'FILL' ${filled ? 1 : 0}, 'wght' 400, 'GRAD' 0, 'opsz' ${Math.min(48, Math.max(20, size))}`,
        ...style,
      }}
    >
      {glyph ? String.fromCodePoint(cupertinoGlyphs[glyph]) : name}
    </span>
  );
}
