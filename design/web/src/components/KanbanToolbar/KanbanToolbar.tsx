import { useState } from "react";
import { Button } from "../Button/Button";
import { Chip } from "../Chip/Chip";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { Menu, MenuAnchor, type MenuItem } from "../Menu/Menu";
import { TextField } from "../TextField/TextField";
import {
  cx,
  PlatformScope,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./KanbanToolbar.css";

/** A board in the board switcher. */
export interface KanbanBoardItem {
  /** Board slug, e.g. `default`. */
  slug: string;
  /** Display name, e.g. `Platform`. */
  name: string;
  /** Tasks on the board, shown as "Platform (12)". */
  total: number;
}

/** What the Kanban "…" menu asks for. */
export type KanbanMoreAction =
  "select" | "dispatch" | "workers" | "orchestration";

/** The Kanban "…" menu, as `Menu` items: Select tasks, Run dispatcher now, Active workers…, Orchestration…. */
export const kanbanMoreItems: { label: string; value: KanbanMoreAction }[] = [
  { label: "Select tasks", value: "select" },
  { label: "Run dispatcher now", value: "dispatch" },
  { label: "Active workers…", value: "workers" },
  { label: "Orchestration…", value: "orchestration" },
];

/** The board switcher's items: each board as "Name (12)", the one on screen checked, then "Manage boards…" (no `value`). */
export function kanbanBoardMenuItems(
  boards: KanbanBoardItem[],
  board?: string,
): Array<MenuItem | "divider"> {
  return [
    ...boards.map((b) => ({
      label: `${b.name} (${b.total})`,
      value: b.slug,
      checked: b.slug === board,
    })),
    "divider",
    { label: "Manage boards…" },
  ];
}

export interface KanbanToolbarProps {
  /** Show the 56px app bar above the search ("Kanban", board switcher, live dot, overflow menu). */
  showAppBar?: boolean;
  /** App bar title. */
  title?: string;
  /** The board's event stream is connected: a green dot, otherwise a muted one ("Reconnecting…"). */
  live?: boolean;
  /** Boards offered by the board switcher; the switcher is hidden when empty. */
  boards?: KanbanBoardItem[];
  /** Slug of the board on screen (checked in the switcher). */
  board?: string;
  /** Selection mode: the app bar becomes a close button and "N selected". Pair it with `KanbanBulkBar`. */
  selectedCount?: number;
  /** Current search text. */
  query?: string;
  /** Assignees the board knows; an empty list hides the assignee filter. */
  assignees?: string[];
  /** Tenants the board knows; an empty list hides the tenant filter. */
  tenants?: string[];
  /** Assignee filter in effect; omitted means "All assignees". */
  assignee?: string;
  /** Tenant filter in effect; omitted means "All tenants". */
  tenant?: string;
  /** The Archived filter chip is on (archived tasks are listed). */
  includeArchived?: boolean;
  /** Wide screen (900px and up): adds a refresh button next to the search, since there is no pull-to-refresh. */
  wide?: boolean;
  /** The last refresh failed: shows the red "Could not refresh" notice with Retry above the toolbar. */
  refreshFailed?: boolean;
  /** Which menu starts open, for previews: the assignee or tenant filter, the board switcher, or the "…" menu. */
  defaultOpenMenu?: "assignee" | "tenant" | "board" | "more";
  /** Show the search field and the filter chips under the app bar (default true). Off while the board loads or failed to load, when only the app bar is shown. */
  showSearch?: boolean;
  /** Show the "…" menu (Select tasks, Run dispatcher now, Active workers…, Orchestration…). Default true; the app hides it until a board has loaded. */
  showMore?: boolean;
  /** Phone: a menu button before the title that opens the shell's navigation drawer. Leave out on a wide screen, where the sidebar is beside the page. */
  onOpenMenu?: () => void;
  /** An entry of the "…" menu was picked. */
  onMoreAction?: (action: KanbanMoreAction) => void;
  /** Search text changed. */
  onQueryChange?: (query: string) => void;
  /** An assignee was picked; `undefined` for "All assignees". */
  onAssigneeChange?: (assignee: string | undefined) => void;
  /** A tenant was picked; `undefined` for "All tenants". */
  onTenantChange?: (tenant: string | undefined) => void;
  /** The Archived chip was toggled. */
  onIncludeArchivedChange?: (include: boolean) => void;
  /** Refresh button or Retry pressed. */
  onRefresh?: () => void;
  /** A board was picked in the switcher. */
  onBoardChange?: (slug: string) => void;
  /** "Manage boards…" was picked in the switcher. */
  onManageBoards?: () => void;
  /** Close button pressed in selection mode. */
  onExitSelection?: () => void;
  /** `apple`: the search is the iOS search field (rounded 10px, 36px tall, tinted fill), and the filter and board menus are iOS pull-downs on touch or compact Mac menus (see `device`). Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple`, which menus to draw: `touch` (iPhone, iPad) or `mac`. Inherited from the enclosing `AppShell`, else `mac`. */
  device?: AppleDevice;
}

/**
 * The top of the Kanban screen: app bar (title, board switcher, live dot,
 * or "N selected" in selection mode), search field, and the assignee,
 * tenant and Archived filter chips. Sits above `KanbanColumn`s or, on a
 * phone, `KanbanStatusChips`.
 */
export function KanbanToolbar({
  showAppBar = true,
  title = "Kanban",
  live = true,
  boards = [],
  board,
  selectedCount,
  query,
  assignees = [],
  tenants = [],
  assignee,
  tenant,
  includeArchived = false,
  wide = true,
  refreshFailed = false,
  defaultOpenMenu,
  showSearch = true,
  showMore = true,
  onOpenMenu,
  onMoreAction,
  onQueryChange,
  onAssigneeChange,
  onTenantChange,
  onIncludeArchivedChange,
  onRefresh,
  onBoardChange,
  onManageBoards,
  onExitSelection,
  platform,
  device,
}: KanbanToolbarProps) {
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const [open, setOpen] = useState(defaultOpenMenu);
  const toggle = (menu: "assignee" | "tenant" | "board" | "more") =>
    setOpen(open === menu ? undefined : menu);
  const selecting = selectedCount !== undefined;
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div
        className={cx("h-kanban-toolbar", apple && "h-kanban-toolbar--apple")}
      >
        {showAppBar ? (
          <div className="h-kanban-toolbar__appbar">
            {selecting ? (
              <>
                <IconButton
                  icon="close"
                  label="Done selecting"
                  onClick={onExitSelection}
                />
                <span className="h-kanban-toolbar__title h-kanban-toolbar__title--selecting">
                  {`${selectedCount} selected`}
                </span>
              </>
            ) : (
              <>
                {onOpenMenu ? (
                  <IconButton
                    icon="menu"
                    label="Open navigation menu"
                    onClick={onOpenMenu}
                  />
                ) : null}
                <span
                  className={cx(
                    "h-kanban-toolbar__title",
                    onOpenMenu && "h-kanban-toolbar__title--after-menu",
                  )}
                >
                  {title}
                </span>
                <span className="h-kanban-toolbar__actions">
                  {boards.length ? (
                    <MenuAnchor>
                      <IconButton
                        icon="dashboard_customize"
                        label="Switch board"
                        onClick={() => toggle("board")}
                      />
                      {open === "board" ? (
                        <Menu
                          align="end"
                          label="Switch board"
                          device={device}
                          style={{ minWidth: 220, maxWidth: 320 }}
                          items={kanbanBoardMenuItems(boards, board)}
                          onSelect={(item) => {
                            setOpen(undefined);
                            if (item.value) onBoardChange?.(item.value);
                            else onManageBoards?.();
                          }}
                        />
                      ) : null}
                    </MenuAnchor>
                  ) : null}
                  <span
                    className={[
                      "h-kanban-toolbar__live",
                      live ? "h-kanban-toolbar__live--on" : null,
                    ]
                      .filter(Boolean)
                      .join(" ")}
                    title={live ? "Live" : "Reconnecting…"}
                    aria-label={live ? "Live" : "Reconnecting…"}
                    role="img"
                  />
                  {showMore ? (
                    <MenuAnchor>
                      <IconButton
                        icon="more_vert"
                        label="More"
                        onClick={() => toggle("more")}
                      />
                      {open === "more" ? (
                        <Menu
                          align="end"
                          label="More"
                          device={device}
                          style={{ minWidth: 220 }}
                          items={kanbanMoreItems}
                          onSelect={(item) => {
                            setOpen(undefined);
                            if (item.value) onMoreAction?.(item.value);
                          }}
                        />
                      ) : null}
                    </MenuAnchor>
                  ) : null}
                </span>
              </>
            )}
          </div>
        ) : null}
        {refreshFailed ? (
          <div className="h-kanban-toolbar__notice" role="status">
            <Icon name="error" size={18} />
            <span className="h-kanban-toolbar__notice-text">
              Could not refresh. Showing the last board.
            </span>
            <Button variant="text" compact onClick={onRefresh}>
              Retry
            </Button>
          </div>
        ) : null}
        {showSearch ? (
          <div className="h-kanban-toolbar__body">
            <div className="h-kanban-toolbar__search-row">
              <TextField
                className="h-kanban-toolbar__search"
                variant="search"
                leadingIcon="search"
                placeholder="Search tasks"
                value={query}
                onChange={(e) => onQueryChange?.(e.target.value)}
                readOnly={query !== undefined && !onQueryChange}
              />
              {wide ? (
                <IconButton
                  icon="refresh"
                  label="Refresh"
                  onClick={onRefresh}
                />
              ) : null}
            </div>
            <div className="h-kanban-toolbar__filters">
              {assignees.length ? (
                <FilterMenu
                  label={assignee ?? "All assignees"}
                  all="All assignees"
                  options={assignees}
                  open={open === "assignee"}
                  device={device}
                  onToggle={() => toggle("assignee")}
                  onSelect={(v) => {
                    setOpen(undefined);
                    onAssigneeChange?.(v);
                  }}
                />
              ) : null}
              {tenants.length ? (
                <FilterMenu
                  label={tenant ?? "All tenants"}
                  all="All tenants"
                  options={tenants}
                  open={open === "tenant"}
                  device={device}
                  onToggle={() => toggle("tenant")}
                  onSelect={(v) => {
                    setOpen(undefined);
                    onTenantChange?.(v);
                  }}
                />
              ) : null}
              <Chip
                label="Archived"
                selected={includeArchived}
                onClick={() => onIncludeArchivedChange?.(!includeArchived)}
              />
            </div>
          </div>
        ) : null}
      </div>
    </PlatformScope>
  );
}

