import {
  useContext,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from "react";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import {
  ShellChromeContext,
  cx,
  PlatformScope,
  usePlatform,
  type Platform,
} from "../../platform";
import "./ThreadSidebar.css";

/**
 * Which device a component is laid out for. `phone` is touch (iPhone, iPad):
 * 44px bars and rows, iOS menus. `desktop` is pointer (Mac, and every
 * Material platform): compact rows, Mac menus. Only matters under `apple`.
 */
export type DeviceLayout = "desktop" | "phone";

type MenuVariant = "material" | "ios" | "mac";

function menuVariant(apple: boolean, layout: DeviceLayout): MenuVariant {
  if (!apple) return "material";
  return layout === "phone" ? "ios" : "mac";
}

/** One chat in the sidebar's thread list. */
export interface ThreadItem {
  /** Stable id, matched against `selectedId`. */
  id: string;
  /** The chat's title, cut with an ellipsis when it does not fit one line. */
  title: string;
  /** Pinned chats show a small pin before the title. */
  pinned?: boolean;
  /**
   * The dashboard holds this chat (default true), so it gets the "…" menu with
   * Rename, Pin, Archive and Delete. A local or mock chat (false) has no menu.
   */
  remote?: boolean;
}

/** What a chat's "…" menu asks for. `pin` toggles: it reads "Unpin" on a pinned chat. */
export type ThreadAction =
  "copy-transcript" | "rename" | "pin" | "archive" | "delete";

/** An entry of the sidebar's collapsible "More" section. */
export interface SidebarMoreEntry {
  /** Material Symbols icon name. */
  icon: string;
  /** Row label, e.g. "MCP servers". */
  label: string;
  /** Called when the row is clicked. */
  onClick?: () => void;
}

/** What the account menu in the sidebar footer asks for. */
export type AccountAction =
  | "appearance"
  | "notifications"
  | "app-lock"
  | "about"
  | "sign-out"
  | "change-server";

/** The six entries the app puts behind "More", in its order. */
export const DEFAULT_MORE_ENTRIES: SidebarMoreEntry[] = [
  { icon: "person", label: "Profiles" },
  { icon: "extension", label: "Skills" },
  { icon: "smart_toy", label: "Bots" },
  { icon: "extension", label: "Plugins" },
  { icon: "power", label: "MCP servers" },
  { icon: "tune", label: "Helper models" },
];

const rowRadiusClass = "h-sidebar-row";

interface MenuItem<T extends string> {
  value?: T;
  label: string;
  disabled?: boolean;
  divider?: boolean;
  destructive?: boolean;
}

function PopupMenu<T extends string>({
  items,
  onSelect,
  className,
  style,
  variant = "material",
}: {
  items: MenuItem<T>[];
  onSelect: (value: T) => void;
  className?: string;
  style?: CSSProperties;
  variant?: MenuVariant;
}) {
  return (
    <div
      role="menu"
      className={cx(
        "h-popup-menu",
        variant !== "material" && `h-popup-menu--${variant}`,
        className,
      )}
      style={style}
      onMouseDown={(e) => e.stopPropagation()}
    >
      {items.map((item, i) =>
        item.divider ? (
          <div key={`d${i}`} className="h-popup-menu__divider" />
        ) : (
          <button
            key={item.label}
            type="button"
            role="menuitem"
            disabled={item.disabled}
            className={[
              "h-popup-menu__item",
              item.disabled ? "h-popup-menu__item--info" : null,
              item.destructive ? "h-popup-menu__item--destructive" : null,
            ]
              .filter(Boolean)
              .join(" ")}
            onClick={() => item.value && onSelect(item.value)}
          >
            {item.label}
          </button>
        ),
      )}
    </div>
  );
}

function useDismiss(open: boolean, close: () => void) {
  useEffect(() => {
    if (!open) return;
    const onDown = () => close();
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && close();
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open, close]);
}

function threadMenuItems(
  pinned: boolean,
  actionable: boolean,
  includeCopyTranscript: boolean,
): MenuItem<ThreadAction>[] {
  return [
    ...(includeCopyTranscript
      ? [
          { value: "copy-transcript" as const, label: "Copy transcript" },
          ...(actionable ? [{ label: "-", divider: true }] : []),
        ]
      : []),
    ...(actionable
      ? [
          { value: "rename" as const, label: "Rename" },
          { value: "pin" as const, label: pinned ? "Unpin" : "Pin" },
          { value: "archive" as const, label: "Archive" },
          {
            value: "delete" as const,
            label: "Delete",
            destructive: true,
          },
        ]
      : []),
  ];
}

export interface ThreadActionsButtonProps {
  /** Whether the chat is pinned; the menu then offers "Unpin". */
  pinned?: boolean;
  /** The dashboard holds the chat: offer Rename, Pin, Archive and Delete. */
  actionable?: boolean;
  /** Add "Copy transcript" on top, as the chat header does. */
  includeCopyTranscript?: boolean;
  /** Open the menu initially, for previews. */
  defaultOpen?: boolean;
  /** Called with the picked entry; the menu closes. */
  onAction?: (action: ThreadAction) => void;
  /** `apple` draws the menu as an iOS pull-down (`layout="phone"`: rounded panel, 44px rows, Delete in red) or a compact Mac menu (`desktop`: 24px rows, 13px text, 6px radius). Inherits the provider's platform. */
  platform?: Platform;
  /** Which Apple menu `platform="apple"` draws; see `platform`. Default `desktop`. */
  layout?: DeviceLayout;
}

/**
 * The 40px "…" button that opens a chat's actions menu (Copy transcript,
 * Rename, Pin, Archive, Delete), right-aligned under the button. The chat
 * header uses it; the sidebar rows have their own dense 28px version.
 */
export function ThreadActionsButton({
  pinned = false,
  actionable = true,
  includeCopyTranscript = false,
  defaultOpen = false,
  onAction,
  platform,
  layout = "desktop",
}: ThreadActionsButtonProps) {
  const resolvedPlatform = usePlatform(platform);
  const variant = menuVariant(resolvedPlatform === "apple", layout);
  const [open, setOpen] = useState(defaultOpen);
  const close = useRef(() => setOpen(false)).current;
  useDismiss(open, close);
  return (
    <PlatformScope platform={resolvedPlatform}>
      <span
        className="h-thread-actions"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <IconButton
          icon="more_horiz"
          label="Chat actions"
          tone="muted"
          onClick={() => setOpen((o) => !o)}
        />
        {open ? (
          <PopupMenu
            variant={variant}
            className="h-thread-actions__menu"
            items={threadMenuItems(pinned, actionable, includeCopyTranscript)}
            onSelect={(a) => {
              setOpen(false);
              onAction?.(a);
            }}
          />
        ) : null}
      </span>
    </PlatformScope>
  );
}

export interface SidebarActionProps {
  /** Material Symbols icon name, 18px. */
  icon: string;
  /** Row label, 13px. */
  label: string;
  /** Fill the row and bold the label, as for the open destination. */
  selected?: boolean;
  /** Draw the icon filled (the open destination uses the filled glyph). */
  filledIcon?: boolean;
  /** Called when the row is clicked. */
  onClick?: () => void;
}

/** A flat, full-width sidebar row for an action or destination ("New chat", "Kanban", "More"). */
export function SidebarAction({
  icon,
  label,
  selected = false,
  filledIcon = false,
  onClick,
}: SidebarActionProps) {
  return (
    <button
      type="button"
      className={[
        "h-sidebar-action",
        rowRadiusClass,
        selected ? "h-sidebar-action--selected" : null,
      ]
        .filter(Boolean)
        .join(" ")}
      aria-current={selected ? "page" : undefined}
      onClick={onClick}
    >
      <Icon name={icon} size={18} filled={filledIcon} />
      <span className="h-sidebar-action__label">{label}</span>
    </button>
  );
}

export interface SidebarBrandProps {
  /** The Mac sidebar: no brand row, a 52px strip that leaves 78px for the traffic lights and ends in a hide-sidebar button (when inside an `AppShell`). */
  mac?: boolean;
}

/** The sidebar's top line: the Hermes hub mark and the app name. On the Mac sidebar (`mac`) it is the empty strip beside the traffic lights instead. */
export function SidebarBrand({ mac = false }: SidebarBrandProps) {
  const { toggleSidebar } = useContext(ShellChromeContext);
  if (mac)
    return (
      <div className="h-sidebar-brand h-sidebar-brand--mac">
        <span className="h-sidebar-brand__spacer" />
        {toggleSidebar ? (
          <IconButton
            icon="left_panel_close"
            label="Hide sidebar"
            tone="muted"
            onClick={toggleSidebar}
          />
        ) : null}
      </div>
    );
  return (
    <div className="h-sidebar-brand">
      <Icon name="hub" size={18} />
      <span className="h-sidebar-brand__name">Hermes</span>
    </div>
  );
}

export interface AccountFooterProps {
  /** Display name or email of the signed-in user; the server URL, or "Not connected", without one. */
  label?: string;
  /** The server address, shown greyed out at the top of the menu. */
  serverUrl?: string;
  /** The server requires sign-in, so the menu offers "Sign out". */
  authRequired?: boolean;
  /** Open the account menu initially, for previews. */
  defaultMenuOpen?: boolean;
  /** Called with the picked menu entry. */
  onAction?: (action: AccountAction) => void;
  /** Apple menu style for the account menu; see `ThreadActionsButton`. Inherits the provider's platform. */
  platform?: Platform;
  /** Which Apple menu `platform="apple"` draws. Default `desktop`. */
  layout?: DeviceLayout;
}

/** The sidebar footer: an avatar, the account label and a "…" that opens the account menu over it. */
export function AccountFooter({
  label = "Not connected",
  serverUrl = "",
  authRequired = false,
  defaultMenuOpen = false,
  onAction,
  platform,
  layout = "desktop",
}: AccountFooterProps) {
  const resolvedPlatform = usePlatform(platform);
  const variant = menuVariant(resolvedPlatform === "apple", layout);
  const [open, setOpen] = useState(defaultMenuOpen);
  const close = useRef(() => setOpen(false)).current;
  useDismiss(open, close);
  const items: MenuItem<AccountAction>[] = [
    { label: serverUrl || " ", disabled: true },
    { label: "-", divider: true },
    { value: "appearance", label: "Appearance" },
    { value: "notifications", label: "Notifications" },
    { value: "app-lock", label: "App lock" },
    { value: "about", label: "About" },
    ...(authRequired
      ? [{ value: "sign-out" as const, label: "Sign out" }]
      : []),
    { value: "change-server", label: "Change server" },
  ];
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div
        className="h-account-footer"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <button
          type="button"
          className={`h-account-footer__button ${rowRadiusClass}`}
          title="Account"
          onClick={() => setOpen((o) => !o)}
        >
          <span className="h-account-footer__avatar">
            <Icon name="person" size={15} />
          </span>
          <span className="h-account-footer__label">{label}</span>
          <Icon
            name="more_horiz"
            size={16}
            className="h-account-footer__more"
          />
        </button>
        {open ? (
          <PopupMenu
            variant={variant}
            className="h-account-footer__menu"
            items={items}
            onSelect={(a) => {
              setOpen(false);
              onAction?.(a);
            }}
          />
        ) : null}
      </div>
    </PlatformScope>
  );
}

