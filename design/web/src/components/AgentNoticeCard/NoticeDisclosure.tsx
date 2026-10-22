import { useState, type KeyboardEvent, type ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import "./NoticeDisclosure.css";

export interface NoticeDisclosureProps {
  /** The header's content: a plain title or a row with an icon and a dismiss button. */
  title: ReactNode;
  /** Start with the details showing. */
  defaultOpen?: boolean;
  /** Called with the new open state when the header is pressed. */
  onToggle?: (open: boolean) => void;
  /** Caps the details at this height in px and scrolls beyond it. */
  maxBodyHeight?: number;
  /** The details: usually 12px-padded text lines. */
  children?: ReactNode;
}

/**
 * The expansion tile every activity reference card sits in (the app's
 * `DisclosureTile`, a dense Material `ExpansionTile`): a 48px header with the
 * title and a chevron, and while open a hairline above and below the details.
 * Internal helper of the activity cards.
 */
export function NoticeDisclosure({
  title,
  defaultOpen = false,
  onToggle,
  maxBodyHeight,
  children,
}: NoticeDisclosureProps) {
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
    <div
      className={["h-notice-tile", open ? "h-notice-tile--open" : null]
        .filter(Boolean)
        .join(" ")}
    >
      <div
        className="h-notice-tile__header"
        role="button"
        tabIndex={0}
        aria-expanded={open}
        onClick={toggle}
        onKeyDown={onKeyDown}
      >
        <div className="h-notice-tile__title">{title}</div>
        <Icon
          name="expand_more"
          apple={false}
          size={24}
          className="h-notice-tile__chevron"
        />
      </div>
      {open ? (
        <div
          className="h-notice-tile__body"
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
