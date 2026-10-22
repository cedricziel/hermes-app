import { useState, type ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import { cx } from "../../platform";
import "./DisclosureTile.css";

export interface DisclosureTileProps {
  /** The always-visible header content (13px, one or more lines). */
  title: ReactNode;
  /** Open on first render. */
  defaultOpen?: boolean;
  /** Called when the header opens the tile (not when it closes). */
  onOpen?: () => void;
  /** The content shown while open. */
  children?: ReactNode;
}

/**
 * The app's `DisclosureTile` (a dense Material `ExpansionTile`): a 48px header
 * with a rotating chevron, and hairline rules above and below once open.
 * Material on every platform. Internal: the Working-tier activity cards draw
 * their header and details with it.
 */
export function DisclosureTile({
  title,
  defaultOpen = false,
  onOpen,
  children,
}: DisclosureTileProps) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className={cx("h-disclosure", open && "h-disclosure--open")}>
      <button
        type="button"
        className="h-disclosure__header"
        aria-expanded={open}
        onClick={() => {
          if (!open) onOpen?.();
          setOpen(!open);
        }}
      >
        <span className="h-disclosure__title">{title}</span>
        <Icon
          name="expand_more"
          apple={false}
          size={24}
          className="h-disclosure__chevron"
        />
      </button>
      {open ? <div className="h-disclosure__body">{children}</div> : null}
    </div>
  );
}
