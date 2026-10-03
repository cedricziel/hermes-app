import { createContext, useContext } from "react";
import "./styles/apple.css";

/**
 * Whose conventions a component follows. `apple` is iOS, iPadOS and macOS (Human
 * Interface Guidelines); `material` is Android, Windows and Linux, and the
 * look every component had before this prop existed.
 */
export type Platform = "apple" | "material";

export const PlatformContext = createContext<Platform>("material");

/** An explicit `platform` prop wins; otherwise the nearest `HermesProvider`'s, otherwise material. */
export function usePlatform(platform?: Platform): Platform {
  const inherited = useContext(PlatformContext);
  return platform ?? inherited;
}

export function cx(...names: Array<string | false | null | undefined>) {
  return names.filter(Boolean).join(" ");
}