function FilterMenu({
  label,
  all,
  options,
  open,
  device,
  onToggle,
  onSelect,
}: {
  label: string;
  all: string;
  options: string[];
  open: boolean;
  device?: AppleDevice;
  onToggle: () => void;
  onSelect: (value: string | undefined) => void;
}) {
  return (
    <MenuAnchor>
      <Chip icon="filter_list" label={label} onClick={onToggle} />
      {open ? (
        <Menu
          align="start"
          label={all}
          device={device}
          style={{ minWidth: 200, maxWidth: 320 }}
          items={[
            { label: all },
            ...options.map((o) => ({ label: o, value: o })),
          ]}
          onSelect={(item) => onSelect(item.value)}
        />
      ) : null}
    </MenuAnchor>
  );
}

export interface KanbanBulkBarProps {
  /** Tasks picked; at 0 every action is disabled. */
  selectedCount: number;
  /** Move pressed (the app then asks for a status). */
  onMove?: () => void;
  /** Assign pressed (the app then asks for an assignee or "Nobody"). */
  onAssign?: () => void;
  /** Priority pressed (Normal, P1–P3). */
  onPriority?: () => void;
  /** Effort pressed (profile default or a reasoning effort). */
  onEffort?: () => void;
  /** Archive pressed (the app confirms "Archive N tasks?"). */
  onArchive?: () => void;
  /**
   * `apple` (iPhone): a 44px toolbar of icon-and-label buttons that reaches
   * the screen edge, instead of the 80px bar of five text buttons. Inherits
   * the provider's platform.
   */
  platform?: Platform;
}

/**
 * The bottom bar of Kanban selection mode: Move, Assign, Priority, Effort and
 * Archive as five equal text buttons (a 44px icon-and-label toolbar under
 * `platform="apple"`). Shown with `KanbanToolbar`'s
 * `selectedCount` set.
 */
export function KanbanBulkBar({
  selectedCount,
  onMove,
  onAssign,
  onPriority,
  onEffort,
  onArchive,
  platform,
}: KanbanBulkBarProps) {
  const none = selectedCount === 0;
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const actions: [string, string, (() => void) | undefined][] = [
    ["Move", "drive_file_move", onMove],
    ["Assign", "person_add", onAssign],
    ["Priority", "flag", onPriority],
    ["Effort", "speed", onEffort],
    ["Archive", "archive", onArchive],
  ];
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div
        className={cx("h-kanban-bulk-bar", apple && "h-kanban-bulk-bar--apple")}
      >
        {actions.map(([label, icon, run]) => (
          <Button
            key={label}
            variant="text"
            icon={apple ? icon : undefined}
            disabled={none}
            onClick={run}
            className="h-kanban-bulk-bar__action"
          >
            {label}
          </Button>
        ))}
      </div>
    </PlatformScope>
  );
}
