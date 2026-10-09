import { useContext, useLayoutEffect, type ReactNode, type Ref } from "react";
import { Icon } from "../Icon/Icon";
import type { CupertinoIconName } from "../Icon/cupertinoIcons";
import { cx, PlatformScope, ShellChromeContext } from "../../platform";
import "./MacToolbar.css";

export interface MacToolbarButtonProps {
  /** Material Symbols name; drawn as its CupertinoIcons pair (`edit_square` a square and pencil, `ios_share` the share arrow). */
  icon: string;
  /** The glyph by Flutter's `CupertinoIcons.*` name, where the Material name pairs with another one: `pin` for an unpinned chat's Pin (AppIcons.pinOutline), whose `push_pin` would draw `pin_slash`. */
  apple?: CupertinoIconName;
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
  apple,
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
      <Icon name={icon} apple={apple} size={18} />
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
  /** The placeholder: "Search" (default), "Search skills". */
  hint?: string;
  /** A search is open: the field stays 240px wide and shows the clear button. */
  active?: boolean;
  /** Draw the focus ring, for previews (the field also shows it while it has the focus). */
  focused?: boolean;
  onChange?: (query: string) => void;
  /** The field got the focus: open a search. */
  onBegin?: () => void;
  /** The clear button or Escape: end the search. */
  onEnd?: () => void;
  /** The text input, for a page that focuses it (Command-F). */
  inputRef?: Ref<HTMLInputElement>;
}

/** The toolbar's search field: 26px tall and 180px wide, 240px with a focus ring while in use; Escape and the clear button end the search. */
export function MacToolbarSearchField({
  query = "",
  hint = "Search",
  active = false,
  focused = false,
  onChange,
  onBegin,
  onEnd,
  inputRef,
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
        ref={inputRef}
        type="search"
        placeholder={hint}
        aria-label={hint}
        value={query}
        onChange={(e) => onChange?.(e.target.value)}
        onFocus={onBegin}
        onKeyDown={(e) => {
          if (e.key !== "Escape") return;
          if (query) e.stopPropagation();
          onEnd?.();
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
  /** An 11px muted line under the title: "default · claude-opus-4", "main · all profiles · 12 tasks", "4 jobs". May be an element, such as a subtitle that opens a menu. */
  subtitle?: ReactNode;
  /** A control before the title, 8px from it, such as a pushed page's back `MacToolbarButton`; the bar then starts 12px from the edge instead of 20px. */
  leading?: ReactNode;
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
  /** Space in px before the title in a window with no sidebar at all: 86 (the traffic lights' 78 and 8) in a conversation window. Overrides the 20px default and the hidden sidebar's 78px. */
  leadingInset?: number;
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
  leading,
  actions,
  border = false,
  sidebarHidden,
  onShowSidebar,
  leadingInset,
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
        style={
          leadingInset !== undefined
            ? { paddingLeft: leadingInset }
            : leading && !hidden
              ? { paddingLeft: 12 }
              : undefined
        }
      >
        {hidden && showSidebar ? (
          <MacToolbarButton
            icon="left_panel_open"
            label="Show sidebar"
            shortcut="⌃⌘S"
            onClick={showSidebar}
          />
        ) : null}
        {leading}
        <div className="h-mac-toolbar__title">
          <span className="h-mac-toolbar__heading">{title}</span>
          {subtitle ? (
            <span
              className={cx(
                "h-mac-toolbar__subtitle",
                typeof subtitle !== "string" && "h-mac-toolbar__subtitle--node",
              )}
            >
              {subtitle}
            </span>
          ) : null}
        </div>
        {actions ? (
          <div className="h-mac-toolbar__actions">{actions}</div>
        ) : null}
      </header>
    </PlatformScope>
  );
}
