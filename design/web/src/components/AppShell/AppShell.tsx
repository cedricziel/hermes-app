import type { ReactNode } from "react";
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
 * The shell's destinations as sidebar rows (Chat, Kanban, Schedules), in the
 * wide sidebar and the phone drawer alike. Pass it as `navigation` to
 * `ThreadSidebar`, so it sits under the app name above "New chat".
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
   * `desktop` (900px and wider): the sidebar sits beside the page.
   * `phone` (narrower): there is no bottom bar; the same sidebar is a 280px
   * drawer over the page, opened from the menu button in the page's app bar.
   */
  layout?: "desktop" | "phone";
  /** Phone only: show the drawer open over a dimmed page. */
  drawerOpen?: boolean;
  /**
   * The left column (desktop) or the drawer (phone). For Chat pass a
   * `ThreadSidebar` with `navigation={<ShellNavigation .../>}`; leave it out
   * for Kanban and Schedules to get the plain `ShellSidebar`.
   */
  sidebar?: ReactNode;
  /** Account label for the default `ShellSidebar`'s footer. */
  account?: string;
  /** A destination was picked in the sidebar or the drawer. */
  onSelect?: (destination: ShellDestination) => void;
  /** The scrim beside the open drawer was clicked. */
  onCloseDrawer?: () => void;
  /** The open page: for Chat, a `ChatHeader` over the thread or a `WelcomeView`. */
  children?: ReactNode;
}

/**
 * The app's frame around the open page. The destinations (Chat, Kanban,
 * Schedules) are rows at the top of the sidebar: beside the page on a wide
 * screen, in a drawer on a phone. It fills its parent; give it a size.
 */
export function AppShell({
  destinations = ["chat", "kanban", "schedules"],
  current = "chat",
  layout = "desktop",
  drawerOpen = false,
  sidebar,
  account,
  onSelect,
  onCloseDrawer,
  children,
}: AppShellProps) {
  const single = destinations.length <= 1;
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
  if (layout === "phone") {
    return (
      <div className="h-app-shell h-app-shell--phone">
        <div className="h-app-shell__content">{children}</div>
        {drawerOpen && side ? (
          <>
            <div
              className="h-app-shell__scrim"
              aria-hidden="true"
              onClick={onCloseDrawer}
            />
            <div className="h-app-shell__drawer">{side}</div>
          </>
        ) : null}
      </div>
    );
  }
  return (
    <div className="h-app-shell h-app-shell--desktop">
      {side ? <div className="h-app-shell__sidebar">{side}</div> : null}
      <div className="h-app-shell__content">{children}</div>
    </div>
  );
}
