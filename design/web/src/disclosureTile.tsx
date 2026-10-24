import { useState, type KeyboardEvent, type ReactNode } from "react";
import { Icon } from "./components/Icon/Icon";
import { cx } from "./platform";
import "./disclosureTile.css";

export interface DisclosureTileProps {
  /** The header's content: a plain title, or a row with an icon and a dismiss button. */
  title: ReactNode;
  /** The header text size: 14 (default) for the reference cards, 13 for the Working-tier ones. */
  titleSize?: 13 | 14;
  /** Start with the details showing. */
  defaultOpen?: boolean;
  /** Called with the new open state when the header is pressed. */
  onToggle?: (open: boolean) => void;
  /** Caps the details at this height in px and scrolls beyond it. */
  maxBodyHeight?: number;
  /** The details shown while open. */
  children?: ReactNode;
}

/**
 * The app's `DisclosureTile` (a dense Material `ExpansionTile`), which every
 * activity card sits in: a 48px header with the title and a rotating
 * chevron, and while open a hairline above and below the details. Material
 * on every platform. The header is a `role="button"` element rather than a
 * `<button>`, so a title may hold its own buttons (a notice's dismiss).
 */
export function DisclosureTile({
  title,
  titleSize = 14,
  defaultOpen = false,
  onToggle,
  maxBodyHeight,
  children,
}: DisclosureTileProps) {
  const [open, setOpen] = useState(defaultOpen);
  const toggle = () => {
    setOpen(!open);
    onToggle?.(!open);
  };
  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.target !== event.currentTarget) return;
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      toggle();
    }
  };
  return (
    <div className={cx("h-disclosure", open && "h-disclosure--open")}>
      <div
        className="h-disclosure__header"
        role="button"
        tabIndex={0}
        aria-expanded={open}
        onClick={toggle}
        onKeyDown={onKeyDown}
      >
        <div
          className={cx(
            "h-disclosure__title",
            titleSize === 13 && "h-disclosure__title--small",
          )}
        >
          {title}
        </div>
        <Icon
          name="expand_more"
          apple={false}
          size={24}
          className="h-disclosure__chevron"
        />
      </div>
      {open ? (
        <div
          className="h-disclosure__body"
          style={
            maxBodyHeight
              ? { maxHeight: maxBodyHeight, overflowY: "auto" }
              : undefined
          }
        >
          {children}
        </div>
      ) : null}
    </div>
  );
}
