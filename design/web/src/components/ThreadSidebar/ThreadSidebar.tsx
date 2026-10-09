import {
  useContext,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { ActionSheet } from "../ActionSheet/ActionSheet";
import {
  Menu,
  MenuAnchor,
  useDismiss,
  useMenuState,
  type MenuItem,
} from "../Menu/Menu";
import { SwipeActions } from "../SwipeActions/SwipeActions";
import { Icon } from "../Icon/Icon";
import { Spinner } from "../Spinner/Spinner";
import { IconButton } from "../IconButton/IconButton";
import {
  ShellChromeContext,
  cx,
  PlatformScope,
  useAppleDevice,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import {
  MacRowButton,
  MacSourceListRow,
  SectionedThreadList,
  ThreadListHeading,
  type ThreadGrouping,
} from "./MacSourceList";
import { MacAccountFooter } from "./MacAccount";
import {
  MacSearchResults,
  ThreadSearchField,
  ThreadSearchResults,
  type ThreadSearchHit,
  type ThreadSidebarSearch,
} from "./SidebarSearch";
import "./ThreadSidebar.css";

export type { ThreadGrouping, ThreadSection } from "./MacSourceList";
export type { ThreadSearchHit, ThreadSidebarSearch } from "./SidebarSearch";
export type { MacProfileScope, SwitcherProfile } from "./MacAccount";
export type { SettingsEntry } from "../SettingsDialog/SettingsDialog";

/**
 * Which device a component is laid out for. `phone` is touch (iPhone, iPad
 * in Split View): 44px bars and rows, iOS menus. `desktop` is pointer (Mac,
 * and every Material platform): compact rows, Mac menus; a full-screen iPad
 * also uses `desktop`, with `device="touch"` where a component offers it.
 * Only matters under `apple`.
 */
export type DeviceLayout = "desktop" | "phone";

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
  /**
   * When the chat was last active, as an ISO date ("2026-10-04T09:30:00Z").
   * Only the Mac sidebar reads it, to sort the chat into a recency section
   * (see `ThreadSection`); without it the chat counts as today's.
   */
  updatedAt?: string;
  /**
   * The folder the chat ran in (the session's git repository root, else its
   * working directory): "/home/ada/code/hermes-app". With `grouping="folder"`
   * the chat sits under the folder's last segment ("hermes-app"), or the
   * whole path where two folders share one; without it under "No folder".
   */
  folderPath?: string;
}

/** What a chat's "…" menu asks for. `pin` toggles: it reads "Unpin" on a pinned chat. */
export type ThreadAction =
  | "open-in-new-window"
  | "copy-transcript"
  | "rename"
  | "pin"
  | "archive"
  | "delete";

/** An entry of the sidebar's collapsible "More" section. */
export interface SidebarMoreEntry {
  /** Material Symbols icon name. */
  icon: string;
  /** Row label, e.g. "MCP servers". */
  label: string;
  /** Called when the row is clicked. */
  onClick?: () => void;
}

/**
 * What the account menu in the sidebar footer asks for. Touch and Material:
 * Appearance, Notifications, App lock, About, Sign out, Change server. Mac:
 * `settings` (Settings…, which opens the Settings list), `connection`
 * (Connection Details) and `sign-out`.
 */
export type AccountAction =
  | "appearance"
  | "notifications"
  | "app-lock"
  | "about"
  | "sign-out"
  | "change-server"
  | "settings"
  | "connection";

/** The six entries the app puts behind "More", in its order (Bots became Messaging in #429). Not on a Mac, whose profile pages are reached from the Profiles page. */
export const DEFAULT_MORE_ENTRIES: SidebarMoreEntry[] = [
  { icon: "person", label: "Profiles" },
  { icon: "extension", label: "Skills" },
  { icon: "smart_toy", label: "Messaging" },
  { icon: "extension", label: "Plugins" },
  { icon: "power", label: "MCP servers" },
  { icon: "tune", label: "Helper models" },
];

const rowRadiusClass = "h-sidebar-row";

type ThreadMenuItems = Array<MenuItem<ThreadAction> | "divider">;

function threadMenuItems(
  pinned: boolean,
  actionable: boolean,
  includeCopyTranscript: boolean,
  mac: boolean,
  canOpenInNewWindow = false,
): ThreadMenuItems {
  if (mac) return macThreadMenuItems(pinned, actionable, canOpenInNewWindow);
  return [
    ...(includeCopyTranscript
      ? [
          { value: "copy-transcript" as const, label: "Copy transcript" },
          ...(actionable ? ["divider" as const] : []),
        ]
      : []),
    ...(actionable ? threadActions(pinned) : []),
  ];
}

/**
 * A chat's menu as a Mac app lists it (the app's `macThreadMenuItems`), with
 * the shortcuts the menu bar gives them, in the sidebar and the chat header
 * alike. A chat the dashboard does not hold only offers the copy; one it
 * holds leads with "Open in New Window" when the window can open one.
 */
export function macThreadMenuItems(
  pinned: boolean,
  actionable: boolean,
  canOpenInNewWindow: boolean,
): ThreadMenuItems {
  const copy = { value: "copy-transcript" as const, label: "Copy Transcript" };
  if (!actionable) return [copy];
  return [
    ...(canOpenInNewWindow
      ? [
          {
            value: "open-in-new-window" as const,
            label: "Open in New Window",
            shortcut: "⌥⌘O",
          },
          "divider" as const,
        ]
      : []),
    { value: "rename", label: "Rename…" },
    { value: "pin", label: pinned ? "Unpin" : "Pin", shortcut: "⇧⌘P" },
    copy,
    { value: "archive", label: "Archive" },
    "divider",
    {
      value: "delete",
      label: "Delete…",
      shortcut: "⌘⌫",
      destructive: true,
    },
  ];
}

/** Rename, Pin or Unpin, Archive, Delete: the menu's, the action sheet's and the swipes' actions. */
function threadActions(pinned: boolean) {
  return [
    { value: "rename" as const, label: "Rename" },
    { value: "pin" as const, label: pinned ? "Unpin" : "Pin" },
    { value: "archive" as const, label: "Archive" },
    { value: "delete" as const, label: "Delete", destructive: true },
  ];
}

export interface ThreadActionsButtonProps {
  /** Whether the chat is pinned; the menu then offers "Unpin". */
  pinned?: boolean;
  /** The dashboard holds the chat: offer Rename, Pin, Archive and Delete. */
  actionable?: boolean;
  /** Add "Copy transcript" on top, as the chat header does. */
  includeCopyTranscript?: boolean;
  /** Mac only: lead the menu with "Open in New Window" (⌥⌘O). */
  canOpenInNewWindow?: boolean;
  /** Open the menu initially, for previews. */
  defaultOpen?: boolean;
  /** Called with the picked entry; the menu closes. */
  onAction?: (action: ThreadAction) => void;
  /** `apple` draws the menu as an iOS pull-down on touch (rounded panel, 44px rows, Delete in red) or the Mac menu (22px rows with shortcuts: Rename…, Pin, Copy Transcript, Archive, Delete…). Inherits the provider's platform. */
  platform?: Platform;
  /** `phone` is touch; `desktop` (default) follows the enclosing `AppShell`'s device, else Mac. Only matters under `apple`. */
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
  canOpenInNewWindow = false,
  defaultOpen = false,
  onAction,
  platform,
  layout = "desktop",
}: ThreadActionsButtonProps) {
  const resolvedPlatform = usePlatform(platform);
  const device = useAppleDevice(layout);
  const mac = resolvedPlatform === "apple" && device === "mac";
  const [open, setOpen] = useMenuState(defaultOpen);
  return (
    <PlatformScope platform={resolvedPlatform}>
      <MenuAnchor className="h-thread-actions">
        <IconButton
          icon="more_horiz"
          label="Chat actions"
          tone="muted"
          onMouseDown={(e) => e.stopPropagation()}
          onClick={() => setOpen((o) => !o)}
        />
        {open ? (
          <Menu
            align="end"
            label="Chat actions"
            device={device}
            items={threadMenuItems(
              pinned,
              actionable,
              includeCopyTranscript,
              mac,
              canOpenInNewWindow,
            )}
            onSelect={(item) => {
              setOpen(false);
              if (item.value) onAction?.(item.value);
            }}
          />
        ) : null}
      </MenuAnchor>
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
  /** Display name or email of the signed-in user; the server URL, or "Not connected", without one. On a Mac the name over the server's host, or the host alone. */
  label?: string;
  /** The server address, shown greyed out at the top of the menu (touch, Material) or as its host under the name (Mac). */
  serverUrl?: string;
  /** The server requires sign-in, so the menu offers "Sign out" ("Sign Out" on a Mac, whose menu then reads "Signed in to the dashboard"). */
  authRequired?: boolean;
  /** Open the account menu initially, for previews. */
  defaultMenuOpen?: boolean;
  /** Called with the picked menu entry. */
  onAction?: (action: AccountAction) => void;
  /** Apple menu style for the account menu; see `ThreadActionsButton`. Inherits the provider's platform. */
  platform?: Platform;
  /** `phone` is touch; `desktop` (default) follows `device`, then the enclosing `AppShell`'s, else Mac. */
  layout?: DeviceLayout;
  /** Under `apple`, which menu to draw; overrides `layout`. */
  device?: AppleDevice;
}

/** The host of `url` ("hermes.example.net"), or `url` itself when it does not parse. */
function hostOf(url: string) {
  try {
    return new URL(url).host || url;
  } catch {
    return url;
  }
}

/**
 * The sidebar footer: an avatar, the account label and a "…" that opens the
 * account menu over it. On a Mac (#402) it sits over a hairline: initials,
 * the name in bold over the server's host and an up-down chevron, and its
 * menu opens above it with "Signed in to the dashboard", Settings… ⌘,,
 * Connection Details and Sign Out.
 */
export function AccountFooter(props: AccountFooterProps) {
  const resolvedPlatform = usePlatform(props.platform);
  const menuDevice = useAppleDevice(props.layout ?? "desktop", props.device);
  if (resolvedPlatform === "apple" && menuDevice === "mac")
    return (
      <PlatformScope platform="apple">
        <MacAccountFooter
          name={props.label}
          host={props.serverUrl ? hostOf(props.serverUrl) : "Not connected"}
          canSignOut={!!props.authRequired}
          defaultMenuOpen={props.defaultMenuOpen}
          onAction={props.onAction}
        />
      </PlatformScope>
    );
  return (
    <TouchAccountFooter
      {...props}
      label={props.label || props.serverUrl || "Not connected"}
      platform={resolvedPlatform}
      device={menuDevice}
    />
  );
}

function TouchAccountFooter({
  label,
  serverUrl = "",
  authRequired = false,
  defaultMenuOpen = false,
  onAction,
  platform,
  device: menuDevice,
}: AccountFooterProps & { platform: Platform; device: AppleDevice }) {
  const [open, setOpen] = useMenuState(defaultMenuOpen);
  const items: Array<MenuItem<AccountAction> | "divider"> = [
    { label: serverUrl || " ", info: true },
    "divider",
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
    <PlatformScope platform={platform}>
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
          <Menu
            className="h-account-footer__menu"
            label="Account"
            device={menuDevice}
            items={items}
            onSelect={(item) => {
              setOpen(false);
              if (item.value) onAction?.(item.value);
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
   * `ShellNavigation`, which on a Mac also carries the profile switcher).
   * Leave it out when the shell has only Chat.
   */
  navigation?: ReactNode;
  /** Entries behind the collapsible "More" row (touch and Material). Defaults to Profiles, Skills, Messaging, Plugins, MCP servers, Helper models; an empty list hides the section. A Mac sidebar has no "More": its Profiles page reaches those screens. */
  moreEntries?: SidebarMoreEntry[];
  /** Show the "More" section expanded initially. */
  defaultMoreOpen?: boolean;
  /** Open this chat's "…" menu initially, for previews. Not on Apple touch, which has no "…" button. */
  defaultMenuThreadId?: string;
  /** Apple touch: draw this chat's row swiped open, for previews; see `swipeSide`. */
  swipedThreadId?: string;
  /** Which way `swipedThreadId` is swiped: `trailing` (default) shows Delete in red, `leading` shows Pin or Unpin in orange. */
  swipeSide?: "leading" | "trailing";
  /** Apple touch: draw the long-press action sheet of this chat over the sidebar, for previews. */
  actionSheetThreadId?: string;
  /**
   * How the chats are grouped (#434), picked from the "…" on the first
   * header (or beside "Chats"): `recent` (default) or `folder`. By recency a
   * Mac and an iPhone or iPad list the chats under Pinned, Today, Previous 7
   * days, Previous 30 days and Older (from `updatedAt`), while Material lists
   * them flat under a "Chats" heading. By folder every platform lists Pinned,
   * then each folder (from `folderPath`) with its count, then "No folder".
   */
  grouping?: ThreadGrouping;
  /** Open the grouping menu ("Group by": Recent, Folder) initially, for previews. */
  defaultGroupingMenuOpen?: boolean;
  /** The day the recency sections count back from (and search hits' "2h ago"), as an ISO date; defaults to today. Pin it in previews so the sections stay put. */
  now?: string;
  /** Sections folded away initially (their header stays, with the chevron turned): a recency section (`pinned`, `today`, `previous-7-days`, `previous-30-days`, `older`), `folder:<folderPath>` or `no-folder`. */
  defaultFoldedSections?: string[];
  /** Mac: draw this chat's row as if under the pointer (hover fill, Archive and More buttons), for previews. */
  hoveredThreadId?: string;
  /** Mac: chats the dashboard holds lead their menu with "Open in New Window" (⌥⌘O). */
  canOpenInNewWindow?: boolean;
  /**
   * A chat search, as preview state. On a Mac (#399) the search lives in
   * the toolbar (`ChatHeader`), and while one is open the sidebar shows its
   * results instead of the destinations and chats: the "This profile | All
   * profiles" switch, "Recent searches" while the query is empty, else the
   * hits under "Chats" (title matches) and "Messages" with counts and the
   * term in bold, a hit from another profile prefixed with its name, or
   * "No results for “q”". On touch and Material a "Search chats" field sits
   * under "New chat" and, holding text, its hits replace the chats.
   */
  search?: ThreadSidebarSearch;
  /** Mac: the profile the sidebar lists, so hits from other profiles name theirs. */
  searchProfile?: string;
  /** The server has more chats: end the list with a "Show more" row. */
  hasMore?: boolean;
  /** The next page is loading: the "Show more" row shows a spinner. */
  loadingMore?: boolean;
  /** Account label for the footer; see `AccountFooter`. */
  account?: string;
  /** Server address shown at the top of the account menu (its host under the name on a Mac). */
  serverUrl?: string;
  /** The server requires sign-in, so the account menu offers "Sign out". */
  authRequired?: boolean;
  /** Open the account menu initially, for previews. */
  defaultAccountMenuOpen?: boolean;
  /** A chat row was clicked. In a compact Mac window this also closes the sidebar lying over the page. */
  onSelect?: (id: string) => void;
  /** "New chat" was clicked (not on a Mac, whose New Chat is in the toolbar). */
  onNewThread?: () => void;
  /** An entry of a chat's "…" menu was picked. */
  onThreadAction?: (id: string, action: ThreadAction) => void;
  /** "Show more" was clicked. */
  onLoadMore?: () => void;
  /** An account menu entry was picked. */
  onAccountAction?: (action: AccountAction) => void;
  /** Recent or Folder was picked from the grouping menu. */
  onGroupingChange?: (grouping: ThreadGrouping) => void;
  /** Touch and Material: the search field changed (empty when cleared). */
  onSearchChange?: (query: string) => void;
  /** A search hit was clicked. */
  onOpenSearchHit?: (hit: ThreadSearchHit) => void;
  /** Mac: a recent search was clicked. */
  onPickRecentSearch?: (query: string) => void;
  /** Mac: the scope switch was flipped. */
  onSearchScopeChange?: (scope: "profile" | "all-profiles") => void;
  /**
   * `apple` changes the sidebar to Apple's conventions, and what changes
   * depends on the device (see `layout` and `device`). Touch (iPhone and
   * iPad): thread rows are at least 44px tall and have no "…" button, as in
   * the app: a swipe from the trailing edge reveals Delete, one from the
   * leading edge Pin (or Unpin), and a long press opens an action sheet with
   * Rename, Pin, Archive and Delete (see `swipedThreadId`,
   * `actionSheetThreadId`). Mac: the sidebar starts at the top of the window
   * and drops the brand row for a 52px strip that leaves 78px for the
   * traffic lights; it is a source list: the chats sit under small bold
   * section headers that fold away on a click, as 28px rows without a pin
   * glyph whose Archive and More buttons show under the pointer
   * (`hoveredThreadId`), and More or a right-click opens the compact Mac
   * menu (`canOpenInNewWindow` adds "Open in New Window"). New chat and
   * search move to the toolbar (`ChatHeader`), the "More" section goes
   * (the Profiles page holds those screens), the footer becomes the Mac
   * account footer, and destinations passed in `navigation` become
   * source-list rows too. Inherits the provider's platform.
   */
  platform?: Platform;
  /** `phone` draws touch rows and menus under `platform="apple"`; `desktop` (default) draws the Mac sidebar unless `device` or the enclosing `AppShell` says touch. Has no effect on `material`. */
  layout?: DeviceLayout;
  /** Under `apple`, `touch` (iPad sidebar beside the page) or `mac`; see `AppleDevice`. Inherited from the enclosing `AppShell` when omitted. */
  device?: AppleDevice;
}

/**
 * The chat sidebar (280px wide in the app, phone drawer included): the Hermes
 * name, optional shell destinations, "New chat", the search field, the
 * scrolling thread list with the open chat filled, the "More" section and
 * the account footer. On a Mac: the strip under the traffic lights, the
 * profile switcher and destinations, the source list (or a search's
 * results) and the Mac account footer. It fills its parent's height; give
 * it a width.
 */
export function ThreadSidebar({
  threads,
  selectedId = null,
  navigation,
  moreEntries = DEFAULT_MORE_ENTRIES,
  defaultMoreOpen = false,
  defaultMenuThreadId,
  swipedThreadId,
  swipeSide = "trailing",
  actionSheetThreadId,
  grouping = "recent",
  defaultGroupingMenuOpen,
  now,
  defaultFoldedSections,
  hoveredThreadId,
  canOpenInNewWindow = false,
  search,
  searchProfile,
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
  onGroupingChange,
  onSearchChange,
  onOpenSearchHit,
  onPickRecentSearch,
  onSearchScopeChange,
  platform,
  layout = "desktop",
  device: deviceProp,
}: ThreadSidebarProps) {
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const device = useAppleDevice(layout, deviceProp);
  const touch = apple && device === "touch";
  const mac = apple && device === "mac";
  const [moreOpen, setMoreOpen] = useState(defaultMoreOpen);
  const [menuId, setMenuId] = useState<string | undefined>(defaultMenuThreadId);
  const [menuTop, setMenuTop] = useState<number | null>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const rowRefs = useRef(new Map<string, HTMLDivElement>());
  const close = useRef(() => setMenuId(undefined)).current;
  useDismiss(menuId !== undefined, close);
  const trackRow = (id: string) => (el: HTMLDivElement | null) => {
    if (el) rowRefs.current.set(id, el);
    else rowRefs.current.delete(id);
  };
  const shell = useContext(ShellChromeContext);
  const navigationChrome = useMemo(
    () => ({ ...shell, device }),
    [shell, device],
  );
  const today = useMemo(() => (now ? new Date(now) : new Date()), [now]);
  const select = (id: string) => {
    shell.closeOverlay?.();
    onSelect?.(id);
  };
  const openHit = (hit: ThreadSearchHit) => {
    shell.closeOverlay?.();
    onOpenSearchHit?.(hit);
  };

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
  const sheetThread = touch
    ? threads.find((t) => t.id === actionSheetThreadId && t.remote !== false)
    : undefined;

  const macRow = (t: ThreadItem) => (
    <MacSourceListRow
      key={t.id}
      label={t.title}
      selected={t.id === selectedId}
      hovered={t.id === hoveredThreadId}
      rowRef={trackRow(t.id)}
      onClick={() => select(t.id)}
      onContextMenu={(e) => {
        e.preventDefault();
        setMenuId(t.id);
      }}
      actions={
        <>
          {t.remote !== false ? (
            <MacRowButton
              icon="archive"
              label="Archive"
              title="Archive"
              onPress={() => onThreadAction?.(t.id, "archive")}
            />
          ) : null}
          <MacRowButton
            icon="more_horiz"
            label={`More actions for ${t.title}`}
            title="More"
            onPress={() =>
              setMenuId((open) => (open === t.id ? undefined : t.id))
            }
          />
        </>
      }
    />
  );

  const touchRow = (t: ThreadItem) => {
    const selected = t.id === selectedId;
    const actionable = t.remote !== false;
    const inlineButton = actionable && !touch;
    const row = (
      <div
        key={t.id}
        ref={trackRow(t.id)}
        className={cx(
          "h-thread-row",
          rowRadiusClass,
          selected && "h-thread-row--selected",
          inlineButton && "h-thread-row--actionable",
        )}
        role="button"
        tabIndex={0}
        aria-current={selected ? "true" : undefined}
        onClick={() => select(t.id)}
        onContextMenu={
          inlineButton
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
        {inlineButton ? (
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
    if (!actionable || !touch) return row;
    const pin = t.pinned ? "Unpin" : "Pin";
    return (
      <SwipeActions
        key={t.id}
        className={rowRadiusClass}
        actions={[
          {
            label: "Delete",
            icon: "delete",
            onPress: () => onThreadAction?.(t.id, "delete"),
          },
        ]}
        leadingActions={[
          {
            label: pin,
            icon: "push_pin",
            filled: !t.pinned,
            color: "orange",
            onPress: () => onThreadAction?.(t.id, "pin"),
          },
        ]}
        revealed={t.id === swipedThreadId ? swipeSide : false}
        device="touch"
      >
        {row}
      </SwipeActions>
    );
  };

  const variant = mac ? "mac" : touch ? "touch" : "material";
  // Apple lists sections by recency too; Material only by folder (#434).
  const sectioned = apple || grouping === "folder";
  const threadList = sectioned ? (
    <SectionedThreadList
      threads={threads}
      grouping={grouping}
      variant={variant}
      now={today}
      defaultFolded={defaultFoldedSections}
      groupingMenuOpen={defaultGroupingMenuOpen}
      onGroupingChange={onGroupingChange}
      renderRow={mac ? macRow : touchRow}
    />
  ) : (
    <>
      <ThreadListHeading
        grouping={grouping}
        variant={variant}
        menuOpen={defaultGroupingMenuOpen}
        onGroupingChange={onGroupingChange}
      />
      {threads.map(touchRow)}
    </>
  );
  const showMore = hasMore ? (
    <div className="h-thread-sidebar__show-more">
      {loadingMore ? (
        <Spinner size={16} color="var(--h-fg)" />
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
  ) : null;
  const searching = !mac && !!search && search.query.trim() !== "";

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
        {mac && search ? (
          <MacSearchResults
            search={search}
            currentProfile={searchProfile}
            selectedId={selectedId}
            now={today}
            onOpen={openHit}
            onPickRecent={onPickRecentSearch}
            onScopeChange={onSearchScopeChange}
          />
        ) : (
          <>
            {navigation ? (
              <>
                <div
                  className={cx(
                    "h-thread-sidebar__pad",
                    mac && "h-thread-sidebar__nav--mac",
                  )}
                >
                  <ShellChromeContext.Provider value={navigationChrome}>
                    {navigation}
                  </ShellChromeContext.Provider>
                </div>
                {mac ? null : <hr className="h-thread-sidebar__nav-divider" />}
              </>
            ) : null}
            {/* A Mac window's New Chat and search are in the toolbar. */}
            {mac ? null : (
              <div className="h-thread-sidebar__pad">
                <SidebarAction
                  icon="add"
                  label="New chat"
                  onClick={onNewThread}
                />
              </div>
            )}
            {!mac && search ? (
              <div className="h-thread-sidebar__pad h-thread-sidebar__search">
                <ThreadSearchField
                  query={search.query}
                  onChange={onSearchChange}
                />
              </div>
            ) : null}
            <div
              ref={listRef}
              className={cx(
                "h-thread-sidebar__list",
                mac && "h-thread-sidebar__list--mac",
              )}
              onScroll={() => menuId && setMenuId(undefined)}
            >
              {searching ? (
                <ThreadSearchResults
                  search={search}
                  selectedId={selectedId}
                  now={today}
                  onOpen={openHit}
                />
              ) : (
                <>
                  {threadList}
                  {showMore}
                </>
              )}
            </div>
          </>
        )}
        {menuThread && menuTop !== null && !touch ? (
          <Menu
            className="h-thread-sidebar__menu"
            style={{ top: menuTop }}
            label="Chat actions"
            device="mac"
            items={threadMenuItems(
              !!menuThread.pinned,
              menuThread.remote !== false,
              false,
              mac,
              canOpenInNewWindow,
            )}
            onSelect={(item) => {
              setMenuId(undefined);
              if (item.value) onThreadAction?.(menuThread.id, item.value);
            }}
          />
        ) : null}
        {mac ? null : <div className="h-thread-sidebar__divider" />}
        {!mac && moreEntries.length ? (
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
          device={device}
        />
        {sheetThread ? (
          <ActionSheet
            title={sheetThread.title}
            actions={threadActions(!!sheetThread.pinned).map((a) => ({
              label: a.label,
              destructive: a.destructive,
              onPress: () => onThreadAction?.(sheetThread.id, a.value),
            }))}
          />
        ) : null}
      </nav>
    </PlatformScope>
  );
}
