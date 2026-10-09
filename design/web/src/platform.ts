import {
  createContext,
  createElement,
  Fragment,
  useContext,
  type ReactNode,
} from "react";
import "./styles/apple.css";

/**
 * Whose conventions a component follows. `apple` is iOS, iPadOS and macOS (Human
 * Interface Guidelines); `material` is Android, Windows and Linux, and the
 * look every component had before this prop existed.
 */
export type Platform = "apple" | "material";

/** The text ramp a `HermesProvider` sets; see its `typeRamp`. */
export type TypeRamp = "ios" | "default";

/** What the nearest `HermesProvider` chose; undefined outside one. */
export const PlatformContext = createContext<Platform | undefined>(undefined);
export const TypeRampContext = createContext<TypeRamp | undefined>(undefined);

/** An explicit `platform` prop wins; otherwise the nearest `HermesProvider`'s, otherwise material. */
export function usePlatform(platform?: Platform): Platform {
  const inherited = useContext(PlatformContext);
  return platform ?? inherited ?? "material";
}

/**
 * Hands a component's resolved platform to everything it renders, so an
 * explicit `platform` prop also reaches its nested `Icon`s and components
 * instead of only its own classes.
 */
export function PlatformScope({
  platform,
  children,
}: {
  platform: Platform;
  children?: ReactNode;
}) {
  return createElement(PlatformContext.Provider, { value: platform }, children);
}

export function cx(...names: Array<string | false | null | undefined>) {
  return names.filter(Boolean).join(" ");
}

/**
 * Which Apple device a component is drawn for where touch and pointer differ.
 * `mac`: pointer, the unified toolbar, the sidebar under the traffic lights
 * and compact menus. `touch`: iPhone and iPad, 44px targets and iOS menus.
 * Without it a `phone` layout is `touch` and a `desktop` layout follows the
 * enclosing `AppShell`, else `mac`; so a full-screen iPad, which uses the
 * desktop layout, passes `device="touch"` (once, on its `AppShell`). Ignored
 * on `material`.
 */
export type AppleDevice = "mac" | "touch";

/** What a desktop `AppShell` tells its sidebar and the page's header. */
export interface ShellChrome {
  /** The sidebar is hidden: the header then leaves room for the traffic lights and shows the toggle. */
  sidebarCollapsed: boolean;
  /** Present only inside a Mac `AppShell`; hides or shows the sidebar. */
  toggleSidebar?: () => void;
  /**
   * A header that shows its own "Show sidebar" button calls this while
   * mounted (it returns the release), so the shell draws its fallback
   * button only on pages without one.
   */
  claimSidebarToggle?: () => () => void;
  /** The shell's resolved Apple device, which its sidebar and header inherit. */
  device?: AppleDevice;
  /** A compact Mac window (under 760px): the sidebar opens over the page, and the page's toolbar folds its secondary buttons into a menu. */
  compact?: boolean;
  /** Present while a compact Mac window's sidebar lies over the page; a pick in the sidebar calls it. */
  closeOverlay?: () => void;
}

export const ShellChromeContext = createContext<ShellChrome>({
  sidebarCollapsed: false,
});

/** Resolves `AppleDevice` as its doc says: an explicit `device`, then a phone layout (touch), then the enclosing `AppShell`'s, then `mac`. */
export function useAppleDevice(
  layout: "desktop" | "phone",
  device?: AppleDevice,
): AppleDevice {
  const shell = useContext(ShellChromeContext);
  if (device) return device;
  return layout === "phone" ? "touch" : (shell.device ?? "mac");
}

/** The device a list row draws its swipe and long-press actions for: an explicit `device`, then the enclosing `AppShell`'s, then `touch`. */
export function useRowDevice(device?: AppleDevice): AppleDevice {
  const shell = useContext(ShellChromeContext);
  return device ?? shell.device ?? "touch";
}

/** Width in px a Mac window's traffic lights take at the top left, which the sidebar and a collapsed header leave free. */
export const TRAFFIC_LIGHT_GAP = 78;

/**
 * The look a grouped settings component draws: `ios` (iPhone, iPad), `mac`
 * or `material`, as Flutter's `PlatformChrome`.
 */
export type GroupedChrome = "ios" | "mac" | "material";

/** Sets the Apple device for a subtree, keeping the enclosing `AppShell`'s other state, so rows and menus inside a Mac page draw the Mac look. */
export function DeviceScope({
  device,
  children,
}: {
  device?: AppleDevice;
  children?: ReactNode;
}) {
  const shell = useContext(ShellChromeContext);
  if (!device || device === shell.device) {
    return createElement(Fragment, null, children);
  }
  return createElement(
    ShellChromeContext.Provider,
    { value: { ...shell, device } },
    children,
  );
}

/** Resolves a grouped component's look: `material`, else the Apple device (an explicit `device`, then the enclosing scope's, then `touch`). */
export function useGroupedChrome(
  platform?: Platform,
  device?: AppleDevice,
): GroupedChrome {
  const resolved = usePlatform(platform);
  const rowDevice = useRowDevice(device);
  if (resolved === "material") return "material";
  return rowDevice === "mac" ? "mac" : "ios";
}
