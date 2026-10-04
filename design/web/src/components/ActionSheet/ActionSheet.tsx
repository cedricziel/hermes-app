import { cx } from "../../platform";
import "./ActionSheet.css";

/** One button of an `ActionSheet`. */
export interface ActionSheetAction {
  /** "Rename", "Pause", "Delete". */
  label: string;
  /** Drawn in Apple's system red: Delete, Remove. */
  destructive?: boolean;
  /** The action was picked; the sheet closes. */
  onPress?: () => void;
}

export interface ActionSheetProps {
  /** One line naming what the actions apply to: the row's title, cut with an ellipsis. */
  title?: string;
  /** The actions top to bottom, destructive ones last. Cancel is added below them. */
  actions: ActionSheetAction[];
  /** Cancel, or a tap on the scrim. */
  onCancel?: () => void;
  /**
   * `overlay` (default): covers its nearest positioned ancestor (give the
   * screen `position: relative`) with the scrim and puts the sheet at the
   * bottom, 8px from the edges. `inline`: the sheet alone, in the flow.
   */
  presentation?: "overlay" | "inline";
  className?: string;
}

/**
 * The iOS action sheet a long press on a list row opens (a chat, a scheduled
 * job, an MCP server, a plugin), Flutter's `CupertinoActionSheet`: a blurred
 * group of 57px actions under the row's title, in the primary color with
 * destructive ones in red, and a separate bold Cancel. iOS only: on a Mac a
 * right-click opens the row's `Menu`, on Material the row's "…" menu.
 */
export function ActionSheet({
  title,
  actions,
  onCancel,
  presentation = "overlay",
  className,
}: ActionSheetProps) {
  const sheet = (
    <div
      className={cx("h-action-sheet", presentation === "inline" && className)}
      role="dialog"
      aria-label={title}
      onClick={(e) => e.stopPropagation()}
    >
      <div className="h-action-sheet__group">
        {title ? <div className="h-action-sheet__title">{title}</div> : null}
        {actions.map((action) => (
          <button
            key={action.label}
            type="button"
            className={cx(
              "h-action-sheet__action",
              action.destructive && "h-action-sheet__action--destructive",
            )}
            onClick={action.onPress}
          >
            {action.label}
          </button>
        ))}
      </div>
      <button
        type="button"
        className="h-action-sheet__action h-action-sheet__cancel"
        onClick={onCancel}
      >
        Cancel
      </button>
    </div>
  );
  if (presentation === "inline") return sheet;
  return (
    <div
      className={cx("h-action-sheet-overlay", className)}
      onClick={(e) => {
        e.stopPropagation();
        onCancel?.();
      }}
    >
      {sheet}
    </div>
  );
}
