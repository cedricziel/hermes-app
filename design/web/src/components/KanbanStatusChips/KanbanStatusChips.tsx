import { Icon } from "../Icon/Icon";
import "./KanbanStatusChips.css";

/** One status in the phone's chip row. */
export interface KanbanStatusCount {
  /** Status key, e.g. `running`; shown capitalised ("Running"). */
  name: string;
  /** Tasks in that status, shown after the name ("Running 2"). */
  count: number;
}

export interface KanbanStatusChipsProps {
  /** The board's statuses in board order: triage, todo, scheduled, ready, running, blocked, review, done. */
  statuses: KanbanStatusCount[];
  /** The status whose tasks are listed below; its chip is filled and checked. */
  selected: string;
  /** Called with the status key of the chip pressed. */
  onSelect?: (status: string) => void;
}

/**
 * The horizontally scrolling row of status chips that replaces the board's
 * columns on a phone (below 900px). One chip per status with its task count;
 * the selected one picks the list shown under it.
 */
export function KanbanStatusChips({
  statuses,
  selected,
  onSelect,
}: KanbanStatusChipsProps) {
  return (
    <div className="h-kanban-status-chips" role="tablist">
      {statuses.map((s) => {
        const on = s.name === selected;
        return (
          <button
            key={s.name}
            type="button"
            role="tab"
            aria-selected={on}
            className={[
              "h-kanban-status-chips__chip",
              on ? "h-kanban-status-chips__chip--selected" : null,
            ]
              .filter(Boolean)
              .join(" ")}
            onClick={() => onSelect?.(s.name)}
          >
            {on ? <Icon name="check" size={18} /> : null}
            {`${kanbanStatusLabel(s.name)} ${s.count}`}
          </button>
        );
      })}
    </div>
  );
}

/** `running` becomes `Running`, as the app labels statuses. */
export function kanbanStatusLabel(status: string): string {
  return status ? status[0].toUpperCase() + status.slice(1) : status;
}
