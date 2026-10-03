import type { CSSProperties, ReactNode } from "react";
import "../../styles/tokens.css";
import "../../styles/base.css";

export interface HermesProviderProps {
  /** Light (default) or dark palette for everything inside. */
  theme?: "light" | "dark";
  /** Fill the parent's height, as an app screen does. */
  fill?: boolean;
  className?: string;
  style?: CSSProperties;
  children?: ReactNode;
}

/**
 * Root wrapper for every Hermes screen or component: sets the theme tokens
 * (`--h-*`), the system font and the page background. Components rendered
 * outside it fall back to the light tokens but miss the font and background.
 */
export function HermesProvider({
  theme = "light",
  fill = false,
  className,
  style,
  children,
}: HermesProviderProps) {
  return (
    <div
      className={["h-root", className].filter(Boolean).join(" ")}
      data-hermes-theme={theme}
      style={fill ? { minHeight: "100%", height: "100%", ...style } : style}
    >
      {children}
    </div>
  );
}
