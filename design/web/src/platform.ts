import {
  createContext,
  createElement,
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

/** Width in px a Mac window's traffic lights take at the top left, which the sidebar and a collapsed header leave free. */
export const TRAFFIC_LIGHT_GAP = 78;
