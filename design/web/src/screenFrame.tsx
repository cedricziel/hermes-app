import type { ReactNode } from "react";
import { ListDetailLayout } from "./components/ListDetailLayout/ListDetailLayout";
import { usePlatform, type AppleDevice, type Platform } from "./platform";
import "./screenFrame.css";

/** Phone (touch) or desktop (Mac window, Material desktop) for a pushed screen. */
export type ScreenLayout = "phone" | "desktop";

export interface ScreenFrameProps {
  title: string;
  subtitle?: string;
  backLabel?: string;
  onBack?: () => void;
  onClose?: () => void;
  actions?: ReactNode;
  tabs?: string[];
  activeTab?: number;
  onTabChange?: (index: number) => void;
  onAdd?: () => void;
  addLabel?: string;
  layout: ScreenLayout;
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
  /** Max width of the centred content column: 640 (ContentColumn) or 720 (kDetailContentMaxWidth). `null` lets it fill the width. */
  maxWidth?: number | null;
  /** Pinned under the scrolling content (a bottom bar or a format toolbar). */
  footer?: ReactNode;
  /** A strip between the bar and the content that spans the full width (the Skills job bar). */
  banner?: ReactNode;
  /** Centre the content vertically (loading spinners and state messages). */
  centered?: boolean;
  children?: ReactNode;
}

/**
 * The scaffold of a pushed single-pane screen (Profiles, Bots, Skills, Helper
 * models...): `ListDetailLayout` in its `list` layout for the app bar, the
 * content in a centred column like Flutter's `ContentColumn`, and an
 * optional pinned footer. On a Mac (`apple` + `desktop`) the bar is the 52px
 * toolbar, since the pushed route fills the window.
 */
export function ScreenFrame({
  layout,
  platform,
  device,
  maxWidth = 640,
  footer,
  banner,
  centered = false,
  children,
  ...bar
}: ScreenFrameProps) {
  const resolved = usePlatform(platform);
  const column = maxWidth === null ? undefined : { maxWidth };
  return (
    <ListDetailLayout
      {...bar}
      layout="list"
      platform={resolved}
      device={layout === "phone" ? "touch" : (device ?? "mac")}
      list={
        <div className="h-screen-frame">
          {banner}
          <div className="h-screen-frame__scroll">
            <div
              className={
                centered
                  ? "h-screen-frame__column h-screen-frame__column--centered"
                  : "h-screen-frame__column"
              }
              style={column}
            >
              {children}
            </div>
          </div>
          {footer ? (
            <div className="h-screen-frame__footer">
              <div className="h-screen-frame__footer-column" style={column}>
                {footer}
              </div>
            </div>
          ) : null}
        </div>
      }
    />
  );
}
