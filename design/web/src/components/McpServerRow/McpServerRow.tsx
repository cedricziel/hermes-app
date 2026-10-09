import { GroupedTile } from "../GroupedRow/GroupedRow";
import { GroupedSwitchRow } from "../GroupedSwitchRow/GroupedSwitchRow";
import { RowActions } from "../SwipeActions/RowActions";
import {
  PlatformScope,
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { mcpFacts, mcpPlural } from "../../mcp";

/** An MCP server configured on the active Hermes profile. */
export interface McpServer {
  /** Server name from the profile's config, e.g. "grafana". Its first letter fills the leading tile. */
  name: string;
  /** `remote`: an HTTP/SSE endpoint. `command`: a program the Hermes host runs (address shown in monospace). */
  transport: "remote" | "command";
  /** The URL of a remote server, or the command line of a command server: "npx -y @modelcontextprotocol/server-filesystem /srv/notes". */
  address?: string;
  /** How it signs in, already labelled: "OAuth", "Header". A remote server without one reads "No auth". */
  auth?: string;
  /** Switched on for new chats. Off adds "Off" to the facts line. */
  enabled: boolean;
}

/** The outcome of the last "Test connection", when there is one. */
export interface McpServerTest {
  /** The server answered and listed its tools. */
  ok?: boolean;
  /** Number of tools it listed; "2 tools" joins the facts line when `ok`. */
  toolCount?: number;
  /** It needs an OAuth sign-in first: a "Sign in needed" line in the warning color. */
  signInNeeded?: boolean;
}

export interface McpServerRowProps {
  /** The server to show. */
  server: McpServer;
  /** Result of the last connection test, which adds a tool count or "Sign in needed". */
  test?: McpServerTest;
  /** Highlighted as the server open in the detail pane (wide layout). */
  selected?: boolean;
  /** A switch request is in flight: the switch is disabled. */
  switching?: boolean;
  /** The row was clicked: open the server's detail. */
  onClick?: () => void;
  /** The switch was flipped to this value. */
  onEnabledChange?: (enabled: boolean) => void;
  /**
   * `apple` + `touch`: 17px name, the address (15px; a command in 13px
   * monospace), the facts in a 13px muted line, the 51x31 toggle; the row
   * swipes from the trailing edge to Remove and a long press opens an
   * action sheet with Turn on or Turn off, and Remove (see `swipeRevealed`,
   * `actionSheetOpen`). `apple` + `mac`: 13px name over one 11px line
   * "address · facts" and the small 36x22 toggle. `material`: 16px name,
   * 14px address, 13px facts, the Material switch. Inherits the provider's
   * platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac`; only touch swipes. Inherited from the enclosing `SettingsScaffold`, `GroupedListView` or `AppShell`. */
  device?: AppleDevice;
  /** Apple touch: draw the row swiped open, Remove showing in red. A static preview state. */
  swipeRevealed?: boolean;
  /** Apple touch: draw the long-press action sheet over the screen (the nearest positioned ancestor). A static preview state. */
  actionSheetOpen?: boolean;
  /** Remove was picked from the swipe or the action sheet. Turn on and Turn off call `onEnabledChange`. */
  onRemove?: () => void;
}

/**
 * One server in the MCP servers group (a `GroupedSection` with
 * `dividerIndent="tile"`): its initial in a `GroupedTile`, the name, its
 * URL or command, one muted facts line ("Remote · OAuth · 2 tools", plus
 * "Off" when switched off), "Sign in needed" in the warning color, and its
 * switch. The row opens the detail; the switch stays its own control.
 */
export function McpServerRow({
  server,
  test,
  selected = false,
  switching = false,
  onClick,
  onEnabledChange,
  platform,
  device,
  swipeRevealed,
  actionSheetOpen,
  onRemove,
}: McpServerRowProps) {
  const resolved = usePlatform(platform);
  const mac = useGroupedChrome(resolved, device) === "mac";
  const meta = [
    ...mcpFacts(server),
    ...(test?.ok ? [mcpPlural(test.toolCount ?? 0, "tool")] : []),
    ...(server.enabled ? [] : ["Off"]),
  ].join(" · ");
  const subtitle = [server.address, mac ? meta : undefined]
    .filter(Boolean)
    .join(" · ");
  const actions = [
    ...(switching
      ? []
      : [
          {
            label: server.enabled ? "Turn off" : "Turn on",
            icon: server.enabled ? "toggle_off" : "toggle_on",
            onPress: () => onEnabledChange?.(!server.enabled),
          },
        ]),
    { label: "Remove", icon: "delete", destructive: true, onPress: onRemove },
  ];
  return (
    <PlatformScope platform={resolved}>
      <RowActions
        title={server.name}
        actions={actions}
        swipeRevealed={swipeRevealed}
        actionSheetOpen={actionSheetOpen}
        device={device}
      >
        <GroupedSwitchRow
          title={server.name}
          leading={
            <GroupedTile device={device}>
              {server.name.charAt(0).toUpperCase()}
            </GroupedTile>
          }
          subtitle={subtitle || undefined}
          monospaceSubtitle={server.transport === "command"}
          caption={!mac && meta ? meta : undefined}
          warning={test?.signInNeeded ? "Sign in needed" : undefined}
          selected={selected}
          checked={server.enabled}
          disabled={switching}
          onChange={onEnabledChange ?? (() => {})}
          onClick={onClick ?? (() => {})}
          device={device}
        />
      </RowActions>
    </PlatformScope>
  );
}
