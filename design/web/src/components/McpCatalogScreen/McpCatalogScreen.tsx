import { Button } from "../Button/Button";
import { Chip } from "../Chip/Chip";
import { ListDetailLayout } from "../ListDetailLayout/ListDetailLayout";
import {
  McpCatalogRow,
  type McpCatalogEntry,
} from "../McpCatalogRow/McpCatalogRow";
import {
  McpInstallPanel,
  type McpInstallPanelProps,
} from "../McpInstallPanel/McpInstallPanel";
import { McpServerDetail } from "../McpServerDetail/McpServerDetail";
import type { McpServerEntry } from "../McpServersScreen/McpServersScreen";
import { Sheet } from "../Sheet/Sheet";
import { TextField } from "../TextField/TextField";
import { usePlatform, type Platform } from "../../platform";
import { noop, ScreenFrame, ScreenState } from "../../screen";
import "./McpCatalogScreen.css";

/** The catalog's filter chips. */
export type McpCatalogFilter = "All" | "Remote" | "Command" | "OAuth";

const FILTERS: McpCatalogFilter[] = ["All", "Remote", "Command", "OAuth"];

export interface McpCatalogScreenProps {
  /** Every entry of Hermes' approved catalog; the screen filters them by `query` and `filter`. */
  entries: McpCatalogEntry[];
  /** The profile entries install into, under the title: "Installing into: work". */
  profile?: string;
  /** `loading`: a centred spinner. `failed`: "Could not load the catalog" with Retry. */
  state?: "loaded" | "loading" | "failed";
  /** `desktop` (900px and wider): the 380px list beside a pane with the selected entry. `phone`: the list alone; an entry opens in a bottom sheet (`sheetEntry`). */
  layout?: "phone" | "desktop";
  /** Text in the search field; matches names and descriptions. */
  query?: string;
  /** The selected filter chip. Default "All". */
  filter?: McpCatalogFilter;
  /** Some entries could not be read: a muted note above the list. */
  hasDiagnostics?: boolean;
  /** Names of entries Hermes is building on the server (a "Building" tag). */
  building?: string[];
  /** Desktop: the entry in the pane. Not installed: its `McpInstallPanel`. Installed: its server's `McpServerDetail` (pass `installedServer`). Nothing: "Pick a server to see what Hermes would run." */
  selected?: string;
  /** Desktop: the installed server to show when `selected` is installed. */
  installedServer?: McpServerEntry;
  /** Phone: draw this entry's install panel in a bottom sheet over the list. */
  sheetEntry?: string;
  /** Passed to the install panel in the pane or sheet: its `state`, `failure`, `credentials`, `enableAfterInstall` and callbacks. */
  install?: Omit<McpInstallPanelProps, "entry" | "profile" | "platform">;
  onBack?: () => void;
  onQueryChange?: (query: string) => void;
  onFilterChange?: (filter: McpCatalogFilter) => void;
  onClearSearch?: () => void;
  onOpen?: (name: string) => void;
  onRetry?: () => void;
  /** The sheet's scrim was clicked. */
  onDismissSheet?: () => void;
  /** Follows the platform: chevron back labelled "MCP servers" on an Apple phone, Apple switches and spinners. Inherits the provider's platform. */
  platform?: Platform;
}

function matches(entry: McpCatalogEntry, q: string, filter: McpCatalogFilter) {
  const text =
    !q ||
    entry.name.toLowerCase().includes(q) ||
    (entry.description ?? "").toLowerCase().includes(q);
  const kind =
    filter === "All" ||
    (filter === "Remote" && entry.transport === "remote") ||
    (filter === "Command" && entry.transport === "command") ||
    (filter === "OAuth" && entry.auth === "OAuth");
  return text && kind;
}

/**
 * Hermes' approved MCP servers for the active profile: a search field
 * ("Search 12 servers"), filter chips (All, Remote, Command, OAuth) and
 * `McpCatalogRow`s. From 900px the selected entry sits beside the list as an
 * `McpInstallPanel` (or the installed server's `McpServerDetail`); on a
 * phone it opens in a bottom `Sheet`. Covers loading, failed and "No servers
 * match". Fills its parent; give it a size.
 */
export function McpCatalogScreen({
  entries,
  profile,
  state = "loaded",
  layout = "desktop",
  query = "",
  filter = "All",
  hasDiagnostics = false,
  building = [],
  selected,
  installedServer,
  sheetEntry,
  install,
  onBack,
  onQueryChange,
  onFilterChange,
  onClearSearch,
  onOpen,
  onRetry,
  onDismissSheet,
  platform,
}: McpCatalogScreenProps) {
  const resolved = usePlatform(platform);
  const desktop = layout === "desktop";
  const q = query.trim().toLowerCase();
  const visible = entries.filter((e) => matches(e, q, filter));
  const panelFor = (entry: McpCatalogEntry) => (
    <McpInstallPanel entry={entry} profile={profile} {...install} />
  );

  let list;
  if (state !== "loaded") {
    list = (
      <ScreenState
        state={state}
        failedTitle="Could not load the catalog"
        onRetry={onRetry}
      />
    );
  } else {
    list = (
      <div className="h-mcp-catalog">
        <div className="h-mcp-catalog__search">
          <TextField
            leadingIcon="search"
            placeholder={`Search ${entries.length} ${entries.length === 1 ? "server" : "servers"}`}
            value={query}
            onChange={(e) => onQueryChange?.(e.target.value)}
          />
        </div>
        <div className="h-mcp-catalog__filters">
          {FILTERS.map((f) => (
            <Chip
              key={f}
              label={f}
              selected={filter === f}
              onClick={() => onFilterChange?.(f)}
            />
          ))}
        </div>
        {hasDiagnostics ? (
          <div className="h-body-sm h-mcp-catalog__diagnostics">
            Some catalog entries could not be read.
          </div>
        ) : null}
        <div className="h-mcp-catalog__rows">
          {visible.length === 0 ? (
            <div className="h-mcp-catalog__none">
              <div className="h-title-md">No servers match</div>
              <Button variant="text" onClick={onClearSearch}>
                Clear search
              </Button>
            </div>
          ) : (
            visible.map((entry) => (
              <McpCatalogRow
                key={entry.name}
                entry={entry}
                building={building.includes(entry.name)}
                selected={desktop && entry.name === selected}
                onClick={() => onOpen?.(entry.name)}
              />
            ))
          )}
        </div>
      </div>
    );
  }

  const picked = entries.find((e) => e.name === selected);
  const pane = !picked ? undefined : picked.installed ? (
    installedServer ? (
      <McpServerDetail server={installedServer} test={installedServer.test} />
    ) : undefined
  ) : (
    panelFor(picked)
  );
  const sheet = !desktop
    ? entries.find((e) => e.name === sheetEntry && !e.installed)
    : undefined;

  return (
    <ScreenFrame platform={resolved}>
      <ListDetailLayout
        layout={desktop && state === "loaded" ? "split" : "list"}
        title="Catalog"
        subtitle={profile ? `Installing into: ${profile}` : undefined}
        onBack={onBack ?? noop}
        backLabel="MCP servers"
        listWidth={380}
        detailPadding={0}
        list={list}
        detail={pane}
        placeholder="Pick a server to see what Hermes would run."
      />
      {sheet ? (
        <Sheet padding={0} onDismiss={onDismissSheet}>
          {panelFor(sheet)}
        </Sheet>
      ) : null}
    </ScreenFrame>
  );
}
