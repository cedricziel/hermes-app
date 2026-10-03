import type { CSSProperties, ReactNode } from "react";
import { PlatformContext, cx, type Platform } from "../../platform";
import "../../styles/tokens.css";
import "../../styles/base.css";

export interface HermesProviderProps {
  /** Light (default) or dark palette for everything inside. */
  theme?: "light" | "dark";
  /**
   * Whose conventions the components inside follow: `material` (default; the
   * look before this prop existed, for Android, Windows and Linux) or `apple`
   * (iOS, iPadOS, macOS). Every component with a `platform` prop reads it
   * from here unless it is given its own. Nest a provider to show both.
   */
  platform?: Platform;
  /**
   * The text ramp. `ios` (the default under `platform="apple"`) uses Apple's
   * sizes: body 17, subheadline 15, footnote 13, caption 12. Pass `default`
   * on a Mac screen, which keeps the compact sizes.
   */
  typeRamp?: "ios" | "default";
  /** Fill the parent's height, as an app screen does. */
  fill?: boolean;
  className?: string;
  style?: CSSProperties;
  children?: ReactNode;
}

/**
 * Root wrapper for every Hermes screen or component: sets the theme tokens
 * (`--h-*`), the system font and the page background, and says which platform
 * look (`material` or `apple`) the components inside use. Components rendered
 * outside it fall back to the light tokens but miss the font and background.
 */
export function HermesProvider({
  theme = "light",
  platform = "material",
  typeRamp,
  fill = false,
  className,
  style,
  children,
}: HermesProviderProps) {
  const ramp = typeRamp ?? (platform === "apple" ? "ios" : "default");
  return (
    <PlatformContext.Provider value={platform}>
      <div
        className={cx("h-root", className)}
        data-hermes-theme={theme}
        data-hermes-platform={platform}
        data-hermes-ramp={ramp}
        style={fill ? { minHeight: "100%", height: "100%", ...style } : style}
      >
        {children}
      </div>
    </PlatformContext.Provider>
  );
}
