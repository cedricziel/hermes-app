import { useState } from "react";
import { Button } from "../Button/Button";
import { Chip } from "../Chip/Chip";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { TextField } from "../TextField/TextField";
import { cx, PlatformScope, usePlatform, type Platform } from "../../platform";
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
  /** Which menu starts open, for previews: the assignee or tenant filter, or the board switcher. */
  defaultOpenMenu?: "assignee" | "tenant" | "board";
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
  /** `apple`: the search is the iOS search field (rounded 10px, 36px tall, tinted fill). Inherits the provider's platform. */
  platform?: Platform;
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
  onQueryChange,
  onAssigneeChange,
  onTenantChange,
  onIncludeArchivedChange,
  onRefresh,
  onBoardChange,
  onManageBoards,
  onExitSelection,
  platform,
}: KanbanToolbarProps) {
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const [open, setOpen] = useState(defaultOpenMenu);
  const toggle = (menu: "assignee" | "tenant" | "board") =>
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
                <span className="h-kanban-toolbar__title">{title}</span>
                <span className="h-kanban-toolbar__actions">
                  {boards.length ? (
                    <span className="h-kanban-toolbar__anchor">
                      <IconButton
                        icon="dashboard_customize"
                        label="Switch board"
                        onClick={() => toggle("board")}
                      />
                      {open === "board" ? (
                        <div className="h-kanban-toolbar__menu h-kanban-toolbar__menu--end">
                          {boards.map((b) => (
                            <button
                              key={b.slug}
                              type="button"
                              className="h-kanban-toolbar__item h-kanban-toolbar__item--checkable"
                              onClick={() => {
                                setOpen(undefined);
                                onBoardChange?.(b.slug);
                              }}
                            >
                              <span className="h-kanban-toolbar__check">
                                {b.slug === board ? (
                                  <Icon
                                    name="check"
                                    apple="checkmark"
                                    size={20}
                                  />
                                ) : null}
                              </span>
                              {`${b.name} (${b.total})`}
                            </button>
                          ))}
                          <hr className="h-divider h-kanban-toolbar__menu-divider" />
                          <button
                            type="button"
                            className="h-kanban-toolbar__item"
                            onClick={() => {
                              setOpen(undefined);
                              onManageBoards?.();
                            }}
                          >
                            Manage boards…
                          </button>
                        </div>
                      ) : null}
                    </span>
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
                  <IconButton icon="more_vert" label="More" />
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
              <IconButton icon="refresh" label="Refresh" onClick={onRefresh} />
            ) : null}
          </div>
          <div className="h-kanban-toolbar__filters">
            {assignees.length ? (
              <FilterMenu
                label={assignee ?? "All assignees"}
                all="All assignees"
                options={assignees}
                open={open === "assignee"}
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
      </div>
    </PlatformScope>
  );
}

function FilterMenu({
  label,
  all,
  options,
  open,
  onToggle,
  onSelect,
}: {
  label: string;
  all: string;
  options: string[];
  open: boolean;
  onToggle: () => void;
  onSelect: (value: string | undefined) => void;
}) {
  return (
    <span className="h-kanban-toolbar__anchor">
      <Chip icon="filter_list" label={label} onClick={onToggle} />
      {open ? (
        <div className="h-kanban-toolbar__menu" role="menu">
          <button
            type="button"
            role="menuitem"
            className="h-kanban-toolbar__item"
            onClick={() => onSelect(undefined)}
          >
            {all}
          </button>
          {options.map((o) => (
            <button
              key={o}
              type="button"
              role="menuitem"
              className="h-kanban-toolbar__item"
              onClick={() => onSelect(o)}
            >
              {o}
            </button>
          ))}
        </div>
      ) : null}
    </span>
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
