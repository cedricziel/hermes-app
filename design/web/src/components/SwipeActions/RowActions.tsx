import type { ReactNode } from "react";
import { ActionSheet } from "../ActionSheet/ActionSheet";
import {
  usePlatform,
  useRowDevice,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { SwipeActions } from "./SwipeActions";

/** One thing a list row can do besides opening it, as Flutter's `RowAction`. */
export interface RowAction {
  label: string;
  icon: string;
  /** Offered as the trailing swipe action and drawn in red. */
  destructive?: boolean;
  onPress?: () => void;
}

/**
 * The list rows' share of Flutter's `RowActions`: on Apple touch the
 * destructive actions behind a trailing swipe and every action in the
 * long-press sheet, drawn after the row over its nearest positioned ancestor.
 * Elsewhere `children` as is.
 */
export function RowActions({
  title,
  actions,
  swipeRevealed,
  actionSheetOpen,
  platform,
  device,
  className,
  children,
}: {
  title: string;
  actions: RowAction[];
  swipeRevealed?: boolean;
  actionSheetOpen?: boolean;
  platform?: Platform;
  device?: AppleDevice;
  className?: string;
  children: ReactNode;
}) {
  const resolvedPlatform = usePlatform(platform);
  const rowDevice = useRowDevice(device);
  const touch = resolvedPlatform === "apple" && rowDevice === "touch";
  return (
    <>
      <SwipeActions
        actions={actions.filter((a) => a.destructive)}
        revealed={swipeRevealed}
        platform={resolvedPlatform}
        device={device}
        className={className}
      >
        {children}
      </SwipeActions>
      {touch && actionSheetOpen ? (
        <ActionSheet title={title} actions={actions} />
      ) : null}
    </>
  );
}
