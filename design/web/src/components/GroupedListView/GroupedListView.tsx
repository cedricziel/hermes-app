import type { CSSProperties, ReactNode } from "react";
import {
  cx,
  DeviceScope,
  PlatformScope,
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { metricsClass } from "../../grouped";
import "./GroupedListView.css";

export interface GroupedListViewProps {
  /** The page's `GroupedSection`s (and any `GroupedFooter`), top to bottom. */
  children?: ReactNode;
  /**
   * `apple` with `device`: on `touch` (iPhone, iPad) a 16px gutter and groups
   * at most 640px wide; on `mac` a 20px gutter and the 600px column.
   * `material`: a 16px gutter and 640px. A wider page centres the column
   * while the whole width scrolls; 32px of space ends the list. Inherits the
   * provider's platform; reaches every row inside.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch` (default, unless an enclosing `AppShell` or `SettingsScaffold` says otherwise). Every grouped component inside inherits it. */
  device?: AppleDevice;
  className?: string;
  style?: CSSProperties;
}

/**
 * The scrolling body of a settings page (Plugins, Skills, MCP servers,
 * Helper models, a form): its `GroupedSection`s keep the platform's gutter
 * and stay centred at the platform's maximum width on a wide page. Fills its
 * parent's height and scrolls; put it as the body of a `SettingsScaffold`.
 */
export function GroupedListView({
  children,
  platform,
  device,
  className,
  style,
}: GroupedListViewProps) {
  const resolved = usePlatform(platform);
  const chrome = useGroupedChrome(resolved, device);
  return (
    <PlatformScope platform={resolved}>
      <DeviceScope device={device}>
        <div
          className={cx("h-grouped-list", metricsClass(chrome), className)}
          style={style}
        >
          <div className="h-grouped-list__column">{children}</div>
        </div>
      </DeviceScope>
    </PlatformScope>
  );
}
