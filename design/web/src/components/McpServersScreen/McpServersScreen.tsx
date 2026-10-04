import { Button } from "../Button/Button";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { ListDetailLayout } from "../ListDetailLayout/ListDetailLayout";
import { Menu, MenuAnchor } from "../Menu/Menu";
import {
  McpServerRow,
  type McpServer,
  type McpServerTest,
} from "../McpServerRow/McpServerRow";
import {
  McpServerDetail,
  type McpServerTestState,
} from "../McpServerDetail/McpServerDetail";
import { StateMessage } from "../StateMessage/StateMessage";
import { usePlatform, type Platform } from "../../platform";
import { noop, ScreenFrame, ScreenState } from "../../screen";
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
  /** The profile they belong to, shown as "Profile: work" under the title and named in the empty state. */
  profile?: string;
  /** `loading`: a centred spinner. `failed`: "Could not load MCP servers" with Retry. `loaded` (default): the list, or the empty state. */
  state?: "loaded" | "loading" | "failed";
  /**
   * `desktop` (900px and wider): the 380px list beside the selected server's
   * `McpServerDetail`. `phone`: the list alone; a server opens as its own
   * page, drawn with `openServer`.
   */
  layout?: "phone" | "desktop";
  /** Desktop: the server open in the detail pane. Defaults to the first. */
  selected?: string;
  /** Phone: draw this server's page (back to "MCP servers") instead of the list. */
  openServer?: string;
  /** Draw the "Add" menu open: "Browse the catalog", "Add a custom server". */
  addMenuOpen?: boolean;
  /** Apple phone: draw this server's row swiped open to Remove. */
  swipedServer?: string;
  /** Back to the chat. The back button is always drawn: the screen is pushed over the chat. */
  onBack?: () => void;
  onOpen?: (name: string) => void;
  onEnabledChange?: (name: string, enabled: boolean) => void;
  onTest?: (name: string) => void;
  onRemove?: (name: string) => void;
  onSignIn?: (name: string) => void;
  /** The Add button. */
  onAdd?: () => void;
  /** "Browse the catalog": opens `McpCatalogScreen`. */
  onBrowseCatalog?: () => void;
  /** "Add a custom server": opens `McpAddServerScreen`. */
  onAddCustom?: () => void;
  /** The "…" button, whose menu holds "Edit as JSON" (`McpJsonEditorScreen`). */
  onMore?: () => void;
  onRetry?: () => void;
  /**
   * `apple`: a chevron back button labelled "Chat" on a phone, the 44px bar,
   * the iOS toggles and menus, rows that swipe to Remove. Inherits the
   * provider's platform.
   */
  platform?: Platform;
}

function rowTest(test?: McpServerTestState): McpServerTest | undefined {
  if (test?.status === "connected")
    return { ok: true, toolCount: test.tools.length };
  if (test?.status === "signInNeeded") return { signInNeeded: true };
  return undefined;
}

/**
 * The MCP servers screen of the active profile: an app bar ("MCP servers",
 * "Profile: work", an Add menu and "…"), a note that changes apply from the
 * next chat, the `McpServerRow` list and, from 900px, the selected server's
 * `McpServerDetail` beside it. Covers loading, failed and empty states and
 * the phone's server page. Fills its parent; give it a size.
 */
export function McpServersScreen({
  servers,
  profile,
  state = "loaded",
  layout = "desktop",
  selected,
  openServer,
  addMenuOpen = false,
  swipedServer,
  onBack,
  onOpen,
  onEnabledChange,
  onTest,
  onRemove,
  onSignIn,
  onAdd,
  onBrowseCatalog,
  onAddCustom,
  onMore,
  onRetry,
  platform,
}: McpServersScreenProps) {
  const resolved = usePlatform(platform);
  const desktop = layout === "desktop";
  const subtitle = profile ? `Profile: ${profile}` : undefined;
  const detailOf = (server: McpServerEntry) => (
    <McpServerDetail
      server={server}
      test={server.test}
      signInNote={server.signInNote}
      switching={server.switching}
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
        <ListDetailLayout
          layout="list"
          title="MCP servers"
          onBack={onBack ?? noop}
          backLabel="MCP servers"
          list={detailOf(page)}
        />
      </ScreenFrame>
    );
  }

  const loaded = state === "loaded";
  const actions = loaded ? (
    <>
      <MenuAnchor>
        <Button variant="text" icon="add" onClick={onAdd}>
          Add
        </Button>
        {addMenuOpen ? (
          <Menu
            align="end"
            device={desktop ? "mac" : "touch"}
            label="Add"
            items={[
              { label: "Browse the catalog", value: "catalog" },
              { label: "Add a custom server", value: "custom" },
            ]}
            onSelect={(item) =>
              item.value === "catalog" ? onBrowseCatalog?.() : onAddCustom?.()
            }
          />
        ) : null}
      </MenuAnchor>
      <IconButton icon="more_vert" label="More" onClick={onMore} />
    </>
  ) : null;

  const pick = desktop
    ? (servers.find((s) => s.name === selected) ?? servers[0])
    : undefined;

  let list;
  if (state !== "loaded") {
    list = (
      <ScreenState
        state={state}
        failedTitle="Could not load MCP servers"
        onRetry={onRetry}
      />
    );
  } else if (servers.length === 0) {
    list = (
      <div className="h-screen__center">
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
      </div>
    );
  } else {
    list = (
      <div className="h-mcp-screen__list">
        <div className="h-mcp-screen__note">
          <Icon name="info" size={16} />
          <span className="h-body-sm">
            Changes apply from the next chat, not to one that is already
            running.
          </span>
        </div>
        {servers.map((server) => (
          <McpServerRow
            key={server.name}
            server={server}
            test={rowTest(server.test)}
            selected={pick?.name === server.name}
            switching={server.switching}
            device={desktop ? "mac" : "touch"}
            swipeRevealed={swipedServer === server.name}
            onClick={() => onOpen?.(server.name)}
            onEnabledChange={(on) => onEnabledChange?.(server.name, on)}
            onRemove={() => onRemove?.(server.name)}
          />
        ))}
      </div>
    );
  }

  const split = desktop && loaded && servers.length > 0;
  return (
    <ScreenFrame platform={resolved}>
      <ListDetailLayout
        layout={split ? "split" : "list"}
        title="MCP servers"
        subtitle={subtitle}
        onBack={onBack ?? noop}
        backLabel="Chat"
        actions={actions}
        listWidth={380}
        detailPadding={0}
        list={list}
        detail={pick ? detailOf(pick) : undefined}
      />
    </ScreenFrame>
  );
}
