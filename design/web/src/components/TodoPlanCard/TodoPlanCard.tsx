import { DisclosureTile } from "../SessionStatusCard/DisclosureTile";
import "./TodoPlanCard.css";

/** Where one plan task stands. */
export type TodoPlanStatus =
  "pending" | "in_progress" | "completed" | "cancelled";

/** One task of the agent's plan. */
export interface TodoPlanItem {
  /** What the task says, in the agent's words. Wraps. */
  content: string;
  /** Drawn as a small label above the content: Pending, In progress, Completed, Cancelled. */
  status: TodoPlanStatus;
  /** A subtask of an earlier item: indented by 12px. */
  nested?: boolean;
}

export interface TodoPlanCardProps {
  /**
   * The plan's tasks in order. A `null` entry is a task Hermes sent in a shape
   * the app does not understand: it reads "Task details unavailable", and the
   * header says "Some task details unavailable" instead of the completed
   * count. An empty list draws nothing.
   */
  items: Array<TodoPlanItem | null>;
  /** Start opened, to preview the list. Folded by default. */
  defaultOpen?: boolean;
  /** The task list was opened (the app logs it). */
  onDetails?: () => void;
}

const statusLabels: Record<TodoPlanStatus, string> = {
  pending: "Pending",
  in_progress: "In progress",
  completed: "Completed",
  cancelled: "Cancelled",
};

/**
 * The Working-tier card for the agent's own task plan (its todo list). Folded
 * it is one line, `Plan · 1 of 3 completed`; opened it lists every task with a
 * small status label above its text, in a box that scrolls past 240px.
 * Distinct from the todo view inside an opened tool call. Material on every
 * platform, as in the app.
 */
export function TodoPlanCard({
  items,
  defaultOpen = false,
  onDetails,
}: TodoPlanCardProps) {
  if (items.length === 0) return null;
  const complete = items.every((item) => item !== null);
  const completed = items.filter((item) => item?.status === "completed").length;
  const title = complete
    ? `Plan · ${completed} of ${items.length} completed`
    : "Plan · Some task details unavailable";
  return (
    <DisclosureTile
      defaultOpen={defaultOpen}
      onOpen={onDetails}
      title={<span className="h-todo-plan__title">{title}</span>}
    >
      <div className="h-todo-plan__scroll">
        <div className="h-todo-plan__list">
          {items.map((item, i) =>
            item === null ? (
              <div key={i} className="h-todo-plan__unavailable">
                Task details unavailable
              </div>
            ) : (
              <div
                key={i}
                className={
                  item.nested
                    ? "h-todo-plan__item h-todo-plan__item--nested"
                    : "h-todo-plan__item"
                }
              >
                <div className="h-todo-plan__status">
                  {statusLabels[item.status]}
                </div>
                <div className="h-todo-plan__content">{item.content}</div>
              </div>
            ),
          )}
        </div>
      </div>
    </DisclosureTile>
  );
}
