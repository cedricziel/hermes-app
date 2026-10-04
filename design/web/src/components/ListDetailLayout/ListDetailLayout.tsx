import { useContext, type ReactNode } from "react";
import { Button } from "../Button/Button";
import { IconButton } from "../IconButton/IconButton";
import {
  cx,
  PlatformScope,
  ShellChromeContext,
  usePlatform,
  type Platform,
} from "../../platform";
import { Icon } from "../Icon/Icon";
import "./ListDetailLayout.css";

export interface ListDetailLayoutProps {
  /** Page title in the app bar: "MCP servers", "Plugins", "Schedules". */
  title: string;
  /** Small line under the title, e.g. "Profile: work". */
  subtitle?: string;
  /** Shows a back arrow before the title and calls this when it is pressed (a pushed screen on phone). Under `apple` it is a chevron, with `backLabel` beside it in the `list` layout. */
  onBack?: () => void;
  /** Apple, `list` layout (iPhone): the parent screen's title shown beside the back chevron, "Settings" or "Chats". Ignored on `material` and in the `split` layout, where the chevron stands alone. */
  backLabel?: string;
  /** Right side of the app bar: text buttons such as `<Button variant="text" icon="add">Add</Button>` and icon buttons (refresh, more_vert). */
  actions?: ReactNode;
  /** Tabs under the app bar: e.g. ["Installed", "Catalog", "Providers"]. A Material underline tab bar spanning the full width; under `apple` an iOS segmented control instead. */
  tabs?: string[];
  /** Index of the selected tab. */
  activeTab?: number;
  /** A tab was clicked. */
  onTabChange?: (index: number) => void;
  /** Content of the list pane: rows such as McpServerRow, PluginRow or ScheduleJobRow, plus any filters or notes above them. Scrolls on its own. */
  list: ReactNode;
  /** Content of the detail pane for the selected item. Scrolls on its own. Ignored in the `list` layout. */
  detail?: ReactNode;
  /** Centered text in the detail pane when `detail` is empty: "Select a plugin". */
  placeholder?: string;
  /**
   * `split`: list pane and detail pane side by side, as the app does from
   * 900px wide. `list`: the list alone at full width, as on a phone, where an
   * item opens as its own screen or bottom sheet.
   */
  layout?: "split" | "list";
  /** Width of the list pane in px: 380 for MCP servers, 400 for Plugins and Schedules. */
  listWidth?: number;
  /** Inner padding of the detail pane in px. */
  detailPadding?: number;
  /** Floating action at the bottom right, such as the Schedules "New" button. Under `apple` prefer `onAdd`, which replaces it with a "+" in the bar; without `onAdd` it stays, so the action is never lost. */
  floatingAction?: ReactNode;
  /**
   * The screen's "add" action (a new schedule or skill). Material: the
   * extended floating action button, labelled `addLabel`. Apple: a "+" button
   * last in the app bar, since iOS has no floating action buttons. Leave it
   * out for screens that add nothing.
   */
  onAdd?: () => void;
  /** Label of the Material floating action button and the accessible name of the Apple "+": "New schedule". */
  addLabel?: string;
  /**
   * `apple` follows the HIG: a chevron back button (with the parent's title
   * on a phone), a "+" in the bar instead of the FAB and a segmented control
   * instead of underline tabs. The split layout starts at 900px, and on a
   * full-screen iPad from 700px. Inside a Mac `AppShell` the bar is the
   * 52px unified toolbar (44px elsewhere under `apple`). Inherits the
   * provider's platform.
   */
  platform?: Platform;
}

/**
 * The list + detail screen used by MCP servers, Plugins and Schedules: an app
 * bar (title, subtitle, actions), optional tabs, a fixed-width list pane with
 * a 1px divider, and a detail pane. Fills its parent's height; give the parent
 * an explicit size.
 */
export function ListDetailLayout({
  title,
  subtitle,
  onBack,
  backLabel,
  actions,
  tabs,
  activeTab = 0,
  onTabChange,
  list,
  detail,
  placeholder,
  layout = "split",
  listWidth = 400,
  detailPadding = 16,
  floatingAction,
  onAdd,
  addLabel = "Add",
  platform,
}: ListDetailLayoutProps) {
  const split = layout === "split";
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const shellDevice = useContext(ShellChromeContext).device;
  const mac = apple && shellDevice === "mac";
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div
        className={cx(
          "h-list-detail",
          apple && "h-list-detail--apple",
          mac && "h-list-detail--mac",
        )}
      >
        <header className="h-list-detail__bar">
          {onBack && apple ? (
            <button
              type="button"
              className="h-list-detail__back"
              aria-label="Back"
              onClick={onBack}
            >
              {/* The app's back button: CupertinoIcons.back on iOS, Flutter's
                  Material BackButton (a rounded chevron) on macOS. */}
              {mac ? (
                <Icon name="arrow_back_ios_new" apple={false} size={20} />
              ) : (
                <Icon name="arrow_back" apple="back" size={30} />
              )}
              {!split && backLabel ? <span>{backLabel}</span> : null}
            </button>
          ) : onBack ? (
            <IconButton icon="arrow_back" label="Back" onClick={onBack} />
          ) : null}
          <div
            className={[
              "h-list-detail__titles",
              onBack ? "h-list-detail__titles--after-back" : null,
            ]
              .filter(Boolean)
              .join(" ")}
          >
            <div className="h-list-detail__title">{title}</div>
            {subtitle ? (
              <div className="h-list-detail__subtitle">{subtitle}</div>
            ) : null}
          </div>
          {actions || (apple && onAdd) ? (
            <div className="h-list-detail__actions">
              {actions}
              {apple && onAdd ? (
                <IconButton icon="add" label={addLabel} onClick={onAdd} />
              ) : null}
            </div>
          ) : null}
        </header>
        {tabs && tabs.length > 0 ? (
          <div
            className={cx(
              "h-list-detail__tabs",
              apple && "h-list-detail__tabs--segmented",
            )}
            role="tablist"
          >
            {tabs.map((tab, i) => (
              <button
                key={tab}
                type="button"
                role="tab"
                aria-selected={i === activeTab}
                className={[
                  "h-list-detail__tab",
                  i === activeTab ? "h-list-detail__tab--active" : null,
                ]
                  .filter(Boolean)
                  .join(" ")}
                onClick={() => onTabChange?.(i)}
              >
                <span className="h-list-detail__tab-label">{tab}</span>
              </button>
            ))}
          </div>
        ) : null}
        <div className="h-list-detail__body">
          <div
            className="h-list-detail__list"
            style={split ? { width: listWidth, flex: "none" } : undefined}
          >
            {list}
          </div>
          {split ? (
            <div
              className="h-list-detail__detail"
              style={{ padding: detail ? detailPadding : 0 }}
            >
              {detail ?? (
                <div className="h-list-detail__placeholder">{placeholder}</div>
              )}
            </div>
          ) : null}
          {floatingAction && !(apple && onAdd) ? (
            <div className="h-list-detail__fab">{floatingAction}</div>
          ) : null}
          {!apple && !floatingAction && onAdd ? (
            <div className="h-list-detail__fab">
              <Button icon="add" onClick={onAdd}>
                {addLabel}
              </Button>
            </div>
          ) : null}
        </div>
      </div>
    </PlatformScope>
  );
}
