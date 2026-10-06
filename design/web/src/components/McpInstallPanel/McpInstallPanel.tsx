import { Banner } from "../Banner/Banner";
import { Button } from "../Button/Button";
import { Card } from "../Card/Card";
import { FactList, type Fact } from "../FactList/FactList";
import { SectionHeader } from "../SectionHeader/SectionHeader";
import { Spinner } from "../Spinner/Spinner";
import { SwitchRow } from "../SwitchRow/SwitchRow";
import { TextField } from "../TextField/TextField";
import type { McpCatalogEntry } from "../McpCatalogRow/McpCatalogRow";
import { PlatformScope, usePlatform, type Platform } from "../../platform";
import "./McpInstallPanel.css";

export interface McpInstallPanelProps {
  /** The catalog entry to install. */
  entry: McpCatalogEntry;
  /** The profile it installs into; the button reads `Install on "work"`. */
  profile?: string;
  /**
   * `idle`: the form. `installing`: the request is out, the button spins.
   * `building`: Hermes is building the entry on the server ("Building on
   * your server…" with a spinner; the app polls the build). `failed`: a red
   * banner with `failure` and the build log.
   */
  state?: "idle" | "installing" | "building" | "failed";
  /** `failed`: what went wrong, "npm ci exited with 1", and the last lines of the build log. */
  failure?: { message: string; log?: string[] };
  /** What the user typed into each credential field, by variable name; drawn masked. A required one left empty keeps Install disabled. */
  credentials?: Record<string, string>;
  /** "Turn on after installing". Default on. */
  enableAfterInstall?: boolean;
  /** The switch was flipped. */
  onEnableAfterInstallChange?: (enable: boolean) => void;
  /** A credential field changed. */
  onCredentialChange?: (name: string, value: string) => void;
  /** Install was pressed. */
  onInstall?: () => void;
  /** Spinners and the switch follow the platform; the layout is the same. Inherits the provider's platform. */
  platform?: Platform;
}

function runFacts(entry: McpCatalogEntry): Fact[] {
  const facts: Fact[] = [];
  if (entry.transport === "remote")
    facts.push({ label: "type", value: "remote (http)" });
  if (entry.transport === "command")
    facts.push({ label: "type", value: "command (stdio)" });
  if (entry.url) facts.push({ label: "url", value: entry.url });
  if (entry.command) facts.push({ label: "command", value: entry.command });
  if (entry.args?.length)
    facts.push({ label: "args", value: entry.args.join(" ") });
  if (entry.auth) facts.push({ label: "auth", value: entry.auth });
  if (entry.repository) {
    facts.push({ label: "repository", value: entry.repository });
    if (entry.ref) facts.push({ label: "ref", value: entry.ref });
    if (entry.buildSteps?.length)
      facts.push({ label: "steps", value: entry.buildSteps });
  }
  return facts;
}

/**
 * What installing an MCP catalog entry involves, and the form to do it:
 * "What Hermes will run" (type, URL or command, auth, and for entries built
 * on the server the repository, ref and build steps), a secret field for each
 * credential the entry declares, "Turn on after installing" and the filled
 * Install button. Put it in a `Sheet` on a phone, or in the right-hand pane
 * of `McpCatalogScreen` from 900px. Credentials are never shown again after
 * the install.
 */
export function McpInstallPanel({
  entry,
  profile,
  state = "idle",
  failure,
  credentials = {},
  enableAfterInstall = true,
  onEnableAfterInstallChange,
  onCredentialChange,
  onInstall,
  platform,
}: McpInstallPanelProps) {
  const resolved = usePlatform(platform);
  const busy = state === "installing" || state === "building";
  const fields = entry.credentials ?? [];
  const filled = fields.every(
    (c) => c.required === false || Boolean(credentials[c.name]),
  );
  const hasTarget = Boolean(entry.url || entry.command || entry.repository);
  return (
    <PlatformScope platform={resolved}>
      <div className="h-mcp-install">
        <div className="h-title-lg">Install {entry.name}</div>
        {entry.description ? (
          <div className="h-body-md h-mcp-install__gap-4">
            {entry.description}
          </div>
        ) : null}
        {entry.source ? (
          <div className="h-body-sm h-muted h-mcp-install__gap-4">
            {entry.source}
          </div>
        ) : null}
        <div className="h-mcp-install__section">
          <div className="h-title-sm">What Hermes will run</div>
          <Card padding={12}>
            <FactList facts={runFacts(entry)} />
          </Card>
          {entry.transport === undefined ? (
            <Banner
              tone="warning"
              icon="warning"
              title="Hermes did not say how this server connects."
            />
          ) : null}
          {entry.repository ? (
            <div className="h-body-sm h-muted">
              The build runs on your Hermes server, not on this device, and can
              take a while.
            </div>
          ) : null}
        </div>
        {fields.length > 0 ? (
          <div className="h-mcp-install__section">
            <SectionHeader variant="overline" title="Credentials" />
            {fields.map((c) => (
              <TextField
                key={c.name}
                type="password"
                label={c.name}
                helper={
                  c.required === false ? `${c.prompt} (optional)` : c.prompt
                }
                value={credentials[c.name] ?? ""}
                readOnly={busy}
                onChange={(e) => onCredentialChange?.(c.name, e.target.value)}
              />
            ))}
            <div className="h-body-sm h-muted">
              Saved on your Hermes server. It is never shown again.
            </div>
          </div>
        ) : null}
        <div className="h-mcp-install__switch">
          <SwitchRow
            title="Turn on after installing"
            checked={enableAfterInstall}
            disabled={busy}
            onChange={onEnableAfterInstallChange}
          />
        </div>
        {state === "building" ? (
          <div className="h-mcp-install__building">
            <Spinner size={16} label="Building" />
            <span className="h-body-md">Building on your server…</span>
          </div>
        ) : null}
        {state === "failed" && failure ? (
          <div className="h-mcp-install__failure">
            <Banner tone="error" icon="error" title={failure.message} />
            {failure.log?.length ? (
              <pre className="h-mcp-install__log">{failure.log.join("\n")}</pre>
            ) : null}
          </div>
        ) : null}
        <Button
          fullWidth
          className="h-mcp-install__button"
          disabled={busy || !filled || !hasTarget}
          onClick={onInstall}
        >
          {state === "installing" ? (
            <Spinner size={18} color="var(--h-muted)" label="Installing" />
          ) : profile ? (
            `Install on "${profile}"`
          ) : (
            "Install"
          )}
        </Button>
      </div>
    </PlatformScope>
  );
}
