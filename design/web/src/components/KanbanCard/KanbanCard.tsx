import { Badge } from "../Badge/Badge";
import { Icon } from "../Icon/Icon";
import "./KanbanCard.css";

/** One task on the Kanban board, as the board, columns and cards take it. */
export interface KanbanTaskItem {
  /** Hermes task id, shown in mono above the title, e.g. `t_8f2a`. */
  id: string;
  /** Task title; wraps over as many lines as it needs. */
  title: string;
  /**
   * Board status: `triage`, `todo`, `scheduled`, `ready`, `running`,
   * `blocked`, `review`, `done` or `archived`. `running` adds the progress bar.
   */
  status?: string;
  /** Profile the task is assigned to, e.g. `coder`. Omitted when unassigned. */
  assignee?: string;
  /** 1 to 3 shows a red `P1`–`P3` tag; 0 or omitted is normal priority (no tag). */
  priority?: number;
  /** Tenant the task belongs to, shown as a grey tag, e.g. `acme`. */
  tenant?: string;
  /** Number of comments; hidden at 0. */
  commentCount?: number;
  /** Subtasks done, shown as `done/total` next to a tree icon. */
  progressDone?: number;
  /** Subtasks in all; 0 or omitted hides the count and makes a running bar indeterminate. */
  progressTotal?: number;
  /** Open diagnostics (stuck worker, repeated failures); shown in amber, hidden at 0. */
  warningCount?: number;
}

export interface KanbanCardProps {
  /** The task to show. */
  task: KanbanTaskItem;
  /** Picked in selection mode or open in the panel: a 2px primary border instead of the 1px outline. */
  selected?: boolean;
  /** Show the drag handle in the top right corner, as on a phone where a long press selects instead. */
  showHandle?: boolean;
  /** Opens the task. */
  onClick?: () => void;
}

/**
 * A task card on the Kanban board: mono id, bold title and a wrapping row of
 * assignee, priority, tenant, comments, subtask progress and warnings, with a
 * progress bar while the task runs. Use it inside `KanbanColumn` or a phone list.
 */
export function KanbanCard({
  task,
  selected = false,
  showHandle = false,
  onClick,
}: KanbanCardProps) {
  const priority = task.priority ?? 0;
  const comments = task.commentCount ?? 0;
  const total = task.progressTotal ?? 0;
  const done = task.progressDone ?? 0;
  const warnings = task.warningCount ?? 0;
  const hasMeta =
    !!task.assignee ||
    priority > 0 ||
    !!task.tenant ||
    comments > 0 ||
    total > 0 ||
    warnings > 0;
  const classes = [
    "h-kanban-card",
    selected ? "h-kanban-card--selected" : null,
    onClick ? "h-kanban-card--interactive" : null,
  ]
    .filter(Boolean)
    .join(" ");
  return (
    <div
      className={classes}
      role={onClick ? "button" : undefined}
      tabIndex={onClick ? 0 : undefined}
      onClick={onClick}
    >
      <div className="h-kanban-card__id">{task.id}</div>
      <div className="h-kanban-card__title">{task.title}</div>
      {hasMeta ? (
        <div className="h-kanban-card__meta">
          {task.assignee ? (
            <span className="h-kanban-card__fact">
              <Icon name="person" size={13} />
              {task.assignee}
            </span>
          ) : null}
          {priority > 0 ? <Badge tone="error">{`P${priority}`}</Badge> : null}
          {task.tenant ? <Badge>{task.tenant}</Badge> : null}
          {comments > 0 ? (
            <span className="h-kanban-card__fact">
              <Icon name="chat_bubble" size={13} />
              {comments}
            </span>
          ) : null}
          {total > 0 ? (
            <span className="h-kanban-card__fact">
              <Icon name="account_tree" size={13} />
              {`${done}/${total}`}
            </span>
          ) : null}
          {warnings > 0 ? (
            <span className="h-kanban-card__fact h-kanban-card__fact--warning">
              <Icon name="warning" size={13} />
              {warnings}
            </span>
          ) : null}
        </div>
      ) : null}
      {task.status === "running" ? (
        <div
          className={[
            "h-kanban-card__bar",
            total > 0 ? null : "h-kanban-card__bar--indeterminate",
          ]
            .filter(Boolean)
            .join(" ")}
          role="progressbar"
          aria-label="In progress"
          aria-valuetext={total > 0 ? `${done} of ${total} done` : undefined}
        >
          <div
            className="h-kanban-card__bar-value"
            style={
              total > 0
                ? { width: `${Math.min(1, Math.max(0, done / total)) * 100}%` }
                : undefined
            }
          />
        </div>
      ) : null}
      {showHandle ? (
        <span className="h-kanban-card__handle" aria-label="Drag to move">
          <Icon name="drag_indicator" size={20} />
        </span>
      ) : null}
    </div>
  );
}
