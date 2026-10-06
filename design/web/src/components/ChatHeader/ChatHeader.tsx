import { IconButton } from "../IconButton/IconButton";
import {
  MacToolbar,
  MacToolbarButton,
  MacToolbarSearchField,
} from "../MacToolbar/MacToolbar";
import { Menu, MenuAnchor } from "../Menu/Menu";
import {
  ThreadActionsButton,
  type ThreadAction,
} from "../ThreadSidebar/ThreadSidebar";
import { useContext, useEffect, useRef, useState } from "react";
import {
  cx,
  PlatformScope,
  ShellChromeContext,
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
   * Mac: the chat's `MacToolbar`, the title over `subtitle`, then New Chat,
   * Copy Transcript, Connection Details and search (see `windowSize`); no
   * "…" menu (a chat's actions are in the sidebar's context menu). Inside an
   * `AppShell` whose sidebar is hidden it clears the traffic lights and
   * shows the sidebar toggle. Inherits the provider's platform.
   */
  platform?: Platform;
  /**
   * Under `apple`, `mac` or `touch`; see `AppleDevice`. A `phone` layout is
   * touch; a `desktop` one follows the enclosing `AppShell`, else `mac`. Pass
   * `touch` for a full-screen iPad outside an `AppShell`.
   */
  device?: AppleDevice;
  /** Open the "…" menu initially, for previews: the chat's actions on touch and Material, the compact Mac toolbar's Copy Transcript and Connection Details. */
  defaultMenuOpen?: boolean;
  /** The phone menu button was pressed (opens the thread drawer). */
  onOpenMenu?: () => void;
  /** The info button was pressed (shows the connection details). */
  onShowConnection?: () => void;
  /** An entry of the "…" menu was picked. */
  onThreadAction?: (action: ThreadAction) => void;
  /** Mac: the line under the title, "profile · model" ("default · claude-opus-4"). */
  subtitle?: string;
  /**
   * Mac: how much room the window gives the toolbar. `wide` (1000px and up)
   * shows the search field; `medium` a search button until a search is
   * open; `compact` (under 760px) also folds Copy Transcript and Connection
   * Details into a "…" menu. Defaults to `compact` inside a compact
   * `AppShell`, else `wide`.
   */
  windowSize?: "wide" | "medium" | "compact";
  /** Mac: the search query, shown in the toolbar field. */
  searchQuery?: string;
  /** Mac: a search is open (the field shows even in a medium window, wide, with its clear button). */
  searchActive?: boolean;
  /** Mac: New Chat (⌘N). */
  onNewChat?: () => void;
  /** Mac: Copy Transcript; without it the button is disabled (no chat open). */
  onCopyTranscript?: () => void;
  /** Mac: the search button or the field's focus opened a search. */
  onSearchBegin?: () => void;
  onSearchChange?: (query: string) => void;
  /** Mac: the field's clear button or Escape ended the search. */
  onSearchEnd?: () => void;
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
  subtitle,
  windowSize,
  searchQuery = "",
  searchActive = false,
  onNewChat,
  onCopyTranscript,
  onSearchBegin,
  onSearchChange,
  onSearchEnd,
}: ChatHeaderProps) {
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const device = useAppleDevice(layout, deviceProp);
  const hasMenu = title != null && remote;
  const shell = useContext(ShellChromeContext);
  if (apple && device === "mac") {
    return (
      <MacChatToolbar
        title={title ?? "Hermes"}
        subtitle={subtitle}
        windowSize={windowSize ?? (shell.compact ? "compact" : "wide")}
        defaultMoreOpen={defaultMenuOpen}
        searchQuery={searchQuery}
        searchActive={searchActive}
        onNewChat={onNewChat}
        onCopyTranscript={onCopyTranscript}
        onShowConnection={onShowConnection}
        onSearchBegin={onSearchBegin}
        onSearchChange={onSearchChange}
        onSearchEnd={onSearchEnd}
      />
    );
  }
  return (
    <PlatformScope platform={resolvedPlatform}>
      <header
        className={cx(
          "h-chat-header",
          `h-chat-header--${layout}`,
          apple && "h-chat-header--ios",
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
        <h1 className="h-chat-header__title">{title ?? "Hermes"}</h1>
        {hasMenu ? (
          <ThreadActionsButton
            pinned={pinned}
            actionable
            includeCopyTranscript
            defaultOpen={defaultMenuOpen}
            onAction={onThreadAction}
            layout="phone"
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

/** The chat's Mac toolbar (the app's `MacChatToolbar`). */
function MacChatToolbar({
  title,
  defaultMoreOpen,
  subtitle,
  windowSize,
  searchQuery,
  searchActive,
  onNewChat,
  onCopyTranscript,
  onShowConnection,
  onSearchBegin,
  onSearchChange,
  onSearchEnd,
}: Pick<
  ChatHeaderProps,
  | "subtitle"
  | "searchQuery"
  | "searchActive"
  | "onNewChat"
  | "onCopyTranscript"
  | "onShowConnection"
  | "onSearchBegin"
  | "onSearchChange"
  | "onSearchEnd"
> & {
  title: string;
  windowSize: "wide" | "medium" | "compact";
  defaultMoreOpen: boolean;
}) {
  const [moreOpen, setMoreOpen] = useState(defaultMoreOpen);
  const showField = searchActive || windowSize === "wide";
  const root = useRef<HTMLSpanElement>(null);
  // Command-F opens the search: it focuses the field, or asks for it where
  // the window only has room for the button.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!(e.metaKey && e.key.toLowerCase() === "f")) return;
      e.preventDefault();
      const field = root.current?.querySelector<HTMLInputElement>(
        ".h-mac-toolbar__search input",
      );
      if (field) field.focus();
      else onSearchBegin?.();
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [onSearchBegin]);
  return (
    <span ref={root} className="h-chat-header__mac">
      <MacToolbar
        title={title}
        subtitle={subtitle}
        actions={
          <>
            <MacToolbarButton
              icon="edit_square"
              label="New Chat"
              shortcut="⌘N"
              onClick={onNewChat}
            />
            {windowSize === "compact" ? (
              <MenuAnchor>
                <MacToolbarButton
                  icon="more_horiz"
                  label="More"
                  onClick={() => setMoreOpen((o) => !o)}
                />
                {moreOpen ? (
                  <Menu
                    align="end"
                    device="mac"
                    items={[
                      {
                        value: "copy",
                        label: "Copy Transcript",
                        disabled: !onCopyTranscript,
                      },
                      { value: "connection", label: "Connection Details" },
                    ]}
                    onSelect={(item) => {
                      setMoreOpen(false);
                      if (item.value === "copy") onCopyTranscript?.();
                      else onShowConnection?.();
                    }}
                  />
                ) : null}
              </MenuAnchor>
            ) : (
              <>
                <MacToolbarButton
                  icon="ios_share"
                  label="Copy Transcript"
                  disabled={!onCopyTranscript}
                  onClick={onCopyTranscript}
                />
                <MacToolbarButton
                  icon="info_outline"
                  label="Connection Details"
                  onClick={onShowConnection}
                />
              </>
            )}
            {showField ? (
              <MacToolbarSearchField
                query={searchQuery}
                active={searchActive}
                onChange={onSearchChange}
                onBegin={onSearchBegin}
                onEnd={onSearchEnd}
              />
            ) : (
              <MacToolbarButton
                icon="search"
                label="Search"
                shortcut="⌘F"
                onClick={onSearchBegin}
              />
            )}
          </>
        }
      />
    </span>
  );
}
