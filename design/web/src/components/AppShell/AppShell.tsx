import {
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { MacSourceListRow } from "../ThreadSidebar/MacSourceList";
import {
  MacProfileSwitcher,
  SignOutAlert,
  type MacProfileScope,
} from "../ThreadSidebar/MacAccount";
import {
  SettingsDialog,
  type SettingsDialogProps,
  type SettingsEntry,
} from "../SettingsDialog/SettingsDialog";
import { IconButton } from "../IconButton/IconButton";
import {
  AccountFooter,
  SidebarAction,
  SidebarBrand,
  type AccountAction,
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
import "./AppShell.css";

/**
 * A top-level place in the app. Bots (the Bot Mode roster) only exists
 * while the dashboard's gateway is reachable, Kanban and Schedules only
 * while the server offers them, and Profiles only on a Mac (#402), where it
 * opens `MacProfilesPage` in the shell.
 */
export type ShellDestination =
  "chat" | "bots" | "kanban" | "schedules" | "profiles";

const destinationInfo: Record<
  ShellDestination,
  { icon: string; label: string; caption?: string }
> = {
  chat: { icon: "chat_bubble", label: "Chat" },
  bots: { icon: "smart_toy", label: "Bots" },
  // The board is shared by every profile, which the Mac row says.
  kanban: { icon: "view_kanban", label: "Kanban", caption: "All profiles" },
  schedules: { icon: "schedule", label: "Schedules" },
  profiles: { icon: "person", label: "Profiles" },
};

export interface ShellNavigationProps {
  /** The destinations to list, in order (Chat first). */
  destinations: ShellDestination[];
  /** The open destination: a filled row, bold label and filled icon. */
  current: ShellDestination;
  /** A destination row was clicked. In a compact Mac window this also closes the sidebar lying over the page. */
  onSelect?: (destination: ShellDestination) => void;
  /**
   * Mac only: the profile switcher card above the rows (#402): the profile
   * the sidebar works in, and a menu of every profile ("Profiles", each with
   * a check and its home path, "New Profile…", "Manage Profiles…").
   */
  profiles?: MacProfileScope;
  /** `apple` on a Mac draws source-list rows; see the component. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple`, `mac` (default) or `touch`; inherited from the enclosing `AppShell` or `ThreadSidebar`. */
  device?: AppleDevice;
}

/**
 * The shell's destinations as sidebar rows (Chat, Bots, Kanban, Schedules,
 * and Profiles on a Mac), in the wide sidebar and the phone drawer alike.
 * Pass it as `navigation` to `ThreadSidebar`, so it sits under the app name
 * above "New chat". On a Mac they are source-list rows: 28px, a 16px muted
 * outline icon, a 13px label, a soft fill on the open one, and Kanban
 * captioned "All profiles" at the trailing edge (the board is shared by
 * every profile); with `profiles` the profile switcher sits above them.
 */
export function ShellNavigation({
  destinations,
  current,
  onSelect,
  profiles,
  platform,
  device: deviceProp,
}: ShellNavigationProps) {
  const resolvedPlatform = usePlatform(platform);
  const device = useAppleDevice("desktop", deviceProp);
  const { closeOverlay } = useContext(ShellChromeContext);
  const mac = resolvedPlatform === "apple" && device === "mac";
  const select = (d: ShellDestination) => {
    closeOverlay?.();
    onSelect?.(d);
  };
  return (
    <div className="h-shell-navigation">
      {mac && profiles ? (
        <MacProfileSwitcher
          {...profiles}
          onManage={() => {
            closeOverlay?.();
            profiles.onManage?.();
          }}
        />
      ) : null}
      {destinations.map((d) => {
        const { icon, label, caption } = destinationInfo[d];
        const selected = d === current;
        return mac ? (
          <MacSourceListRow
            key={d}
            icon={icon}
            label={label}
            caption={caption}
            selected={selected}
            onClick={() => select(d)}
          />
        ) : (
          <SidebarAction
            key={d}
            icon={icon}
            filledIcon={selected}
            label={label}
            selected={selected}
            onClick={() => select(d)}
          />
        );
      })}
    </div>
  );
}

export interface ShellSidebarProps {
  /** The destinations rows, normally a `ShellNavigation`. */
  navigation: ReactNode;
  /** Account label for the footer ("Not connected" without one). */
  account?: string;
  /** The server address for the account footer; see `AccountFooter`. */
  serverUrl?: string;
  /** The server requires sign-in: the account menu offers Sign out. */
  authRequired?: boolean;
  /** Open the account menu initially, for previews. */
  defaultAccountMenuOpen?: boolean;
  /** An account menu entry was picked. */
  onAccountAction?: (action: AccountAction) => void;
  /** Mac sidebar: a 52px strip for the traffic lights and the hide button replaces the app name. Set by `AppShell` under `platform="apple"`. */
  mac?: boolean;
}

/** The 280px sidebar beside a page that has no thread list of its own (Bots, Kanban, Schedules, Profiles): app name, destinations, account footer. */
export function ShellSidebar({
  navigation,
  account,
  serverUrl,
  authRequired,
  defaultAccountMenuOpen,
  onAccountAction,
  mac,
}: ShellSidebarProps) {
  return (
    <aside className={cx("h-shell-sidebar", mac && "h-shell-sidebar--mac")}>
      <SidebarBrand mac={mac} />
      <div className="h-shell-sidebar__nav">{navigation}</div>
      <div className="h-shell-sidebar__spacer" />
      <AccountFooter
        label={account}
        serverUrl={serverUrl}
        authRequired={authRequired}
        defaultMenuOpen={defaultAccountMenuOpen}
        onAction={onAccountAction}
      />
    </aside>
  );
}

export interface AppShellProps {
  /**
   * The destinations the server offers, Chat first. With only Chat the shell
   * draws nothing of its own and shows `children` (and `sidebar`) bare.
   * `profiles` belongs on a Mac only.
   */
  destinations?: ShellDestination[];
  /** The open destination. */
  current?: ShellDestination;
  /**
   * `desktop`: the sidebar sits beside the page. The app uses it from 900px
   * wide, and from 700px on a full-screen iPad (iOS, shortest side at least
   * 600px) in either orientation; Split View halves and Slide Over stay
   * `phone`. `phone` (narrower): there is no bottom bar; the same sidebar is
   * a 280px drawer over the page, opened from the menu button in the page's
   * app bar. The drawer stays on phones under `apple` too. A Mac window is
   * always `desktop`; see `compact`.
   */
  layout?: "desktop" | "phone";
  /**
   * `apple` + `desktop` on a Mac (`device`) is the Mac window: the sidebar
   * runs from the top of the window (no brand row, 78px left free for the
   * traffic lights, a hide button), the sidebar can be hidden and resized
   * (220 to 360px), and the page's `ChatHeader` becomes the 52px unified
   * toolbar. `apple` on a phone, or on an iPad (`device="touch"`), keeps the
   * drawer or plain sidebar. Inherits the provider's platform.
   */
  platform?: Platform;
  /**
   * Under `apple`, whether the desktop layout is a Mac window (`mac`, the
   * default for `desktop`) or a full-screen iPad (`touch`): the sidebar sits
   * beside the page without the Mac chrome. The sidebar and header inside
   * inherit it. Ignored on `material`.
   */
  device?: AppleDevice;
  /** Mac only: start with the sidebar hidden. A page's `ChatHeader` then shows a "Show sidebar" button and leaves room for the traffic lights; a page without one (Kanban, Schedules) gets a 52px toolbar strip from the shell with the same button. */
  sidebarCollapsed?: boolean;
  /**
   * Mac only: the window is narrower than 760px (#399). The sidebar does not
   * sit beside the page: the page's toolbar clears the traffic lights and
   * starts with the sidebar button, which opens the sidebar over the page
   * behind a 20% scrim; picking a chat or a destination, the scrim or the
   * sidebar's own hide button closes it. A `ChatHeader` inside also folds
   * Copy Transcript and Connection Details into a "…" menu.
   */
  compact?: boolean;
  /** Mac, `compact`: show the sidebar open over the page, for previews. */
  sidebarOverlayOpen?: boolean;
  /** Mac only: sidebar width in px, clamped to 220 to 360 (default 280). */
  sidebarWidth?: number;
  /** Mac only: draw the three window buttons (traffic lights) at the top left, for previews of the window. */
  showTrafficLights?: boolean;
  /** Phone only: show the drawer open over a dimmed page. */
  drawerOpen?: boolean;
  /**
   * The left column (desktop) or the drawer (phone). For Chat pass a
   * `ThreadSidebar` with `navigation={<ShellNavigation .../>}`; leave it out
   * for the other destinations to get the plain `ShellSidebar`.
   */
  sidebar?: ReactNode;
  /** Mac: the profile switcher of the default `ShellSidebar`'s navigation; see `ShellNavigation`. */
  profiles?: MacProfileScope;
  /** Account label for the default `ShellSidebar`'s footer. */
  account?: string;
  /** Server address for the default `ShellSidebar`'s account footer. */
  serverUrl?: string;
  /** The server requires sign-in (the default `ShellSidebar`'s account menu offers Sign out). */
  authRequired?: boolean;
  /** Open the default `ShellSidebar`'s account menu initially, for previews. */
  defaultAccountMenuOpen?: boolean;
  /** An entry of the default `ShellSidebar`'s account menu was picked. */
  onAccountAction?: (action: AccountAction) => void;
  /**
   * Mac only: show the Settings list (the account menu's Settings…, ⌘,), a
   * `SettingsDialog` over the window: Appearance, Notifications and App Lock
   * with their values, then About Hermes and Change Server.
   */
  settingsOpen?: boolean;
  /** The values the Settings list shows: the theme ("Follow system") and whether notifications and app lock are on. */
  settingsValues?: Pick<
    SettingsDialogProps,
    "appearance" | "notifications" | "appLock"
  >;
  /** An entry of the Settings list was picked. */
  onSettingsPick?: (entry: SettingsEntry) => void;
  /** The Settings list was dismissed. */
  onDismissSettings?: () => void;
  /**
   * Mac only: Sign Out asks first (#445), from the account menu or the
   * Hermes menu's "Sign Out…": an Apple alert "Sign out of the dashboard?"
   * with Cancel and Sign Out. Only a server that needs sign-in offers
   * Sign Out (`authRequired`), so leave it closed without one.
   */
  signOutConfirmOpen?: boolean;
  /** Sign Out was confirmed. */
  onConfirmSignOut?: () => void;
  /** The Sign Out question was cancelled or dismissed. */
  onCancelSignOut?: () => void;
  /** A destination was picked in the sidebar or the drawer. */
  onSelect?: (destination: ShellDestination) => void;
  /** The scrim beside the open drawer was clicked. */
  onCloseDrawer?: () => void;
  /** The open page: for Chat, a `ChatHeader` over the thread or a `WelcomeView`; for Profiles on a Mac, `MacProfilesPage`. */
  children?: ReactNode;
}

/**
 * The app's frame around the open page. The destinations (Chat, Bots,
 * Kanban, Schedules, and Profiles on a Mac) are rows at the top of the
 * sidebar: beside the page on a wide screen, in a drawer on a phone, and in
 * a compact Mac window over the page. It fills its parent; give it a size.
 */
export function AppShell({
  destinations = ["chat", "kanban", "schedules"],
  current = "chat",
  layout = "desktop",
  platform,
  device: deviceProp,
  sidebarCollapsed = false,
  compact = false,
  sidebarOverlayOpen = false,
  sidebarWidth = 280,
  showTrafficLights = false,
  drawerOpen = false,
  sidebar,
  profiles,
  account,
  serverUrl,
  authRequired,
  defaultAccountMenuOpen,
  onAccountAction,
  settingsOpen = false,
  settingsValues,
  onSettingsPick,
  onDismissSettings,
  signOutConfirmOpen = false,
  onConfirmSignOut,
  onCancelSignOut,
  onSelect,
  onCloseDrawer,
  children,
}: AppShellProps) {
  const resolvedPlatform = usePlatform(platform);
  const device = useAppleDevice(layout, deviceProp);
  const mac =
    resolvedPlatform === "apple" && layout === "desktop" && device === "mac";
  const compactMac = mac && compact;
  const [collapsed, setCollapsed] = useState(sidebarCollapsed);
  const [overlay, setOverlay] = useState(sidebarOverlayOpen);
  const hidden = mac && (compact || collapsed);
  const toggleSidebar = useCallback(
    () => (compact ? setOverlay((o) => !o) : setCollapsed((c) => !c)),
    [compact],
  );
  const closeOverlay = useCallback(() => setOverlay(false), []);
  const overlayShown = compactMac && overlay;
  const [headerToggles, setHeaderToggles] = useState(0);
  const claimSidebarToggle = useCallback(() => {
    setHeaderToggles((n) => n + 1);
    return () => setHeaderToggles((n) => n - 1);
  }, []);
  const chrome = useMemo(
    () => ({
      sidebarCollapsed: hidden,
      toggleSidebar: mac ? toggleSidebar : undefined,
      claimSidebarToggle,
      device,
      compact: compactMac,
      closeOverlay: overlayShown ? closeOverlay : undefined,
    }),
    [
      hidden,
      mac,
      toggleSidebar,
      claimSidebarToggle,
      device,
      compactMac,
      overlayShown,
      closeOverlay,
    ],
  );
  const single = destinations.length <= 1;
  const side =
    sidebar ??
    (single ? null : (
      <ShellSidebar
        account={account}
        serverUrl={serverUrl}
        authRequired={authRequired}
        defaultAccountMenuOpen={defaultAccountMenuOpen}
        onAccountAction={onAccountAction}
        mac={mac}
        navigation={
          <ShellNavigation
            destinations={destinations}
            current={current}
            onSelect={onSelect}
            profiles={profiles}
          />
        }
      />
    ));
  if (layout === "phone") {
    return (
      <PlatformScope platform={resolvedPlatform}>
        <ShellChromeContext.Provider value={chrome}>
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
        </ShellChromeContext.Provider>
      </PlatformScope>
    );
  }
  const width = Math.min(360, Math.max(220, sidebarWidth)) + 1;
  const shown = side && !hidden;
  return (
    <PlatformScope platform={resolvedPlatform}>
      <ShellChromeContext.Provider value={chrome}>
        <div
          className={cx(
            "h-app-shell h-app-shell--desktop",
            mac && "h-app-shell--mac",
          )}
        >
          {mac && showTrafficLights ? (
            <span className="h-app-shell__traffic-lights h-traffic-lights">
              <span />
              <span />
              <span />
            </span>
          ) : null}
          {shown ? (
            <div
              className="h-app-shell__sidebar"
              style={mac ? { flexBasis: width, width } : undefined}
            >
              {side}
            </div>
          ) : null}
          <div className="h-app-shell__content">
            {hidden && side && headerToggles === 0 ? (
              <div className="h-app-shell__toolbar">
                <IconButton
                  icon="left_panel_open"
                  label="Show sidebar"
                  onClick={toggleSidebar}
                />
              </div>
            ) : null}
            {children}
          </div>
          {overlayShown && side ? (
            <>
              <div
                className="h-app-shell__overlay-scrim"
                aria-hidden="true"
                onClick={closeOverlay}
              />
              <div
                className="h-app-shell__overlay"
                style={{ width: width - 1 }}
              >
                {side}
              </div>
            </>
          ) : null}
          {mac && settingsOpen ? (
            <SettingsDialog
              {...settingsValues}
              device="mac"
              onPick={onSettingsPick}
              onDone={onDismissSettings}
            />
          ) : null}
          {mac && signOutConfirmOpen ? (
            <SignOutAlert
              onConfirm={onConfirmSignOut}
              onCancel={onCancelSignOut}
            />
          ) : null}
        </div>
      </ShellChromeContext.Provider>
    </PlatformScope>
  );
}
