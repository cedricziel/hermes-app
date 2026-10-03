import type { ReactNode } from "react";
import { IconButton } from "../IconButton/IconButton";
import "./ListDetailLayout.css";

export interface ListDetailLayoutProps {
  /** Page title in the app bar: "MCP servers", "Plugins", "Schedules". */
  title: string;
  /** Small line under the title, e.g. "Profile: work". */
  subtitle?: string;
  /** Shows a back arrow before the title and calls this when it is pressed (a pushed screen on phone). */
  onBack?: () => void;
  /** Right side of the app bar: text buttons such as `<Button variant="text" icon="add">Add</Button>` and icon buttons (refresh, more_vert). */
  actions?: ReactNode;
  /** Material tab bar under the app bar, spanning the full width: e.g. ["Installed", "Catalog", "Providers"]. */
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
  /** Floating action at the bottom right, such as the Schedules "New" button. */
  floatingAction?: ReactNode;
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
}: ListDetailLayoutProps) {
  const split = layout === "split";
  return (
    <div className="h-list-detail">
      <header className="h-list-detail__bar">
        {onBack ? (
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
        {actions ? (
          <div className="h-list-detail__actions">{actions}</div>
        ) : null}
      </header>
      {tabs && tabs.length > 0 ? (
        <div className="h-list-detail__tabs" role="tablist">
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
        {floatingAction ? (
          <div className="h-list-detail__fab">{floatingAction}</div>
        ) : null}
      </div>
    </div>
  );
}
