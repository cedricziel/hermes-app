import { Banner } from "../Banner/Banner";
import { Button } from "../Button/Button";
import { Card } from "../Card/Card";
import { IconButton } from "../IconButton/IconButton";
import { SectionHeader } from "../SectionHeader/SectionHeader";
import { Spinner } from "../Spinner/Spinner";
import { SwitchRow } from "../SwitchRow/SwitchRow";
import type { McpServer } from "../McpServerRow/McpServerRow";
import { PlatformScope, usePlatform, type Platform } from "../../platform";
import "./McpServerDetail.css";

/** A tool an MCP server listed in its last connection test. */
export interface McpTool {
  /** The tool's name, in monospace: "search_dashboards". */
  name: string;
  /** What it does: "Find dashboards by title or tag." */
  description?: string;
  /** What its schema costs the model in context, in characters; shown as "320 chars" or "1.4k chars". */
  schemaChars?: number;
}

/**
 * The state of a server's connection test, as the detail shows it.
 * `running`: the Test button spins. `unavailable`: Hermes could not run the
 * test (a red banner with Retry). `signInNeeded`: an orange banner with Sign
 * in. `failed`: a red "Could not connect" banner with `error`. `connected`: a
 * green banner with the counts and the tool list.
 */
export type McpServerTestState =
  | { status: "running" }
  | { status: "unavailable" }
  | { status: "signInNeeded" }
  | { status: "failed"; error?: string }
  | {
      status: "connected";
      tools: McpTool[];
      prompts?: number;
      resources?: number;
    };

export interface McpServerDetailProps {
  /** The server to show. A server whose `auth` is "OAuth" gets a Sign in button. */
  server: McpServer;
  /** The last connection test, if any. */
  test?: McpServerTestState;
  /** Why the last sign-in could not start, as a red banner: "A sign-in to grafana is already in progress". */
  signInNote?: string;
  /** A switch request is in flight: the Enabled switch is disabled. */
  switching?: boolean;
  /** A sign-in is starting: Sign in spins and is disabled. */
  startingSignIn?: boolean;
  /** The Enabled switch was flipped. */
  onEnabledChange?: (enabled: boolean) => void;
  /** "Test connection", or Retry after an unavailable test. */
  onTest?: () => void;
  /** The red Remove button. The app asks before removing. */
  onRemove?: () => void;
  /** Sign in (an OAuth server): opens `McpSignInScreen`. */
  onSignIn?: () => void;
  /** Under `apple` the switch is the 51x31 toggle and the spinners the activity indicator; the layout is the same. Inherits the provider's platform. */
  platform?: Platform;
}

function plural(n: number, noun: string) {
  return `${n} ${noun}${n === 1 ? "" : "s"}`;
}

function schemaSize(chars: number) {
  return chars < 1000
    ? `${chars} chars`
    : `${(chars / 1000).toFixed(1)}k chars`;
}

/**
 * One MCP server in full: name, transport and auth, its address, the Enabled
 * switch in a card, Sign in (OAuth servers), Test connection and Remove, and
 * the outcome of the last test with its tools. Fills the right-hand pane of
 * `McpServersScreen` from 900px wide, and the server's own page on a phone
 * (`McpServersScreen openServer`). Scrolls inside its parent.
 */
