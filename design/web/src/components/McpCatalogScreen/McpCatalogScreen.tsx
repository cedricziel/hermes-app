import { Button } from "../Button/Button";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedSection } from "../GroupedSection/GroupedSection";
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
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { Sheet } from "../Sheet/Sheet";
import { usePlatform, type AppleDevice, type Platform } from "../../platform";
import { mcpPlural } from "../../mcp";
import {
  noop,
  screenDevice,
  ScreenFrame,
  ScreenSplit,
  ScreenState,
} from "../../screen";
import "./McpCatalogScreen.css";

/** The catalog's filters, in the search field's filter menu. */
export type McpCatalogFilter = "All" | "Remote" | "Command" | "OAuth";

const FILTERS: McpCatalogFilter[] = ["All", "Remote", "Command", "OAuth"];

export interface McpCatalogScreenProps {
  /** Every entry of Hermes' approved catalog; the screen filters them by `query` and `filter`. */
  entries: McpCatalogEntry[];
  /** The profile entries install into, the bar's subtitle: "Installing into: work". */
  profile?: string;
  /** `loading`: a centred spinner. `failed`: "Could not load the catalog" with Retry. */
  state?: "loaded" | "loading" | "failed";
  /** `desktop` (900px and wider): the 380px list beside a pane with the selected entry. `phone`: the list alone; an entry opens in a bottom sheet (`sheetEntry`). */
  layout?: "phone" | "desktop";
  /** Text in the search field ("Search 4 servers"); matches names and descriptions. */
  query?: string;
  /** The filter picked in the search field's filter menu. Default "All"; any other marks the filter button. */
  filter?: McpCatalogFilter;
  /** Draw the filter menu open (All, Remote, Command, OAuth, the current one checked). */
  filterMenuOpen?: boolean;
  /** Some entries could not be read: the group's footer says so. */
  hasDiagnostics?: boolean;
  /** Names of entries Hermes is building on the server ("Building" in their facts line). */
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
  /**
   * `apple` on a phone: "‹ MCP servers", the title centred over the
   * subtitle, the 36px search field with the filter button inside, iOS rows.
   * `apple` + `desktop`: the Mac toolbar with the search field and a filter
   * toolbar button. `material`: the 56px bar and the 44px pill search field.
   * Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
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
 * Hermes' approved MCP servers for the active profile, in the settings
 * look: the bar's search field ("Search 4 servers") with its filter menu
 * (All, Remote, Command, OAuth), and the entries as `McpCatalogRow`s in one
 * inset group. From 900px the selected entry sits beside the 380px list as
 * an `McpInstallPanel` (or the installed server's `McpServerDetail`); on a
 * phone it opens in a bottom `Sheet`. Covers loading, failed and "No
 * servers match". Fills its parent; give it a size.
 */
export function McpCatalogScreen({
  entries,
  profile,
  state = "loaded",
  layout = "desktop",
  query = "",
  filter = "All",
  filterMenuOpen = false,
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
  device,
}: McpCatalogScreenProps) {
  const resolved = usePlatform(platform);
  const desktop = layout === "desktop";
  const loaded = state === "loaded";
  const q = query.trim().toLowerCase();
  const visible = entries.filter((e) => matches(e, q, filter));
  const panelFor = (entry: McpCatalogEntry) => (
    <McpInstallPanel entry={entry} profile={profile} {...install} />
  );

  const list = !loaded ? (
    <ScreenState
      state={state}
      failedTitle="Could not load the catalog"
      onRetry={onRetry}
    />
  ) : (
    <GroupedListView>
      {visible.length === 0 ? (
        <div className="h-mcp-catalog__none">
          <div className="h-title-md">No servers match</div>
          <Button variant="text" onClick={onClearSearch}>
            Clear search
          </Button>
        </div>
      ) : (
        <GroupedSection
          dividerIndent="tile"
          footer={
            hasDiagnostics
              ? "Some catalog entries could not be read."
              : undefined
          }
        >
          {visible.map((entry) => (
            <McpCatalogRow
              key={entry.name}
              entry={entry}
              building={building.includes(entry.name)}
              selected={desktop && entry.name === selected}
              onClick={() => onOpen?.(entry.name)}
            />
          ))}
        </GroupedSection>
      )}
    </GroupedListView>
  );

  const picked = entries.find((e) => e.name === selected);
  const pane =
    picked && !picked.installed ? (
      <div className="h-mcp-catalog__panel">{panelFor(picked)}</div>
    ) : picked && installedServer ? (
      <McpServerDetail server={installedServer} test={installedServer.test} />
    ) : (
      <div className="h-mcp-catalog__placeholder">
        Pick a server to see what Hermes would run.
      </div>
    );
  const sheet = !desktop
    ? entries.find((e) => e.name === sheetEntry && !e.installed)
    : undefined;

  return (
    <ScreenFrame platform={resolved}>
      <SettingsScaffold
        title="Catalog"
        subtitle={profile ? `Installing into: ${profile}` : undefined}
        onBack={onBack ?? noop}
        backLabel="MCP servers"
        device={screenDevice(layout, device)}
        search={
          loaded
            ? {
                query,
                onChange: onQueryChange,
                hint: `Search ${mcpPlural(entries.length, "server")}`,
                filters: FILTERS.map((f) => ({
                  label: f,
                  selected: f === filter,
                })),
                onFilter: (i) => onFilterChange?.(FILTERS[i]),
                filterMenuOpen,
              }
            : undefined
        }
      >
        {desktop && loaded ? <ScreenSplit list={list} pane={pane} /> : list}
      </SettingsScaffold>
      {sheet ? (
        <Sheet
          padding={0}
          label={`Install ${sheet.name}`}
          onDismiss={onDismissSheet}
        >
          {panelFor(sheet)}
        </Sheet>
      ) : null}
    </ScreenFrame>
  );
}
