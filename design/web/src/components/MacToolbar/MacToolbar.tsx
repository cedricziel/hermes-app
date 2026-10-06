import { useContext, useLayoutEffect, type ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import { cx, PlatformScope, ShellChromeContext } from "../../platform";
import "./MacToolbar.css";

export interface MacToolbarButtonProps {
  /** Material Symbols name; drawn as its CupertinoIcons pair (`edit_square` a square and pencil, `ios_share` the share arrow). */
  icon: string;
  /** Accessible name and tooltip: "New Chat". */
  label: string;
  /** Key equivalent shown after the label in the tooltip: "⌘N". */
  shortcut?: string;
  /** A toggle that is on (an inspector shown, a filter in effect): the button stays filled. */
  selected?: boolean;
  disabled?: boolean;
  onClick?: () => void;
}

/** A borderless 28px toolbar button with an 18px glyph, filled under the pointer and while `selected`. */
export function MacToolbarButton({
  icon,
  label,
  shortcut,
  selected,
  disabled,
  onClick,
}: MacToolbarButtonProps) {
  return (
    <button
      type="button"
      className={cx(
        "h-mac-toolbar__button",
        selected && "h-mac-toolbar__button--selected",
      )}
      aria-label={label}
      aria-pressed={selected}
      title={shortcut ? `${label} ${shortcut}` : label}
      disabled={disabled}
      onClick={onClick}
    >
      <Icon name={icon} size={18} />
    </button>
  );
}

/** The 1x20px rule between groups of toolbar buttons. */
export function MacToolbarSeparator() {
  return <span className="h-mac-toolbar__separator" aria-hidden="true" />;
}

export interface MacToolbarSearchFieldProps {
  /** The typed query. */
  query?: string;
  /** A search is open: the field stays 240px wide and shows the clear button. */
  active?: boolean;
  /** Draw the focus ring, for previews (the field also shows it while it has the focus). */
  focused?: boolean;
  onChange?: (query: string) => void;
  /** The field got the focus: open a search. */
  onBegin?: () => void;
  /** The clear button or Escape: end the search. */
  onEnd?: () => void;
}

/** The toolbar's search field: 26px tall and 180px wide, 240px with a focus ring while in use; Escape and the clear button end the search. */
export function MacToolbarSearchField({
  query = "",
  active = false,
  focused = false,
  onChange,
  onBegin,
  onEnd,
}: MacToolbarSearchFieldProps) {
  return (
    <label
      className={cx(
        "h-mac-toolbar__search",
        (active || focused) && "h-mac-toolbar__search--wide",
        focused && "h-mac-toolbar__search--focused",
      )}
    >
      <Icon name="search" size={14} className="h-muted" />
      <input
        type="search"
        placeholder="Search"
        value={query}
        onChange={(e) => onChange?.(e.target.value)}
        onFocus={onBegin}
        onKeyDown={(e) => {
          if (e.key === "Escape") onEnd?.();
        }}
      />
      {query || active ? (
        <button
          type="button"
          className="h-mac-toolbar__search-clear"
          aria-label="End search"
          onClick={onEnd}
        >
          <Icon name="cancel" filled size={14} />
        </button>
      ) : null}
    </label>
  );
}

export interface MacToolbarProps {
  /** The page's title, 13px bold: the open chat, "Kanban", "Schedules". */
  title: string;
  /** An 11px muted line under the title: "default · claude-opus-4", "main · all profiles · 12 tasks", "4 jobs". */
  subtitle?: string;
  /**
   * The trailing controls, 4px apart: `MacToolbarButton`s, a
   * `MacToolbarSeparator` between groups, a `MacToolbarSearchField`, or a
   * small control such as a `SegmentedControl` (a menu button is a
   * `MacToolbarButton` inside a `MenuAnchor`).
   */
  actions?: ReactNode;
  /** A hairline under the bar, for a page whose content has no surface of its own at the top (Kanban, Schedules). */
  border?: boolean;
  /**
   * The sidebar is hidden: the bar leaves 78px for the traffic lights and
   * starts with the show-sidebar button. Defaults to the enclosing
   * `AppShell`'s state.
   */
  sidebarHidden?: boolean;
  /** The show-sidebar button was pressed; defaults to the enclosing `AppShell`'s toggle. */
  onShowSidebar?: () => void;
}

/**
 * The unified toolbar at the top of a page in a Mac window (macOS only): 52px
 * high, the title over an optional subtitle at the leading edge, and the
 * page's controls at the trailing edge as borderless 28px buttons with
 * Cupertino glyphs. The chat's has New Chat, Copy Transcript, Connection
 * Details and the search field; Kanban's New Task, a profile filter, the
 * board menu and the inspector toggle; Schedules' a scope control, Refresh
 * and New Schedule. With the sidebar hidden it clears the traffic lights and
 * leads with the show-sidebar button. Draws the Apple glyphs whatever the
 * provider's platform.
 */
export function MacToolbar({
  title,
  subtitle,
  actions,
  border = false,
  sidebarHidden,
  onShowSidebar,
}: MacToolbarProps) {
  const shell = useContext(ShellChromeContext);
  const hidden = sidebarHidden ?? shell.sidebarCollapsed;
  const showSidebar = onShowSidebar ?? shell.toggleSidebar;
  // Inside a Mac AppShell this bar draws the show-sidebar button, so the
  // shell leaves out its own strip.
  const claim = shell.toggleSidebar ? shell.claimSidebarToggle : undefined;
  useLayoutEffect(() => claim?.(), [claim]);
  return (
    <PlatformScope platform="apple">
      <header
        className={cx(
          "h-mac-toolbar",
          border && "h-mac-toolbar--border",
          hidden && "h-mac-toolbar--sidebar-hidden",
        )}
      >
        {hidden && showSidebar ? (
          <MacToolbarButton
            icon="left_panel_open"
            label="Show sidebar"
            shortcut="⌃⌘S"
            onClick={showSidebar}
          />
        ) : null}
        <div className="h-mac-toolbar__title">
          <span className="h-mac-toolbar__heading">{title}</span>
          {subtitle ? (
            <span className="h-mac-toolbar__subtitle">{subtitle}</span>
          ) : null}
        </div>
        {actions ? (
          <div className="h-mac-toolbar__actions">{actions}</div>
        ) : null}
      </header>
    </PlatformScope>
  );
}
