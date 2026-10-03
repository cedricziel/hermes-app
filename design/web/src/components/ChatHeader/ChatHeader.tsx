import { IconButton } from "../IconButton/IconButton";
import {
  ThreadActionsButton,
  type ThreadAction,
} from "../ThreadSidebar/ThreadSidebar";
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
   * `desktop`: the 76px bar above a wide chat, 15px title, bottom border.
   * `phone`: the 64px app bar with a menu button that opens the sidebar drawer.
   */
  layout?: "desktop" | "phone";
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
  defaultMenuOpen = false,
  onOpenMenu,
  onShowConnection,
  onThreadAction,
}: ChatHeaderProps) {
  const hasMenu = title != null && remote;
  return (
    <header className={`h-chat-header h-chat-header--${layout}`}>
      {layout === "phone" ? (
        <span className="h-chat-header__leading">
          <IconButton
            icon="menu"
            label="Open navigation menu"
            onClick={onOpenMenu}
          />
        </span>
      ) : null}
      <h1 className="h-chat-header__title">{title ?? "Hermes"}</h1>
      {hasMenu ? (
        <ThreadActionsButton
          pinned={pinned}
          actionable
          includeCopyTranscript
          defaultOpen={defaultMenuOpen}
          onAction={onThreadAction}
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
