import { Button } from "../Button/Button";
import { Spinner } from "../Spinner/Spinner";
import { RowActions } from "../SwipeActions/RowActions";
import {
  PlatformScope,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./PluginRow.css";

/** A Hermes agent plugin: one installed on the server, or an entry in the curated catalog. */
export interface PluginItem {
  /** Plugin name, e.g. "netbox" or "hermes-plugin-weather". One line, then ellipsis. */
  name: string;
  /** Installed version next to the name, e.g. "1.0.0" (installed rows). */
  version?: string;
  /** Who publishes it, as a small line under the name (catalog rows). */
  maintainer?: string;
  /** What it does. Two lines, then ellipsis. */
  description?: string;
  /** Short commit of the catalog entry, shown as a monospace tag: "a3f9c21" (catalog rows). */
  commit?: string;
  /** Status chip of an installed plugin: `enabled` (solid), `disabled` or `inactive` (outlined). */
  status?: "enabled" | "disabled" | "inactive";
  /** Ships with Hermes; adds a "Bundled" tag. */
  bundled?: boolean;
  /** Needs `hermes auth` on the server; adds a "Needs login" tag. */
  authRequired?: boolean;
  /** Why the hub pulled it, e.g. "unsafe network call"; adds "Removed: <reason>". */
  removedReason?: string;
  /** Curated by Nous; a solid "Official" tag next to the name (catalog rows). */
  official?: boolean;
  /** Already installed: the catalog row shows an "Installed" chip instead of Install. */
  installed?: boolean;
  /** A newer commit than the installed one exists; adds "Update available" (catalog rows). */
  updateAvailable?: boolean;
  /** The server can delete it (installed from Git, not bundled): its swipe and action sheet offer Remove. */
  removable?: boolean;
}

export interface PluginRowProps {
  /** The plugin to show. */
  plugin: PluginItem;
  /**
   * `installed`: a row of the Installed tab, with name + version and a status
   * chip. `catalog`: a row of the Catalog tab, with maintainer, commit and an
   * Install button (or an "Installed" chip).
   */
  variant?: "installed" | "catalog";
  /** Highlighted as the plugin open in the detail pane (wide layout). */
  selected?: boolean;
  /** An install of this catalog entry is running: Install shows a spinner and is disabled. */
  installing?: boolean;
  /** The row was clicked: open the plugin's detail. */
  onClick?: () => void;
  /** Install was pressed on a catalog row. */
  onInstall?: () => void;
  /** Enable or Disable was picked from an installed row's action sheet. */
  onEnabledChange?: (enabled: boolean) => void;
  /** Remove was picked from an installed row's swipe or action sheet. */
  onRemove?: () => void;
  /**
   * `apple`: Install's spinner is the activity indicator. On touch an
   * installed row swipes from the trailing edge to Remove (when `removable`)
   * and a long press opens an action sheet with Enable or Disable, and
   * Remove (see `swipeRevealed`, `actionSheetOpen`); a Mac right-clicks for
   * them. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` (default) or `mac`; only touch swipes. Inherited from the enclosing `AppShell`. */
  device?: AppleDevice;
  /** Apple touch, installed rows: draw the row swiped open, Remove showing in red. A static preview state. */
  swipeRevealed?: boolean;
  /** Apple touch, installed rows: draw the long-press action sheet over the screen (the nearest positioned ancestor). A static preview state. */
  actionSheetOpen?: boolean;
}

function Tag({
  children,
  strong,
  filled,
  mono,
}: {
  children: string;
  strong?: boolean;
  filled?: boolean;
  mono?: boolean;
}) {
  return (
    <span
      className={[
        "h-plugin-row__tag",
        strong ? "h-plugin-row__tag--strong" : null,
        filled ? "h-plugin-row__tag--filled" : null,
        mono ? "h-plugin-row__tag--mono" : null,
      ]
        .filter(Boolean)
        .join(" ")}
    >
      {children}
    </span>
  );
}

/**
 * One plugin in the Plugins screen's Installed or Catalog list: a full-width
 * list tile with the name, a two-line description, small pill tags and a
 * trailing status chip or Install button. Separate rows with a 1px divider.
 */
export function PluginRow({
  plugin,
  variant = "installed",
  selected = false,
  installing = false,
  onClick,
  onInstall,
  onEnabledChange,
  onRemove,
  platform,
  device,
  swipeRevealed,
  actionSheetOpen,
}: PluginRowProps) {
  const resolvedPlatform = usePlatform(platform);
  const catalog = variant === "catalog";
  const tags = catalog
    ? [
        plugin.commit ? (
          <Tag key="commit" mono>
            {plugin.commit}
          </Tag>
        ) : null,
        plugin.installed && plugin.updateAvailable ? (
          <Tag key="update" strong>
            Update available
          </Tag>
        ) : null,
      ].filter(Boolean)
    : [
        plugin.bundled ? <Tag key="bundled">Bundled</Tag> : null,
        plugin.authRequired ? (
          <Tag key="login" strong>
            Needs login
          </Tag>
        ) : null,
        plugin.removedReason ? (
          <Tag key="removed" strong>
            {`Removed: ${plugin.removedReason}`}
          </Tag>
        ) : null,
      ].filter(Boolean);
  const status = plugin.status ?? "enabled";
  const enabled = status === "enabled";
  const actions = catalog
    ? []
    : [
        {
          label: enabled ? "Disable" : "Enable",
          icon: enabled ? "toggle_off" : "toggle_on",
          onPress: () => onEnabledChange?.(!enabled),
        },
        ...(plugin.removable
          ? [
              {
                label: "Remove",
                icon: "delete",
                destructive: true,
                onPress: onRemove,
              },
            ]
          : []),
      ];
  return (
    <PlatformScope platform={resolvedPlatform}>
      <RowActions
        title={plugin.name}
        actions={actions}
        swipeRevealed={swipeRevealed}
        actionSheetOpen={actionSheetOpen}
        device={device}
      >
        <div
          className={[
            "h-plugin-row",
            selected ? "h-plugin-row--selected" : null,
          ]
            .filter(Boolean)
            .join(" ")}
          role="button"
          tabIndex={0}
          aria-pressed={selected}
          onClick={onClick}
          onKeyDown={(e) => {
            if (e.key === "Enter" || e.key === " ") {
              e.preventDefault();
              onClick?.();
            }
          }}
        >
          <div className="h-plugin-row__body">
            <div className="h-plugin-row__title">
              <span className="h-plugin-row__name">{plugin.name}</span>
              {!catalog && plugin.version ? (
                <span className="h-plugin-row__version">{plugin.version}</span>
              ) : null}
              {catalog && plugin.official ? <Tag filled>Official</Tag> : null}
            </div>
            {catalog && plugin.maintainer ? (
              <div className="h-plugin-row__maintainer">
                {plugin.maintainer}
              </div>
            ) : null}
            {plugin.description ? (
              <div className="h-plugin-row__description">
                {plugin.description}
              </div>
            ) : null}
            {tags.length > 0 ? (
              <div className="h-plugin-row__tags">{tags}</div>
            ) : null}
          </div>
          <div className="h-plugin-row__trailing">
            {catalog ? (
              plugin.installed ? (
                <Tag filled>Installed</Tag>
              ) : (
                <Button
                  disabled={installing}
                  onClick={(e) => {
                    e.stopPropagation();
                    onInstall?.();
                  }}
                >
                  {installing ? (
                    <Spinner
                      size={16}

                      color="var(--h-muted)"
                      label="Installing"
                    />
                  ) : (
                    "Install"
                  )}
                </Button>
              )
            ) : (
              <Tag filled={enabled}>
                {enabled
                  ? "Enabled"
                  : status === "disabled"
                    ? "Disabled"
                    : "Inactive"}
              </Tag>
            )}
          </div>
        </div>
      </RowActions>
    </PlatformScope>
  );
}
