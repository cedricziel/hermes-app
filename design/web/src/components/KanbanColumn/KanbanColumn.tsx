import { KanbanCard } from "../KanbanCard/KanbanCard";
import type { KanbanTaskItem } from "../KanbanCard/KanbanCard";
import { kanbanStatusLabel } from "../KanbanStatusChips/KanbanStatusChips";
import "./KanbanColumn.css";

export interface KanbanColumnProps {
  /** Status key of the column, e.g. `todo`; the header shows it capitalised ("Todo"). */
  status: string;
  /** The column's tasks, top to bottom. */
  tasks: KanbanTaskItem[];
  /** Count shown after the name; defaults to the number of `tasks`. */
  count?: number;
  /** Ids of the tasks picked in selection mode (drawn with a 2px border). */
  selectedIds?: string[];
  /**
   * `column`: a 260px board column with its "Todo  3" header, laid side by
   * side with 12px gaps from 900px up. `list`: the phone's full-width list
   * under `KanbanStatusChips`, no header, cards with drag handles, and
   * "No tasks here" when empty.
   */
  variant?: "column" | "list";
  /** A card is being dragged over this column: tints it `surface-high`. */
  dropTarget?: boolean;
  /** Width of a `column`, in px. The app uses 260. */
  width?: number;
  /** Called with the task whose card was pressed. */
  onTaskClick?: (task: KanbanTaskItem) => void;
}

/**
 * One status of the Kanban board and its stack of `KanbanCard`s: a 260px
 * column with a header on a wide screen, or the plain list a phone shows
 * for the status picked in `KanbanStatusChips`.
 */
export function KanbanColumn({
  status,
  tasks,
  count,
  selectedIds = [],
  variant = "column",
  dropTarget = false,
  width = 260,
  onTaskClick,
}: KanbanColumnProps) {
  const cards = tasks.map((t) => (
    <KanbanCard
      key={t.id}
      task={t}
      selected={selectedIds.includes(t.id)}
      showHandle={variant === "list"}
      onClick={onTaskClick ? () => onTaskClick(t) : undefined}
    />
  ));
  if (variant === "list") {
    return (
      <div
        className={[
          "h-kanban-column--list",
          dropTarget ? "h-kanban-column--drop" : null,
        ]
          .filter(Boolean)
          .join(" ")}
      >
        {tasks.length ? (
          cards
        ) : (
          <div className="h-kanban-column__empty">No tasks here</div>
        )}
      </div>
    );
  }
  return (
    <section
      className={[
        "h-kanban-column",
        dropTarget ? "h-kanban-column--drop" : null,
      ]
        .filter(Boolean)
        .join(" ")}
      style={{ width }}
      aria-label={kanbanStatusLabel(status)}
    >
      <header className="h-kanban-column__header">
        {kanbanStatusLabel(status)}
        <span className="h-kanban-column__count">{count ?? tasks.length}</span>
      </header>
      <div className="h-kanban-column__cards">{cards}</div>
    </section>
  );
}
