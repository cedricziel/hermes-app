import { cx } from "../../platform";
import "./Tag.css";

export interface TagProps {
  /** The tag's text: "Bundled", "Remote", "OAuth", a commit "a3f9c21". One line, never wraps. */
  children: string;
  /**
   * `outlined`: a hairline pill in muted text, the plugin tags ("Bundled",
   * "Disabled"). `strong`: outlined in the text color, for a fact that needs
   * attention ("Needs login", "Update available"). `filled`: a solid primary
   * pill ("Official", "Enabled", "Installed", "Ready"). `tinted`: a gray
   * filled pill, the MCP facts ("Remote", "OAuth", "4 tools").
   * `warning`: an orange tinted pill ("Sign in needed").
   */
  variant?: "outlined" | "strong" | "filled" | "tinted" | "warning";
  /** Monospace text, for a commit, a tool or an environment variable name. */
  mono?: boolean;
}

/**
 * A small pill (11px text, full radius) that states one fact about a row or a
 * detail: transport and auth of an MCP server, a plugin's status, a provider's
 * readiness. Lay several out in a wrapping row with a 6px gap. Same on every
 * platform. Use `Badge` instead for the square-cornered Kanban and run tags.
 */
export function Tag({
  children,
  variant = "outlined",
  mono = false,
}: TagProps) {
  return (
    <span className={cx("h-tag", `h-tag--${variant}`, mono && "h-tag--mono")}>
      {children}
    </span>
  );
}