export interface ThreadSidebarProps {
  /** The chats, newest first (pinned ones first, as the server orders them). */
  threads: ThreadItem[];
  /** The open chat, drawn as a filled row with a bold title. */
  selectedId?: string | null;
  /**
   * The app shell's destinations, shown under the app name and divided from
   * "New chat", in the wide sidebar and the phone drawer (pass a
   * `ShellNavigation`). Leave it out when the shell has only Chat.
   */
  navigation?: ReactNode;
  /** Entries behind the collapsible "More" row. Defaults to Profiles, Skills, Bots, Plugins, MCP servers, Helper models; an empty list hides the section. */
  moreEntries?: SidebarMoreEntry[];
  /** Show the "More" section expanded initially. */
  defaultMoreOpen?: boolean;
  /** Open this chat's "…" menu initially, for previews. */
  defaultMenuThreadId?: string;
  /** The server has more chats: end the list with a "Show more" row. */
  hasMore?: boolean;
  /** The next page is loading: the "Show more" row shows a spinner. */
  loadingMore?: boolean;
  /** Account label for the footer; see `AccountFooter`. */
  account?: string;
  /** Server address shown at the top of the account menu. */
  serverUrl?: string;
  /** The server requires sign-in, so the account menu offers "Sign out". */
  authRequired?: boolean;
  /** Open the account menu initially, for previews. */
  defaultAccountMenuOpen?: boolean;
  /** A chat row was clicked. */
  onSelect?: (id: string) => void;
  /** "New chat" was clicked. */
  onNewThread?: () => void;
  /** An entry of a chat's "…" menu was picked. */
  onThreadAction?: (id: string, action: ThreadAction) => void;
  /** "Show more" was clicked. */
  onLoadMore?: () => void;
  /** An account menu entry was picked. */
  onAccountAction?: (action: AccountAction) => void;
  /**
   * `apple` changes the sidebar to Apple's conventions, and what changes
   * depends on `layout`. Touch (`phone`, iPhone and iPad): thread rows are at
   * least 44px tall and the "…" button is a 44px target that opens the iOS
   * pull-down with Rename, Pin, Archive and Delete (right-click opens it too).
   * The app's swipe actions and long-press sheet are not recreated, so the
   * button stays as the way to reach them. Mac (`desktop`): the sidebar starts at the top
   * of the window, drops the brand row for a 52px strip that leaves 78px for
   * the traffic lights, keeps the "…" button and uses the compact Mac menu.
   * Inherits the provider's platform.
   */
  platform?: Platform;
  /** Touch (`phone`) or pointer (`desktop`, default) rows and menus under `platform="apple"`. Has no effect on `material`. */
  layout?: DeviceLayout;
}

