import { Button } from "../Button/Button";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import {
  McpServerRow,
  type McpServer,
  type McpServerTest,
} from "../McpServerRow/McpServerRow";
import {
  McpServerDetail,
  type McpServerTestState,
} from "../McpServerDetail/McpServerDetail";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { StateMessage } from "../StateMessage/StateMessage";
import {
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { mcpPlural } from "../../mcp";
import {
  noop,
  screenDevice,
  ScreenCenter,
  ScreenFrame,
  ScreenSplit,
  ScreenState,
} from "../../screen";
import "./McpServersScreen.css";

/** A server on the MCP servers screen, with what the screen knows about it. */
export interface McpServerEntry extends McpServer {
  /** The last connection test; the row shows its tool count or "Sign in needed", the detail the whole outcome. */
  test?: McpServerTestState;
  /** A switch request is in flight. */
  switching?: boolean;
  /** Why the last sign-in could not start (detail only). */
  signInNote?: string;
}

export interface McpServersScreenProps {
  /** The active profile's servers, in config order. An empty list draws the empty state. */
  servers: McpServerEntry[];
  /** The profile they belong to: the bar's subtitle ("work"; on a Mac "work · 2 servers"), and named in the empty state. */
  profile?: string;
  /** `loading`: a centred spinner. `failed`: "Could not load MCP servers" with Retry. `loaded` (default): the list, or the empty state. */
  state?: "loaded" | "loading" | "failed";
  /**
   * `desktop` (900px and wider): the 380px list beside the selected server's
   * `McpServerDetail`, past a 1px divider. `phone`: the list alone; a server
   * opens as its own page, drawn with `openServer`.
   */
  layout?: "phone" | "desktop";
  /** Desktop: the server open in the detail pane. Defaults to the first. */
  selected?: string;
  /** Phone: draw this server's page (its name as the title, back to "MCP servers") instead of the list. */
  openServer?: string;
  /** Draw the "+" menu open: "Browse the catalog", "Add a custom server". */
  addMenuOpen?: boolean;
  /** Draw the "…" menu open: "Edit as JSON". */
  moreMenuOpen?: boolean;
  /** Apple phone: draw this server's row swiped open to Remove. */
  swipedServer?: string;
  /** Back to the chat. The back button is always drawn: the screen is pushed over the chat. */
  onBack?: () => void;
  onOpen?: (name: string) => void;
  onEnabledChange?: (name: string, enabled: boolean) => void;
  onTest?: (name: string) => void;
  onRemove?: (name: string) => void;
  onSignIn?: (name: string) => void;
  /** "Browse the catalog": opens `McpCatalogScreen`. */
  onBrowseCatalog?: () => void;
  /** "Add a custom server": opens `McpAddServerScreen`. */
  onAddCustom?: () => void;
  /** "Edit as JSON" from the "…" menu: opens `McpJsonEditorScreen`. */
  onEditJson?: () => void;
  onRetry?: () => void;
  /**
   * `apple` on a phone: the 44px bar with "‹ Chat", the title centred over
   * the profile, "+" and "…" as 44px icon buttons, iOS rows that swipe to
   * Remove. `apple` + `desktop`: the Mac's 52px toolbar and 40px rows.
   * `material`: the 56px bar, 56px rows. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

function rowTest(test?: McpServerTestState): McpServerTest | undefined {
  if (test?.status === "connected")
    return { ok: true, toolCount: test.tools.length };
  if (test?.status === "signInNeeded") return { signInNeeded: true };
  return undefined;
}

/**
 * The MCP servers screen of the active profile, in the settings look: a
 * bar with "MCP servers" over the profile and "+" (the Add menu) and "…"
 * ("Edit as JSON"), the servers as `McpServerRow`s in one inset group whose
 * footer says changes apply from the next chat, and from 900px the selected
 * server's `McpServerDetail` beside the 380px list. Covers loading, failed
 * and empty states and the phone's server page. Fills its parent; give it a
 * size.
 */
export function McpServersScreen({
  servers,
  profile,
  state = "loaded",
  layout = "desktop",
  selected,
  openServer,
  addMenuOpen = false,
  moreMenuOpen = false,
  swipedServer,
  onBack,
  onOpen,
  onEnabledChange,
  onTest,
  onRemove,
  onSignIn,
  onBrowseCatalog,
  onAddCustom,
  onEditJson,
  onRetry,
  platform,
  device,
}: McpServersScreenProps) {
  const resolved = usePlatform(platform);
  const desktop = layout === "desktop";
  const appleDevice = screenDevice(layout, device);
  const mac = useGroupedChrome(resolved, appleDevice) === "mac";
  const detailOf = (server: McpServerEntry, showName = true) => (
    <McpServerDetail
      server={server}
      test={server.test}
      signInNote={server.signInNote}
      switching={server.switching}
      showName={showName}
      onEnabledChange={(on) => onEnabledChange?.(server.name, on)}
      onTest={() => onTest?.(server.name)}
      onRemove={() => onRemove?.(server.name)}
      onSignIn={() => onSignIn?.(server.name)}
    />
  );

  const page = !desktop
    ? servers.find((s) => s.name === openServer)
    : undefined;
  if (page) {
    return (
      <ScreenFrame platform={resolved}>
        <SettingsScaffold
          title={page.name}
          subtitle={profile}
          onBack={onBack ?? noop}
          backLabel="MCP servers"
          device={appleDevice}
        >
          {detailOf(page, false)}
        </SettingsScaffold>
      </ScreenFrame>
    );
  }

  const loaded = state === "loaded";
  const pick = desktop
    ? (servers.find((s) => s.name === selected) ?? servers[0])
    : undefined;

  let body;
  if (!loaded) {
    body = (
      <ScreenState
        state={state}
        failedTitle="Could not load MCP servers"
        onRetry={onRetry}
      />
    );
  } else if (servers.length === 0) {
    body = (
      <ScreenCenter>
        <StateMessage
          title={profile ? `No MCP servers on "${profile}"` : "No MCP servers"}
          detail="MCP servers give the agent extra tools, such as searching your documents or reading a calendar."
          action={
            <div className="h-mcp-screen__empty-actions">
              <Button onClick={onBrowseCatalog}>Browse the catalog</Button>
              <Button variant="outlined" onClick={onAddCustom}>
                Add a custom server
              </Button>
            </div>
          }
        />
      </ScreenCenter>
    );
  } else {
    const list = (
      <GroupedListView>
        <GroupedSection
          dividerIndent="tile"
          footer="Changes apply from the next chat, not to one that is already running."
        >
          {servers.map((server) => (
            <McpServerRow
              key={server.name}
              server={server}
              test={rowTest(server.test)}
              selected={pick?.name === server.name}
              switching={server.switching}
              swipeRevealed={swipedServer === server.name}
              onClick={() => onOpen?.(server.name)}
              onEnabledChange={(on) => onEnabledChange?.(server.name, on)}
              onRemove={() => onRemove?.(server.name)}
            />
          ))}
        </GroupedSection>
      </GroupedListView>
    );
    body = pick ? <ScreenSplit list={list} pane={detailOf(pick)} /> : list;
  }

  return (
    <ScreenFrame platform={resolved}>
      <SettingsScaffold
        title="MCP servers"
        subtitle={
          mac && loaded
            ? [profile, mcpPlural(servers.length, "server")]
                .filter(Boolean)
                .join(" · ")
            : profile
        }
        onBack={onBack ?? noop}
        device={appleDevice}
        actions={
          loaded
            ? [
                {
                  icon: "add",
                  label: "Add server",
                  menu: [
                    { label: "Browse the catalog" },
                    { label: "Add a custom server" },
                  ],
                  menuOpen: addMenuOpen,
                  onSelect: (i) =>
                    i === 0 ? onBrowseCatalog?.() : onAddCustom?.(),
                },
                {
                  icon: "more_horiz",
                  label: "More",
                  menu: [{ label: "Edit as JSON" }],
                  menuOpen: moreMenuOpen,
                  onSelect: () => onEditJson?.(),
                },
              ]
            : []
        }
      >
        {body}
      </SettingsScaffold>
    </ScreenFrame>
  );
}
