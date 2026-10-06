import { useState } from "react";
import {
  MacToolbar,
  MacToolbarButton,
  MacToolbarSeparator,
} from "../MacToolbar/MacToolbar";
import { Menu, MenuAnchor } from "../Menu/Menu";
import {
  kanbanBoardMenuItems,
  kanbanMoreItems,
  type KanbanBoardItem,
  type KanbanMoreAction,
} from "../KanbanToolbar/KanbanToolbar";
import { cx } from "../../platform";

type MacMenu = "assignee" | "board" | "more";

/** The board's toolbar in a Mac window, as Flutter's KanbanMacToolbar. Internal to `KanbanScreen`. */
export function KanbanMacToolbar({
  ready,
  live,
  boards,
  board,
  assignees,
  assignee,
  taskCount,
  inspectorShown,
  defaultOpenMenu,
  onCreate,
  onAssigneeChange,
  onBoardChange,
  onManageBoards,
  onToggleInspector,
  onMoreAction,
}: {
  ready: boolean;
  live: boolean;
  boards: KanbanBoardItem[];
  board?: string;
  assignees: string[];
  assignee?: string;
  taskCount: number;
  inspectorShown: boolean;
  /** "tenant" is accepted for KanbanScreen's sake and opens nothing. */
  defaultOpenMenu?: MacMenu | "tenant";
  onCreate?: () => void;
  onAssigneeChange?: (assignee: string | undefined) => void;
  onBoardChange?: (slug: string) => void;
  onManageBoards?: () => void;
  onToggleInspector?: () => void;
  onMoreAction?: (action: KanbanMoreAction) => void;
}) {
  const [open, setOpen] = useState<MacMenu | undefined>(
    defaultOpenMenu === "tenant" ? undefined : defaultOpenMenu,
  );
  const toggle = (m: MacMenu) => setOpen(open === m ? undefined : m);
  const name = boards.find((b) => b.slug === board)?.name;
  const subtitle = ready
    ? [
        name,
        assignee ?? "all profiles",
        taskCount === 1 ? "1 task" : `${taskCount} tasks`,
      ]
        .filter(Boolean)
        .join(" · ")
    : undefined;
  return (
    <MacToolbar
      title="Kanban"
      subtitle={subtitle}
      border
      actions={
        <>
          <span
            className={cx(
              "h-kanban-toolbar__live",
              live && "h-kanban-toolbar__live--on",
            )}
            title={live ? "Live" : "Reconnecting…"}
            aria-label={live ? "Live" : "Reconnecting…"}
            role="img"
          />
          <MacToolbarButton
            icon="add"
            label="New Task"
            shortcut="⌘N"
            disabled={!ready}
            onClick={onCreate}
          />
          {ready && assignees.length ? (
            <MenuAnchor>
              <MacToolbarButton
                icon="filter_list"
                label="Filter by profile"
                selected={assignee !== undefined}
                onClick={() => toggle("assignee")}
              />
              {open === "assignee" ? (
                <Menu
                  align="end"
                  label="Filter by profile"
                  device="mac"
                  style={{ minWidth: 180 }}
                  items={[
                    { label: "All profiles", checked: assignee === undefined },
                    ...assignees.map((a) => ({
                      label: a,
                      value: a,
                      checked: a === assignee,
                    })),
                  ]}
                  onSelect={(item) => {
                    setOpen(undefined);
                    onAssigneeChange?.(item.value);
                  }}
                />
              ) : null}
            </MenuAnchor>
          ) : null}
          {boards.length ? (
            <MenuAnchor>
              <MacToolbarButton
                icon="dashboard_customize_outlined"
                label="Switch board"
                onClick={() => toggle("board")}
              />
              {open === "board" ? (
                <Menu
                  align="end"
                  label="Switch board"
                  device="mac"
                  style={{ minWidth: 220 }}
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
          <MacToolbarSeparator />
          <MacToolbarButton
            icon="view_sidebar_outlined"
            label={inspectorShown ? "Hide Inspector" : "Show Inspector"}
            shortcut="⌥⌘I"
            selected={inspectorShown}
            onClick={onToggleInspector}
          />
          {ready ? (
            <MenuAnchor>
              <MacToolbarButton
                icon="more_horiz"
                label="More"
                onClick={() => toggle("more")}
              />
              {open === "more" ? (
                <Menu<KanbanMoreAction>
                  align="end"
                  label="More"
                  device="mac"
                  style={{ minWidth: 200 }}
                  items={kanbanMoreItems}
                  onSelect={(item) => {
                    setOpen(undefined);
                    if (item.value) onMoreAction?.(item.value);
                  }}
                />
              ) : null}
            </MenuAnchor>
          ) : null}
        </>
      }
    />
  );
}