/**
 * The chat sidebar (280px wide in the app, phone drawer included): the Hermes
 * name, optional shell destinations, "New chat", the scrolling thread list with
 * the open chat filled, the "More" section and the account footer. It fills its
 * parent's height; give it a width.
 */
export function ThreadSidebar({
  threads,
  selectedId = null,
  navigation,
  moreEntries = DEFAULT_MORE_ENTRIES,
  defaultMoreOpen = false,
  defaultMenuThreadId,
  hasMore = false,
  loadingMore = false,
  account,
  serverUrl,
  authRequired,
  defaultAccountMenuOpen,
  onSelect,
  onNewThread,
  onThreadAction,
  onLoadMore,
  onAccountAction,
  platform,
  layout = "desktop",
}: ThreadSidebarProps) {
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const touch = apple && layout === "phone";
  const mac = apple && layout === "desktop";
  const variant = menuVariant(apple, layout);
  const [moreOpen, setMoreOpen] = useState(defaultMoreOpen);
  const [menuId, setMenuId] = useState<string | undefined>(defaultMenuThreadId);
  const [menuTop, setMenuTop] = useState<number | null>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const rowRefs = useRef(new Map<string, HTMLDivElement>());
  const close = useRef(() => setMenuId(undefined)).current;
  useDismiss(menuId !== undefined, close);

  useLayoutEffect(() => {
    const list = listRef.current;
    const row = menuId ? rowRefs.current.get(menuId) : undefined;
    if (!list || !row) {
      setMenuTop(null);
      return;
    }
    setMenuTop(
      list.offsetTop + row.offsetTop - list.scrollTop + row.offsetHeight + 2,
    );
  }, [menuId, threads]);

  const menuThread = threads.find((t) => t.id === menuId);

  return (
    <PlatformScope platform={resolvedPlatform}>
      <nav
        className={cx(
          "h-thread-sidebar",
          touch && "h-thread-sidebar--touch",
          mac && "h-thread-sidebar--mac",
        )}
        aria-label="Chats"
      >
        <SidebarBrand mac={mac} />
        {navigation ? (
          <>
            <div className="h-thread-sidebar__pad">{navigation}</div>
            <hr className="h-thread-sidebar__nav-divider" />
          </>
        ) : null}
        <div className="h-thread-sidebar__pad">
          <SidebarAction icon="add" label="New chat" onClick={onNewThread} />
        </div>
        <div
          ref={listRef}
          className="h-thread-sidebar__list"
          onScroll={() => menuId && setMenuId(undefined)}
        >
          {threads.map((t) => {
            const selected = t.id === selectedId;
            const actionable = t.remote !== false;
            return (
              <div
                key={t.id}
                ref={(el) => {
                  if (el) rowRefs.current.set(t.id, el);
                  else rowRefs.current.delete(t.id);
                }}
                className={[
                  "h-thread-row",
                  rowRadiusClass,
                  selected ? "h-thread-row--selected" : null,
                  actionable ? "h-thread-row--actionable" : null,
                ]
                  .filter(Boolean)
                  .join(" ")}
                role="button"
                tabIndex={0}
                aria-current={selected ? "true" : undefined}
                onClick={() => onSelect?.(t.id)}
                onContextMenu={
                  actionable
                    ? (e) => {
                        e.preventDefault();
                        setMenuId(t.id);
                      }
                    : undefined
                }
              >
                {t.pinned ? (
                  <Icon
                    name="push_pin"
                    filled
                    size={12}
                    className="h-thread-row__pin"
                  />
                ) : null}
                <span className="h-thread-row__title">{t.title}</span>
                {actionable ? (
                  <button
                    type="button"
                    className="h-thread-row__more"
                    aria-label="Chat actions"
                    title="Chat actions"
                    onMouseDown={(e) => e.stopPropagation()}
                    onClick={(e) => {
                      e.stopPropagation();
                      setMenuId((id) => (id === t.id ? undefined : t.id));
                    }}
                  >
                    <Icon name="more_horiz" size={16} />
                  </button>
                ) : null}
              </div>
            );
          })}
          {hasMore ? (
            <div className="h-thread-sidebar__show-more">
              {loadingMore ? (
                <span
                  className={cx(
                    "h-thread-sidebar__spinner",
                    apple && "h-apple-spinner",
                  )}
                  aria-label="Loading"
                />
              ) : (
                <button
                  type="button"
                  className="h-thread-sidebar__show-more-button"
                  onClick={onLoadMore}
                >
                  Show more
                </button>
              )}
            </div>
          ) : null}
        </div>
        {menuThread && menuTop !== null ? (
          <PopupMenu
            variant={variant}
            className={cx(
              "h-thread-sidebar__menu",
              touch && "h-thread-sidebar__menu--touch",
            )}
            style={{ top: menuTop }}
            items={threadMenuItems(!!menuThread.pinned, true, false)}
            onSelect={(a) => {
              setMenuId(undefined);
              onThreadAction?.(menuThread.id, a);
            }}
          />
        ) : null}
        <div className="h-thread-sidebar__divider" />
        {moreEntries.length ? (
          <div className="h-thread-sidebar__pad">
            <div className="h-thread-sidebar__divider" />
            <SidebarAction
              icon={moreOpen ? "expand_more" : "chevron_right"}
              label="More"
              onClick={() => setMoreOpen((o) => !o)}
            />
            {moreOpen
              ? moreEntries.map((e) => (
                  <SidebarAction
                    key={e.label}
                    icon={e.icon}
                    label={e.label}
                    onClick={e.onClick}
                  />
                ))
              : null}
          </div>
        ) : null}
        <AccountFooter
          label={account}
          serverUrl={serverUrl}
          authRequired={authRequired}
          defaultMenuOpen={defaultAccountMenuOpen}
          onAction={onAccountAction}
          platform={apple ? "apple" : "material"}
          layout={layout}
        />
      </nav>
    </PlatformScope>
  );
}