export function McpServerDetail({
  server,
  test,
  signInNote,
  switching = false,
  startingSignIn = false,
  onEnabledChange,
  onTest,
  onRemove,
  onSignIn,
  platform,
}: McpServerDetailProps) {
  const resolved = usePlatform(platform);
  const auth =
    server.auth || (server.transport === "remote" ? "No auth" : undefined);
  const signInNeeded = test?.status === "signInNeeded";
  const running = test?.status === "running";
  const signInButton = (inBanner: boolean) => (
    <Button
      variant={inBanner ? "text" : "outlined"}
      icon={startingSignIn ? undefined : "login"}
      fullWidth={!inBanner}
      disabled={startingSignIn}
      onClick={onSignIn}
    >
      {startingSignIn ? <Spinner size={16} label="Starting sign-in" /> : null}
      Sign in
    </Button>
  );
  return (
    <PlatformScope platform={resolved}>
      <div className="h-mcp-detail">
        <div className="h-title-lg">{server.name}</div>
        <div className="h-body-sm h-mcp-detail__meta">
          {[server.transport === "remote" ? "Remote" : "Command", auth]
            .filter(Boolean)
            .join(" · ")}
        </div>
        {server.address ? (
          <div className="h-mcp-detail__address">{server.address}</div>
        ) : null}
        <Card padding={0} className="h-mcp-detail__switch">
          <SwitchRow
            title="Enabled"
            subtitle={
              server.enabled
                ? "Used from the next chat"
                : "Not used from the next chat"
            }
            checked={server.enabled}
            disabled={switching}
            onChange={onEnabledChange}
            inset={16}
          />
        </Card>
        <div className="h-mcp-detail__actions">
          {server.auth === "OAuth" && !signInNeeded
            ? signInButton(false)
            : null}
          <div className="h-mcp-detail__test-row">
            <Button
              variant="outlined"
              icon={running ? undefined : "check"}
              fullWidth
              disabled={running}
              onClick={onTest}
            >
              {running ? <Spinner size={16} label="Testing" /> : null}
              Test connection
            </Button>
            <IconButton
              icon="delete"
              label="Remove"
              variant="outlined"
              className="h-mcp-detail__remove"
              onClick={onRemove}
            />
          </div>
        </div>
        <div className="h-mcp-detail__outcome">
          {signInNote ? (
            <Banner tone="error" icon="error" title={signInNote} />
          ) : null}
          {test?.status === "unavailable" ? (
            <Banner
              tone="error"
              icon="error"
              title={`Could not test ${server.name}`}
              action={
                <Button variant="text" onClick={onTest}>
                  Retry
                </Button>
              }
            />
          ) : test?.status === "signInNeeded" ? (
            <Banner
              tone="warning"
              icon="lock"
              title="Sign in needed"
              detail="Hermes has no OAuth token for this server yet, so it cannot list tools."
              action={signInButton(true)}
            />
          ) : test?.status === "failed" ? (
            <Banner
              tone="error"
              icon="error"
              title="Could not connect"
              detail={test.error}
            />
          ) : test?.status === "connected" ? (
            <>
              <Banner
                tone="success"
                icon="check_circle"
                title="Connected"
                detail={[
                  plural(test.tools.length, "tool"),
                  plural(test.prompts ?? 0, "prompt"),
                  plural(test.resources ?? 0, "resource"),
                ].join(" · ")}
              />
              {test.tools.length > 0 ? (
                <div className="h-mcp-detail__tools">
                  <SectionHeader
                    variant="overline"
                    title={`Tools · ${test.tools.length}`}
                  />
                  <Card padding={0}>
                    {test.tools.map((tool) => (
                      <div key={tool.name} className="h-mcp-detail__tool">
                        <div className="h-mcp-detail__tool-text">
                          <div className="h-mcp-detail__tool-name">
                            {tool.name}
                          </div>
                          {tool.description ? (
                            <div className="h-body-md h-muted">
                              {tool.description}
                            </div>
                          ) : null}
                        </div>
                        {tool.schemaChars !== undefined ? (
                          <div className="h-body-sm h-muted">
                            {schemaSize(tool.schemaChars)}
                          </div>
                        ) : null}
                      </div>
                    ))}
                  </Card>
                  <div className="h-body-sm h-muted">
                    The size next to a tool is what its schema costs the model
                    in context. Hermes sends it with a test.
                  </div>
                </div>
              ) : null}
            </>
          ) : null}
        </div>
      </div>
    </PlatformScope>
  );
}
