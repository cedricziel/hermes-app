import { useContext } from "react";
import { IconButton } from "../IconButton/IconButton";
import {
  ThreadActionsButton,
  type ThreadAction,
} from "../ThreadSidebar/ThreadSidebar";
import {
  ShellChromeContext,
  cx,
  usePlatform,
  type Platform,
} from "../../platform";
import "./ChatHeader.css";

export interface ChatHeaderProps {
  /** The open chat's title; null or omitted before one is picked, which shows "Hermes". */
  title?: string | null;
  /**
   * The dashboard holds the open chat (default true): a "…" menu offers Copy
   * transcript, Rename, Pin, Archive and Delete. A local chat (false) or no
   * chat gets no "…" button.
   */
  remote?: boolean;
  /** The open chat is pinned; its menu then reads "Unpin". */
  pinned?: boolean;
  /**
   * `desktop`: the bar above a wide chat (iPad landscape, Mac, Windows,
   * Linux). `phone`: the narrow bar with a menu button that opens the sidebar
   * drawer. Heights: material 76px desktop and 64px phone, apple 52px Mac
   * toolbar and 44px phone navigation bar.
   */
  layout?: "desktop" | "phone";
  /**
   * `material` (default): 15px title, bottom border (desktop); 16px left
   * aligned title (phone). `apple` phone: a 44px navigation bar, the 17px
   * semibold title centred, a hairline under it. `apple` desktop: the 52px
   * unified Mac toolbar, no rule underneath; inside an `AppShell` whose
   * sidebar is collapsed it leaves 78px for the traffic lights and shows the
   * sidebar toggle. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Open the "…" menu initially, for previews. */
  defaultMenuOpen?: boolean;
  /** The phone menu button was pressed (opens the thread drawer). */
  onOpenMenu?: () => void;
  /** The info button was pressed (shows the connection details). */
  onShowConnection?: () => void;
  /** An entry of the "…" menu was picked. */
  onThreadAction?: (action: ThreadAction) => void;
}

/**
 * The bar above the chat: the open thread's title, its "…" actions and the
 * connection-details info button. On a phone it is the app bar with the
 * drawer's menu button in front.
 */
export function ChatHeader({
  title,
  remote = true,
  pinned = false,
  layout = "desktop",
  platform,
  defaultMenuOpen = false,
  onOpenMenu,
  onShowConnection,
  onThreadAction,
}: ChatHeaderProps) {
  const apple = usePlatform(platform) === "apple";
  const { sidebarCollapsed, toggleSidebar } = useContext(ShellChromeContext);
  const hasMenu = title != null && remote;
  const mac = apple && layout === "desktop";
  const showToggle = mac && sidebarCollapsed;
  return (
    <header
      className={cx(
        "h-chat-header",
        `h-chat-header--${layout}`,
        apple && "h-chat-header--apple",
        showToggle && "h-chat-header--collapsed",
      )}
    >
      {layout === "phone" ? (
        <span className="h-chat-header__leading">
          <IconButton
            icon="menu"
            label="Open navigation menu"
            onClick={onOpenMenu}
          />
        </span>
      ) : null}
      {showToggle ? (
        <IconButton
          icon="left_panel_open"
          label="Show sidebar"
          onClick={toggleSidebar}
        />
      ) : null}
      <h1 className="h-chat-header__title">{title ?? "Hermes"}</h1>
      {hasMenu ? (
        <ThreadActionsButton
          pinned={pinned}
          actionable
          includeCopyTranscript
          defaultOpen={defaultMenuOpen}
          onAction={onThreadAction}
          platform={apple ? "apple" : "material"}
          layout={layout}
        />
      ) : null}
      <span className="h-chat-header__info">
        <IconButton
          icon="info"
          label="Connection details"
          onClick={onShowConnection}
        />
      </span>
    </header>
  );
}
