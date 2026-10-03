import type { ReactNode } from "react";
import { Icon } from "../Icon/Icon";
import {
  AccountFooter,
  SidebarAction,
  SidebarBrand,
} from "../ThreadSidebar/ThreadSidebar";
import "./AppShell.css";

/** A top-level place in the app. Kanban and Schedules only exist while the server offers them. */
export type ShellDestination = "chat" | "kanban" | "schedules";

const destinationInfo: Record<
  ShellDestination,
  { icon: string; label: string }
> = {
  chat: { icon: "chat_bubble", label: "Chat" },
  kanban: { icon: "view_kanban", label: "Kanban" },
  schedules: { icon: "schedule", label: "Schedules" },
};

export interface ShellNavigationProps {
  /** The destinations to list, in order (Chat first). */
  destinations: ShellDestination[];
  /** The open destination: a filled row, bold label and filled icon. */
  current: ShellDestination;
  /** A destination row was clicked. */
  onSelect?: (destination: ShellDestination) => void;
}

/**
 * The shell's destinations as sidebar rows (Chat, Kanban, Schedules), for a
 * wide layout. Pass it as `navigation` to `ThreadSidebar`, so it sits under
 * the app name above "New chat".
 */
export function ShellNavigation({
  destinations,
  current,
  onSelect,
}: ShellNavigationProps) {
  return (
    <div className="h-shell-navigation">
      {destinations.map((d) => (
        <SidebarAction
          key={d}
          icon={destinationInfo[d].icon}
          filledIcon={d === current}
          label={destinationInfo[d].label}
          selected={d === current}
          onClick={() => onSelect?.(d)}
        />
      ))}
    </div>
  );
}

export interface ShellSidebarProps {
  /** The destinations rows, normally a `ShellNavigation`. */
  navigation: ReactNode;
  /** Account label for the footer ("Not connected" without one). */
  account?: string;
}

/** The 280px sidebar beside a page that has no thread list of its own (Kanban, Schedules): app name, destinations, account footer. */
export function ShellSidebar({ navigation, account }: ShellSidebarProps) {
  return (
    <aside className="h-shell-sidebar">
      <SidebarBrand />
      <div className="h-shell-sidebar__nav">{navigation}</div>
      <div className="h-shell-sidebar__spacer" />
      <AccountFooter label={account} />
    </aside>
  );
}

export interface AppShellProps {
  /**
   * The destinations the server offers, Chat first. With only Chat the shell
   * draws nothing of its own and shows `children` (and `sidebar`) bare.
   */
  destinations?: ShellDestination[];
  /** The open destination. */
  current?: ShellDestination;
  /**
   * `desktop` (900px and wider): destinations as rows in a 280px left
   * sidebar. `phone`: an 80px Material 3 navigation bar along the bottom.
   */
  layout?: "desktop" | "phone";
  /**
   * Desktop only: the left column. For Chat pass a `ThreadSidebar` with
   * `navigation={<ShellNavigation .../>}`; leave it out for Kanban and
   * Schedules to get the plain `ShellSidebar`.
   */
  sidebar?: ReactNode;
  /** Account label for the default `ShellSidebar`'s footer. */
  account?: string;
  /** A destination was picked in the sidebar or the bottom bar. */
  onSelect?: (destination: ShellDestination) => void;
  /** The open page: for Chat, a `ChatHeader` over the thread or a `WelcomeView`. */
  children?: ReactNode;
}

/**
 * The app's frame: switches between Chat, Kanban and Schedules with sidebar
 * rows on a wide screen or a bottom navigation bar on a phone, around the
 * open page. It fills its parent; give it a size.
 */
export function AppShell({
  destinations = ["chat", "kanban", "schedules"],
  current = "chat",
  layout = "desktop",
  sidebar,
  account,
  onSelect,
  children,
}: AppShellProps) {
  const single = destinations.length <= 1;
  if (layout === "phone") {
    return (
      <div className="h-app-shell h-app-shell--phone">
        <div className="h-app-shell__content">{children}</div>
        {single ? null : (
          <nav className="h-app-shell__bar" aria-label="Destinations">
            {destinations.map((d) => {
              const selected = d === current;
              return (
                <button
                  key={d}
                  type="button"
                  className={[
                    "h-app-shell__bar-item",
                    selected ? "h-app-shell__bar-item--selected" : null,
                  ]
                    .filter(Boolean)
                    .join(" ")}
                  aria-current={selected ? "page" : undefined}
                  onClick={() => onSelect?.(d)}
                >
                  <span className="h-app-shell__indicator">
                    <Icon
                      name={destinationInfo[d].icon}
                      filled={selected}
                      size={24}
                    />
                  </span>
                  <span className="h-app-shell__bar-label">
                    {destinationInfo[d].label}
                  </span>
                </button>
              );
            })}
          </nav>
        )}
      </div>
    );
  }
  const side =
    sidebar ??
    (single ? null : (
      <ShellSidebar
        account={account}
        navigation={
          <ShellNavigation
            destinations={destinations}
            current={current}
            onSelect={onSelect}
          />
        }
      />
    ));
  return (
    <div className="h-app-shell h-app-shell--desktop">
      {side ? <div className="h-app-shell__sidebar">{side}</div> : null}
      <div className="h-app-shell__content">{children}</div>
    </div>
  );
}
