import { cx, PlatformScope, usePlatform, type Platform } from "../../platform";
import "./McpServerRow.css";

/** An MCP server configured on the active Hermes profile. */
export interface McpServer {
  /** Server name from the profile's config, e.g. "grafana". Its first letter fills the avatar. */
  name: string;
  /** `remote`: an HTTP/SSE endpoint. `command`: a program the Hermes host runs (address shown in monospace). */
  transport: "remote" | "command";
  /** The URL of a remote server, or the command line of a command server: "npx -y @modelcontextprotocol/server-filesystem /srv/notes". */
  address?: string;
  /** How it signs in, already labelled: "OAuth", "Header". A remote server without one shows "No auth". */
  auth?: string;
  /** Switched on for new chats. Off adds an "Off" chip. */
  enabled: boolean;
}

/** The outcome of the last "Test connection", when there is one. */
export interface McpServerTest {
  /** The server answered and listed its tools. */
  ok?: boolean;
  /** Number of tools it listed; shown as "4 tools" when `ok`. */
  toolCount?: number;
  /** It needs an OAuth sign-in first; shown as an orange "Sign in needed" chip. */
  signInNeeded?: boolean;
}

export interface McpServerRowProps {
  /** The server to show. */
  server: McpServer;
  /** Result of the last connection test, which adds a tool count or a "Sign in needed" chip. */
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
   * `apple`: the enabled switch is the iOS and macOS toggle (51x31, a thumb
   * that keeps its size, a zinc primary track). In the app the row also
   * swipes to reveal Remove and long-presses (right-clicks on a Mac) for
   * Turn on/off and Remove. Inherits the provider's platform.
   */
  platform?: Platform;
}

/**
 * One server in the MCP servers list: a letter avatar, the name, its URL or
 * command, chips for transport, auth and test result, and an enabled switch.
 * Full-width and borderless; stack rows directly in a list pane.
 */
export function McpServerRow({
  server,
  test,
  selected = false,
  switching = false,
  onClick,
  onEnabledChange,
  platform,
}: McpServerRowProps) {
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const auth =
    server.auth || (server.transport === "remote" ? "No auth" : undefined);
  const chips: { label: string; warning?: boolean }[] = [
    { label: server.transport === "remote" ? "Remote" : "Command" },
    ...(auth ? [{ label: auth }] : []),
    ...(!server.enabled ? [{ label: "Off" }] : []),
    ...(test?.signInNeeded ? [{ label: "Sign in needed", warning: true }] : []),
    ...(test?.ok
      ? [
          {
            label: `${test.toolCount ?? 0} ${test.toolCount === 1 ? "tool" : "tools"}`,
          },
        ]
      : []),
  ];
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div
        className={[
          "h-mcp-server-row",
          selected ? "h-mcp-server-row--selected" : null,
        ]
          .filter(Boolean)
          .join(" ")}
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
        <span className="h-mcp-server-row__avatar" aria-hidden>
          {server.name.charAt(0).toUpperCase()}
        </span>
        <div className="h-mcp-server-row__body">
          <div className="h-mcp-server-row__name">{server.name}</div>
          {server.address ? (
            <div
              className={[
                "h-mcp-server-row__address",
                server.transport === "command"
                  ? "h-mcp-server-row__address--mono"
                  : null,
              ]
                .filter(Boolean)
                .join(" ")}
            >
              {server.address}
            </div>
          ) : null}
          <div className="h-mcp-server-row__chips">
            {chips.map((c) => (
              <span
                key={c.label}
                className={[
                  "h-mcp-server-row__chip",
                  c.warning ? "h-mcp-server-row__chip--warning" : null,
                ]
                  .filter(Boolean)
                  .join(" ")}
              >
                {c.label}
              </span>
            ))}
          </div>
        </div>
        <button
          type="button"
          role="switch"
          aria-checked={server.enabled}
          aria-label={`${server.name} enabled`}
          disabled={switching}
          className={cx(
            "h-mcp-server-row__switch",
            server.enabled && "h-mcp-server-row__switch--on",
            apple && "h-apple-switch",
          )}
          onClick={(e) => {
            e.stopPropagation();
            onEnabledChange?.(!server.enabled);
          }}
        >
          <span className="h-mcp-server-row__thumb" />
        </button>
      </div>
    </PlatformScope>
  );
}
