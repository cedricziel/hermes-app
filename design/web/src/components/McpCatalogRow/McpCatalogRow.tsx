import { GroupedRow, GroupedTile } from "../GroupedRow/GroupedRow";
import type { AppleDevice, Platform } from "../../platform";

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
  /** Server name, e.g. "airtable". Its first letter fills the leading tile. */
  name: string;
  /** What it does: the row's one-line subtitle. */
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
  /** For an entry Hermes builds on the server: the repository it clones. Adds "Builds locally" to the facts line. */
  repository?: string;
  /** The git reference it checks out: "v1.2.0". */
  ref?: string;
  /** The build steps Hermes runs after cloning: ["npm ci", "npm run build"]. */
  buildSteps?: string[];
  /** Credentials the entry declares; the install panel draws a secret field for each. */
  credentials?: McpCredential[];
  /** Already on the profile: "Installed" in the facts line, and it opens the server's detail instead of the install panel. */
  installed?: boolean;
}

export interface McpCatalogRowProps {
  /** The catalog entry to show. */
  entry: McpCatalogEntry;
  /** Hermes is building this entry on the server: adds "Building" to the facts line. */
  building?: boolean;
  /** Highlighted as the entry open in the pane beside the list (wide layout). */
  selected?: boolean;
  /** The row was clicked: open the install panel (or the server, when installed). */
  onClick?: () => void;
  /** iOS: 17px name, 15px description, 13px facts, 29px tile. Mac: 13 / 11 / 11px, 24px tile. Material: 16 / 14 / 13px, 32px tile. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited from the enclosing `SettingsScaffold` or `GroupedListView`. */
  device?: AppleDevice;
}

/**
 * One entry in the MCP catalog's group (a `GroupedSection` with
 * `dividerIndent="tile"`): its initial in a `GroupedTile`, the name, the
 * description on one line and a muted facts line such as "Remote · OAuth ·
 * Installed" (transport, auth, "Builds locally", "Installed", "Building"),
 * with a disclosure chevron.
 */
export function McpCatalogRow({
  entry,
  building = false,
  selected = false,
  onClick,
  platform,
  device,
}: McpCatalogRowProps) {
  const facts = [
    entry.transport === "remote"
      ? "Remote"
      : entry.transport === "command"
        ? "Command"
        : null,
    entry.auth,
    entry.repository ? "Builds locally" : null,
    entry.installed ? "Installed" : null,
    building ? "Building" : null,
  ]
    .filter(Boolean)
    .join(" · ");
  return (
    <GroupedRow
      title={entry.name}
      leading={
        <GroupedTile platform={platform} device={device}>
          {entry.name.charAt(0).toUpperCase()}
        </GroupedTile>
      }
      subtitle={entry.description || undefined}
      caption={facts || undefined}
      selected={selected}
      onClick={onClick ?? (() => {})}
      platform={platform}
      device={device}
    />
  );
}
