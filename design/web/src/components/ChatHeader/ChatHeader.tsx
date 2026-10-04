import { useContext } from "react";
import { IconButton } from "../IconButton/IconButton";
import {
  ThreadActionsButton,
  type ThreadAction,
} from "../ThreadSidebar/ThreadSidebar";
import {
  ShellChromeContext,
  cx,
  PlatformScope,
  useAppleDevice,
  usePlatform,
  type AppleDevice,
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
   * toolbar and 44px iPhone and iPad navigation bar.
   */
  layout?: "desktop" | "phone";
  /**
   * `material` (default): 15px title, bottom border (desktop); 16px left
   * aligned title (phone). `apple` on touch (iPhone, iPad): a 44px navigation
   * bar, the 17px semibold title centred, a hairline under it. `apple` on a
   * Mac: the 52px unified toolbar, no rule underneath; inside an `AppShell`
   * whose sidebar is collapsed it leaves 78px for the traffic lights and
   * shows the sidebar toggle. Inherits the provider's platform.
   */
  platform?: Platform;
  /**
   * Under `apple`, `mac` or `touch`; see `AppleDevice`. A `phone` layout is
   * touch; a `desktop` one follows the enclosing `AppShell`, else `mac`. Pass
   * `touch` for a full-screen iPad outside an `AppShell`.
   */
  device?: AppleDevice;
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
  device: deviceProp,
  defaultMenuOpen = false,
  onOpenMenu,
  onShowConnection,
  onThreadAction,
}: ChatHeaderProps) {
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const { sidebarCollapsed, toggleSidebar } = useContext(ShellChromeContext);
  const device = useAppleDevice(layout, deviceProp);
  const hasMenu = title != null && remote;
  const mac = apple && device === "mac";
  const showToggle = mac && sidebarCollapsed;
  return (
    <PlatformScope platform={resolvedPlatform}>
      <header
        className={cx(
          "h-chat-header",
          `h-chat-header--${layout}`,
          apple && (mac ? "h-chat-header--mac" : "h-chat-header--ios"),
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
            layout={mac ? "desktop" : "phone"}
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
    </PlatformScope>
  );
}
