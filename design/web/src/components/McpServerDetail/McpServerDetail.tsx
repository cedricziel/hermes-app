import { Banner } from "../Banner/Banner";
import { Button } from "../Button/Button";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { GroupedSwitchRow } from "../GroupedSwitchRow/GroupedSwitchRow";
import { Icon } from "../Icon/Icon";
import { Spinner } from "../Spinner/Spinner";
import type { McpServer } from "../McpServerRow/McpServerRow";
import {
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { groupedMetrics } from "../../grouped";
import { mcpFacts, mcpPlural, mcpSchemaSize } from "../../mcp";
import "./McpServerDetail.css";

/** A tool an MCP server listed in its last connection test. */
export interface McpTool {
  /** The tool's name: "search_dashboards". */
  name: string;
  /** What it does: "Find dashboards by title or tag." */
  description?: string;
  /** What its schema costs the model in context, in characters; shown as "320 chars" or "1.4k chars". */
  schemaChars?: number;
}

/**
 * The state of a server's connection test, as the detail shows it.
 * `running`: Test connection shows a spinner in place of its icon.
 * `unavailable`: Hermes could not run the test (a red banner with Retry).
 * `signInNeeded`: an orange banner with Sign in. `failed`: a red "Could not
 * connect" banner with `error`. `connected`: a green banner with the counts
 * and the "Tools" group.
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
  /** The server to show. A server whose `auth` is "OAuth" gets a Sign in row. */
  server: McpServer;
  /** The last connection test, if any. */
  test?: McpServerTestState;
  /** Why the last sign-in could not start, as a red banner: "A sign-in to grafana is already in progress". */
  signInNote?: string;
  /** A switch request is in flight: the Enabled switch is disabled. */
  switching?: boolean;
  /** A sign-in is starting: the Sign in row shows a spinner and is disabled. */
  startingSignIn?: boolean;
  /** The server's name heads the detail (22px semibold). Default true; the phone's server page names it in its bar instead. */
  showName?: boolean;
  /** The Enabled switch was flipped. */
  onEnabledChange?: (enabled: boolean) => void;
  /** The "Test connection" row, or Retry after an unavailable test. */
  onTest?: () => void;
  /** The red Remove row. The app asks before removing. */
  onRemove?: () => void;
  /** Sign in (an OAuth server): opens `McpSignInScreen`. */
  onSignIn?: () => void;
  /** Groups, rows and switches follow the platform: iOS 44px rows and the 51x31 toggle, Mac 40px rows and the small toggle, Material 56px rows. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited from the enclosing `SettingsScaffold`. */
  device?: AppleDevice;
}

/**
 * One MCP server in full, as grouped sections in the settings column: its
 * name, "Remote · OAuth" and its address in monospace; a group with the
 * Enabled switch ("Used from the next chat"); a group of action rows with
 * leading icons (Sign in for OAuth servers, Test connection, Remove in red);
 * the outcome of the last test as a tinted banner; and once connected a
 * "Tools · N" group of tool rows with their schema size as a muted value.
 * Fills the right-hand pane of `McpServersScreen` from 900px wide, and the
 * server's own page on a phone. Scrolls inside its parent.
 */
export function McpServerDetail({
  server,
  test,
  signInNote,
  switching = false,
  startingSignIn = false,
  showName = true,
  onEnabledChange,
  onTest,
  onRemove,
  onSignIn,
  platform,
  device,
}: McpServerDetailProps) {
  const resolved = usePlatform(platform);
  const chrome = useGroupedChrome(resolved, device);
  const leadingSize = groupedMetrics[chrome].titleSize + 5;
  const spinner = (label: string) => (
    <Spinner size={leadingSize - 4} label={label} />
  );
  const signInNeeded = test?.status === "signInNeeded";
  const running = test?.status === "running";
  const tools = test?.status === "connected" ? test.tools : [];
  const outcome =
    test?.status === "unavailable" ? (
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
        action={
          <Button
            variant="text"
            icon={startingSignIn ? undefined : "login"}
            disabled={startingSignIn}
            onClick={onSignIn}
          >
            {startingSignIn ? (
              <Spinner size={16} label="Starting sign-in" />
            ) : null}
            Sign in
          </Button>
        }
      />
    ) : test?.status === "failed" ? (
      <Banner
        tone="error"
        icon="error"
        title="Could not connect"
        detail={test.error}
      />
    ) : test?.status === "connected" ? (
      <Banner
        tone="success"
        icon="check_circle"
        title="Connected"
        detail={[
          mcpPlural(test.tools.length, "tool"),
          mcpPlural(test.prompts ?? 0, "prompt"),
          mcpPlural(test.resources ?? 0, "resource"),
        ].join(" · ")}
      />
    ) : null;
  return (
    <GroupedListView platform={resolved} device={device}>
      <div className="h-mcp-detail__head">
        {showName ? (
          <div className="h-mcp-detail__name">{server.name}</div>
        ) : null}
        <div className="h-mcp-detail__facts">
          {mcpFacts(server).join(" · ")}
        </div>
        {server.address ? (
          <div className="h-mcp-detail__address">{server.address}</div>
        ) : null}
      </div>
      <GroupedSection>
        <GroupedSwitchRow
          title="Enabled"
          subtitle={
            server.enabled
              ? "Used from the next chat"
              : "Not used from the next chat"
          }
          checked={server.enabled}
          disabled={switching}
          onChange={onEnabledChange ?? (() => {})}
        />
      </GroupedSection>
      <GroupedSection dividerIndent="leading">
        {server.auth === "OAuth" && !signInNeeded ? (
          <GroupedRow
            title="Sign in"
            leading={
              startingSignIn ? (
                spinner("Starting sign-in")
              ) : (
                <Icon name="login" size={leadingSize} />
              )
            }
            chevron={false}
            disabled={startingSignIn}
            onClick={onSignIn ?? (() => {})}
          />
        ) : null}
        <GroupedRow
          title="Test connection"
          leading={
            running ? (
              spinner("Testing")
            ) : (
              <Icon name="check" size={leadingSize} />
            )
          }
          chevron={false}
          disabled={running}
          onClick={onTest ?? (() => {})}
        />
        <GroupedRow
          title="Remove"
          leading={
            <Icon name="delete" size={leadingSize} color="var(--h-error)" />
          }
          destructive
          chevron={false}
          onClick={onRemove ?? (() => {})}
        />
      </GroupedSection>
      {signInNote ? (
        <div className="h-mcp-detail__banner">
          <Banner tone="error" icon="error" title={signInNote} />
        </div>
      ) : null}
      {outcome ? <div className="h-mcp-detail__banner">{outcome}</div> : null}
      {tools.length > 0 ? (
        <GroupedSection
          header={`Tools · ${tools.length}`}
          footer="The size next to a tool is what its schema costs the model in context. Hermes sends it with a test."
        >
          {tools.map((tool) => (
            <GroupedRow
              key={tool.name}
              title={tool.name}
              subtitle={tool.description || undefined}
              value={
                tool.schemaChars === undefined
                  ? undefined
                  : mcpSchemaSize(tool.schemaChars)
              }
            />
          ))}
        </GroupedSection>
      ) : null}
    </GroupedListView>
  );
}
