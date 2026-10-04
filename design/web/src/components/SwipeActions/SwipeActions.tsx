import type { CSSProperties, ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import {
  cx,
  usePlatform,
  useRowDevice,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./SwipeActions.css";

/** One action a swipe reveals. */
export interface SwipeAction {
  /** Text under the icon: "Delete", "Remove", "Pin". */
  label: string;
  /** Material Symbols name, white on the action's color. */
  icon: string;
  /** `red` (default): a destructive action, Apple's system red. `orange`: Pin, Apple's system orange. */
  color?: "red" | "orange";
  /** The action was tapped. */
  onPress?: () => void;
}

export interface SwipeActionsProps {
  /** The row: a thread, a scheduled job, an MCP server, a plugin. */
  children: ReactNode;
  /** What a swipe from the trailing edge (leftwards) reveals: the row's destructive actions, Delete or Remove. */
  actions: SwipeAction[];
  /** What a swipe from the leading edge (rightwards) reveals: Pin on a chat. Usually none. */
  leadingActions?: SwipeAction[];
  /** Draw the row swiped open, for a preview: `trailing` (or `true`) shows `actions`, `leading` shows `leadingActions`. Static: there is no drag gesture here. */
  revealed?: boolean | "leading" | "trailing";
  /** Swipe actions exist only under `apple` on touch; elsewhere the row is drawn as is. Inherits the provider's platform. */
  platform?: Platform;
  /** `touch` (default; iPhone, iPad) or `mac`. Inherited from the enclosing `AppShell`. On a Mac the row has no swipe: a right-click opens its menu instead. */
  device?: AppleDevice;
  /** Class on the clipping wrapper, to give it the row's margins or corners (an inset grouped list). */
  className?: string;
  style?: CSSProperties;
}

/**
 * The iOS way to act on a list row (flutter_slidable in the app): a swipe
 * from the trailing edge slides the row aside and shows its destructive
 * actions in red across 30% of the row, a swipe from the leading edge shows
 * Pin in orange on a chat. A long press opens an `ActionSheet` with every
 * action. On Material and on a Mac the row is drawn unchanged.
 */
export function SwipeActions({
  children,
  actions,
  leadingActions = [],
  revealed = false,
  platform,
  device,
  className,
  style,
}: SwipeActionsProps) {
  const apple = usePlatform(platform) === "apple";
  const touch = useRowDevice(device) === "touch";
  if (!apple || !touch) return <>{children}</>;
  const side =
    (revealed === true || revealed === "trailing") && actions.length
      ? "trailing"
      : revealed === "leading" && leadingActions.length
        ? "leading"
        : null;
  return (
    <div className={cx("h-swipe", className)} style={style}>
      <div className={cx("h-swipe__row", side && `h-swipe__row--${side}`)}>
        {children}
      </div>
      {side ? (
        <div className={cx("h-swipe__pane", `h-swipe__pane--${side}`)}>
          {(side === "trailing" ? actions : leadingActions).map((action) => (
            <button
              key={action.label}
              type="button"
              className={cx(
                "h-swipe__action",
                action.color === "orange" && "h-swipe__action--orange",
              )}
              onClick={action.onPress}
            >
              <Icon name={action.icon} size={22} />
              <span>{action.label}</span>
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}
