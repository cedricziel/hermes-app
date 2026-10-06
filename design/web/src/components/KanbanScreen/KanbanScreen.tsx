import { Button } from "../Button/Button";
import { KanbanColumn } from "../KanbanColumn/KanbanColumn";
import type { KanbanTaskItem } from "../KanbanCard/KanbanCard";
import { KanbanStatusChips } from "../KanbanStatusChips/KanbanStatusChips";
import {
  KanbanTaskPanel,
  type KanbanTaskPanelProps,
} from "../KanbanTaskPanel/KanbanTaskPanel";
import {
  KanbanBulkBar,
  KanbanToolbar,
  type KanbanBoardItem,
  type KanbanMoreAction,
  type KanbanToolbarProps,
  type KanbanBulkBarProps,
} from "../KanbanToolbar/KanbanToolbar";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import {
  cx,
  PlatformScope,
  usePlatform,
  useAppleDevice,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { KanbanMacToolbar } from "./KanbanMacToolbar";
import "./KanbanScreen.css";

/** One status of the board and its tasks, in board order. */
export interface KanbanBoardColumn {
  /** Status key: `triage`, `todo`, `scheduled`, `ready`, `running`, `blocked`, `review`, `done` (and `archived` with the Archived filter on). */
  name: string;
  /** The column's tasks, top to bottom. */
  tasks: KanbanTaskItem[];
}

export interface KanbanScreenProps {
  /**
   * `ready`: the board. `loading`: the app bar over a spinner (first load).
   * `error`: "Could not load the board" with Retry. `unavailable`: "Kanban
   * isn't available", the plugin was turned off on the server.
   */
  state?: "ready" | "loading" | "error" | "unavailable";
  /**
   * `desktop` (900px and up): 260px columns side by side, scrolling
   * sideways, and a refresh button by the search. `phone`: the status chips
   * over the list of the status picked in `shownStatus`, and a menu button
   * in the app bar that opens the navigation drawer.
   */
  layout?: "phone" | "desktop";
  /** The board's statuses and tasks, in board order. */
  columns?: KanbanBoardColumn[];
  /** Phone: the status whose tasks are listed (its chip is selected). Defaults to the first column. */
  shownStatus?: string;
  /** Boards for the switcher in the app bar; hidden when there is one or none. */
  boards?: KanbanBoardItem[];
  /** Slug of the board on screen. */
  board?: string;
  /** The event stream is connected (green dot) or reconnecting (muted). */
  live?: boolean;
  /** Search text. */
  query?: string;
  /** Assignees for the filter; empty hides it. */
  assignees?: string[];
  /** Tenants for the filter; empty hides it. */
  tenants?: string[];
  /** Assignee filter in effect. */
  assignee?: string;
  /** Tenant filter in effect. */
  tenant?: string;
  /** Archived tasks are listed. */
  includeArchived?: boolean;
  /** The last refresh failed: the red notice with Retry over the last board. */
  refreshFailed?: boolean;
  /**
   * Selection mode, with the ids of the picked tasks (may be empty): the
   * app bar reads "N selected" with a close button, the cards are outlined
   * when picked, the bulk bar (Move, Assign, Priority, Effort, Archive)
   * replaces the "New task" button at the bottom.
   */
  selectedIds?: string[];
  /** Id of the card drawn selected because its task is open in the panel. */
  openTaskId?: string;
  /**
   * The open task: the screen draws `KanbanTaskPanel` with these props over
   * a scrim, as a bottom sheet on a phone and a centred dialog (form sheet
   * on Apple) on a desktop. `frame` is set for you; on an iPhone pick the
   * sheet height with `detent`.
   */
  openTask?: KanbanTaskPanelProps;
  /** Which app bar menu starts open, for previews. */
  defaultOpenMenu?: "assignee" | "tenant" | "board" | "more";
  /**
   * `apple`: the iOS search field, iOS pull-downs, the 44px bulk toolbar on
   * a phone, Apple toggles and the Apple task sheet; the "New task" button
   * stays a floating button, as in the app. In a Mac window (`apple`,
   * `layout="desktop"`, `device` `mac`, the default without an iPad
   * `AppShell`) the board follows the Mac app instead: a `MacToolbar`
   * ("Kanban" over "Default · all profiles · 7 tasks", the live dot, New
   * Task, the profile filter, the board switcher, the inspector toggle and
   * "…") replaces the app bar and the assignee chip, there is no floating
   * button, and an open task shows in the 380px inspector on the right
   * instead of a dialog. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` (iPhone, iPad) or `mac`; inherited from the enclosing `AppShell`, else `mac` on a desktop layout. */
  device?: AppleDevice;
  /** A card was pressed (opens the task, or toggles it in selection mode). */
  onTaskClick?: (task: KanbanTaskItem) => void;
  /** Phone: a status chip was pressed. */
  onShowStatus?: (status: string) => void;
  /** "New task" pressed. */
  onCreate?: () => void;
  /** Retry pressed on a failed load or refresh, or the refresh button. */
  onRefresh?: () => void;
  /** Phone: the menu button was pressed. */
  onOpenMenu?: () => void;
  /** A "…" menu entry was picked. */
  onMoreAction?: (action: KanbanMoreAction) => void;
  /** A board was picked in the switcher. */
  onBoardChange?: (slug: string) => void;
  /** "Manage boards…" picked in the switcher. */
  onManageBoards?: () => void;
  /** Close pressed in selection mode. */
  onExitSelection?: () => void;
  /** The scrim around the task panel was pressed. */
  onCloseTask?: () => void;
  /** Selection mode: the bulk bar's Move, Assign, Priority, Effort and Archive callbacks (`KanbanBulkBar` props). */
  bulkActions?: Omit<KanbanBulkBarProps, "selectedCount" | "platform">;
  /** Mac: the inspector is shown (default true): beside the board, with "No task selected" until a card is clicked. */
  inspectorShown?: boolean;
  /** Mac: the inspector toggle in the toolbar was pressed. */
  onToggleInspector?: () => void;
  /** Mac: a profile was picked in the toolbar's filter; `undefined` for all profiles. */
  onAssigneeChange?: (assignee: string | undefined) => void;
}

/**
 * The Kanban destination, whole: `KanbanToolbar` (app bar, search,
 * filters), then `KanbanColumn`s side by side on a desktop or
 * `KanbanStatusChips` over one list column on a phone, the "New task"
 * floating button, `KanbanBulkBar` in selection mode and `KanbanTaskPanel`
 * for an open task. Fills its parent; put it in an `AppShell` with
 * `current="kanban"` for the sidebar or drawer.
 */
export function KanbanScreen({
  state = "ready",
  layout = "desktop",
  columns = [],
  shownStatus,
  boards = [],
  board,
  live = true,
  query,
  assignees = [],
  tenants = [],
  assignee,
  tenant,
  includeArchived = false,
  refreshFailed = false,
  selectedIds,
  openTaskId,
  openTask,
  defaultOpenMenu,
  platform,
  device,
  onTaskClick,
  onShowStatus,
  onCreate,
  onRefresh,
  onOpenMenu,
  onMoreAction,
  onBoardChange,
  onManageBoards,
  onExitSelection,
  onCloseTask,
  bulkActions,
  inspectorShown = true,
  onToggleInspector,
  onAssigneeChange,
}: KanbanScreenProps) {
  const resolvedPlatform = usePlatform(platform);
  const selecting = selectedIds !== undefined;
  const phone = layout === "phone";
  const appleDevice = useAppleDevice("desktop", device);
  const mac = resolvedPlatform === "apple" && !phone && appleDevice === "mac";
  const macToolbar = mac && !selecting;
  const ready = state === "ready";
  const picked = selecting ? selectedIds : openTaskId ? [openTaskId] : [];
  const shown = shownStatus ?? columns[0]?.name ?? "";
  const body = ready ? (
    phone ? (
      <>
        <KanbanStatusChips
          statuses={columns.map((c) => ({
            name: c.name,
            count: c.tasks.length,
          }))}
          selected={shown}
          onSelect={onShowStatus}
        />
        <div className="h-kanban-screen__list">
          <KanbanColumn
            variant="list"
            status={shown}
            tasks={columns.find((c) => c.name === shown)?.tasks ?? []}
            selectedIds={picked}
            showHandles={!selecting}
            onTaskClick={onTaskClick}
          />
        </div>
      </>
    ) : (
      <div className="h-kanban-screen__columns">
        {columns.map((c) => (
          <KanbanColumn
            key={c.name}
            status={c.name}
            tasks={c.tasks}
            selectedIds={picked}
            onTaskClick={onTaskClick}
          />
        ))}
      </div>
    )
  ) : state === "loading" ? (
    <div className="h-kanban-screen__center">
      <Spinner />
    </div>
  ) : state === "unavailable" ? (
    <StateMessage
      icon="extension_off"
      title="Kanban isn’t available"
      detail="The plugin was turned off on this server."
    />
  ) : (
    <StateMessage
      icon="error"
      title="Could not load the board"
      action={<Button onClick={onRefresh}>Retry</Button>}
    />
  );
  const toolbarProps: KanbanToolbarProps = {
    live,
    boards: ready ? boards : [],
    board,
    selectedCount: selecting ? selectedIds.length : undefined,
    query,
    assignees: mac ? [] : assignees,
    tenants,
    assignee,
    tenant,
    includeArchived,
    wide: !phone,
    refreshFailed: ready && refreshFailed,
    showMore: ready,
    defaultOpenMenu: macToolbar ? undefined : defaultOpenMenu,
    device,
    onOpenMenu: phone ? onOpenMenu : undefined,
    onMoreAction,
    onRefresh,
    onBoardChange,
    onManageBoards,
    onExitSelection,
  };
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div className={cx("h-kanban-screen", phone && "h-kanban-screen--phone")}>
        {macToolbar ? (
          <KanbanMacToolbar
            ready={ready}
            live={live}
            boards={boards}
            board={board}
            assignees={assignees}
            assignee={assignee}
            taskCount={columns.reduce((n, c) => n + c.tasks.length, 0)}
            inspectorShown={inspectorShown}
            defaultOpenMenu={defaultOpenMenu}
            onCreate={onCreate}
            onAssigneeChange={onAssigneeChange}
            onBoardChange={onBoardChange}
            onManageBoards={onManageBoards}
            onToggleInspector={onToggleInspector}
            onMoreAction={onMoreAction}
          />
        ) : null}
        {!mac ? (
          <KanbanToolbar {...toolbarProps} showSearch={ready} />
        ) : selecting ? (
          <KanbanToolbar {...toolbarProps} showSearch={false} />
        ) : null}
        <div className="h-kanban-screen__body">
          {mac ? (
            <div className="h-kanban-screen__inspected">
              <div className="h-kanban-screen__board">
                <KanbanToolbar
                  {...toolbarProps}
                  showAppBar={false}
                  showSearch={ready}
                />
                {body}
              </div>
              {inspectorShown && ready ? (
                <aside
                  className={cx(
                    "h-kanban-screen__inspector",
                    !openTask && "h-kanban-screen__inspector--empty",
                  )}
                  aria-label="Inspector"
                >
                  {openTask ? (
                    <KanbanTaskPanel
                      {...openTask}
                      frame="plain"
                      height="auto"
                    />
                  ) : (
                    <StateMessage
                      icon="view_sidebar"
                      title="No task selected"
                      detail="Click a card to see its details here."
                    />
                  )}
                </aside>
              ) : null}
            </div>
          ) : (
            body
          )}
          {ready && !selecting && !mac ? (
            <div className="h-kanban-screen__fab">
              <Button icon="add" onClick={onCreate}>
                New task
              </Button>
            </div>
          ) : null}
        </div>
        {ready && selecting ? (
          <KanbanBulkBar selectedCount={selectedIds.length} {...bulkActions} />
        ) : null}
        {openTask && !mac ? (
          <div
            className={cx(
              "h-kanban-screen__overlay",
              phone && "h-kanban-screen__overlay--sheet",
            )}
            onClick={(e) => {
              if (e.target === e.currentTarget) onCloseTask?.();
            }}
          >
            <div className="h-kanban-screen__panel">
              <KanbanTaskPanel
                {...openTask}
                frame={phone ? "sheet" : "dialog"}
                height={openTask.height ?? (phone ? undefined : "auto")}
              />
            </div>
          </div>
        ) : null}
      </div>
    </PlatformScope>
  );
}
