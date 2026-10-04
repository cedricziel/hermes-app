import { Tag } from "../Tag/Tag";
import { cx } from "../../platform";
import "./McpCatalogRow.css";

/** A credential a catalog entry asks for before it can be installed. */
export interface McpCredential {
  /** The environment variable Hermes stores it in: "AIRTABLE_API_KEY". Labels the field. */
  name: string;
  /** What to paste, under the field: "Personal access token". */
  prompt: string;
  /** Install waits for it. An optional one adds "(optional)" to its prompt. Default true. */
  required?: boolean;
}

/** An entry of Hermes' approved MCP catalog. */
export interface McpCatalogEntry {
  /** Server name, e.g. "airtable". Its first letter fills the avatar. */
  name: string;
  /** What it does. Two lines in the row, then ellipsis. */
  description?: string;
  /** Where the entry comes from, a small line in the install panel: "github.com/airtable/mcp". */
  source?: string;
  /** `remote`: Hermes connects to `url`. `command`: Hermes runs `command` with `args`. Leave out when the catalog does not say, which the install panel warns about. */
  transport?: "remote" | "command";
  /** How it signs in, as labelled: "API key", "OAuth", "No auth". */
  auth?: string;
  /** Address of a remote entry. */
  url?: string;
  /** Program of a command entry: "node", "npx". */
  command?: string;
  /** Its arguments, in order. */
  args?: string[];
  /** For an entry Hermes builds on the server: the repository it clones. Adds a "Builds locally" tag. */
  repository?: string;
  /** The git reference it checks out: "v1.2.0". */
  ref?: string;
  /** The build steps Hermes runs after cloning: ["npm ci", "npm run build"]. */
  buildSteps?: string[];
  /** Credentials the entry declares; the install panel draws a secret field for each. */
  credentials?: McpCredential[];
  /** Already on the profile: an "Installed" tag, and it opens the server's detail instead of the install panel. */
  installed?: boolean;
}

export interface McpCatalogRowProps {
  /** The catalog entry to show. */
  entry: McpCatalogEntry;
  /** Hermes is building this entry on the server: adds a "Building" tag. */
  building?: boolean;
  /** Highlighted as the entry open in the pane beside the list (wide layout). */
  selected?: boolean;
  /** The row was clicked: open the install panel (or the server, when installed). */
  onClick?: () => void;
}

/**
 * One entry in the MCP catalog list: a letter avatar, the name, a two-line
 * description and tinted tags for transport, auth, "Builds locally",
 * "Installed" and "Building". Full-width and borderless like `McpServerRow`;
 * stack rows directly under the catalog's search field and filter chips.
 * The same on every platform.
 */
export function McpCatalogRow({
  entry,
  building = false,
  selected = false,
  onClick,
}: McpCatalogRowProps) {
  const tags = [
    entry.transport === "remote"
      ? "Remote"
      : entry.transport === "command"
        ? "Command"
        : null,
    entry.auth,
    entry.repository ? "Builds locally" : null,
    entry.installed ? "Installed" : null,
    building ? "Building" : null,
  ].filter((t): t is string => Boolean(t));
  return (
    <div
      className={cx(
        "h-mcp-catalog-row",
        selected && "h-mcp-catalog-row--selected",
      )}
      role="button"
      tabIndex={0}
      aria-pressed={selected}
      onClick={onClick}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onClick?.();
        }
      }}
    >
      <span className="h-mcp-catalog-row__avatar" aria-hidden>
        {entry.name.charAt(0).toUpperCase()}
      </span>
      <div className="h-mcp-catalog-row__body">
        <div className="h-mcp-catalog-row__name">{entry.name}</div>
        {entry.description ? (
          <div className="h-mcp-catalog-row__description">
            {entry.description}
          </div>
        ) : null}
        {tags.length > 0 ? (
          <div className="h-mcp-catalog-row__tags">
            {tags.map((t) => (
              <Tag key={t} variant="tinted">
                {t}
              </Tag>
            ))}
          </div>
        ) : null}
      </div>
    </div>
  );
}
