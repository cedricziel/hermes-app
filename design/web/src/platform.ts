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

/** What a Mac `AppShell` tells its sidebar and the page's header about the collapsible sidebar. */
export interface ShellChrome {
  /** The sidebar is hidden: the header then leaves room for the traffic lights and shows the toggle. */
  sidebarCollapsed: boolean;
  /** Present only inside a Mac `AppShell`; hides or shows the sidebar. */
  toggleSidebar?: () => void;
}

export const ShellChromeContext = createContext<ShellChrome>({
  sidebarCollapsed: false,
});

/** Width in px a Mac window's traffic lights take at the top left, which the sidebar and a collapsed header leave free. */
export const TRAFFIC_LIGHT_GAP = 78;
