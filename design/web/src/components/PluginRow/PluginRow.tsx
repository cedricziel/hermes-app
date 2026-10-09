import { GroupedRow } from "../GroupedRow/GroupedRow";
import { RowActions } from "../SwipeActions/RowActions";
import {
  PlatformScope,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { RowButton } from "../../rowButton";
import "./PluginRow.css";

/** A Hermes agent plugin: one installed on the server, or an entry in the curated catalog. */
export interface PluginItem {
  /** Plugin name, e.g. "netbox" or "hermes-plugin-weather". One line, then ellipsis. */
  name: string;
  /** Installed version, after the name as muted "v1.2.0" (installed rows). */
  version?: string;
  /** Who publishes it, first in the subtitle: "Nous Research · Drive a headless browser." (catalog rows). */
  maintainer?: string;
  /** What it does, in the one-line subtitle after "Bundled" or the maintainer. */
  description?: string;
  /** Short commit of the catalog entry: "a3f9c21". Shown in its details, not the row. */
  commit?: string;
  /** Whether an installed plugin is on: the row's muted value reads "On", "Off" or "Inactive". */
  status?: "enabled" | "disabled" | "inactive";
  /** Ships with Hermes: the subtitle starts with "Bundled". */
  bundled?: boolean;
  /** Needs `hermes auth` on the server: a "Needs login" warning line. */
  authRequired?: boolean;
  /** Why the hub pulled it, e.g. "unsafe network call": a "Removed: <reason>" warning line. */
  removedReason?: string;
  /** Curated by Nous: muted "Official" after the name (catalog rows). */
  official?: boolean;
  /** Already installed: the catalog row reads "Installed" (with a chevron on Apple) instead of the Install button. */
  installed?: boolean;
  /** A newer commit than the installed one exists: the catalog row reads "Update available". */
  updateAvailable?: boolean;
  /** The server can delete it (installed from Git, not bundled): its swipe and action sheet offer Remove. */
  removable?: boolean;
}

export interface PluginRowProps {
  /** The plugin to show. */
  plugin: PluginItem;
  /**
   * `installed`: a row of the Installed tab: name, "v1.2.0", "Bundled · what
   * it does", a warning for a needed login or a removal, and "On", "Off" or
   * "Inactive". `catalog`: a row of the Catalog tab: name, "Official",
   * "maintainer · what it does", and "Installed" / "Update available" or a
   * small Install button.
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
   * `apple`: a disclosure chevron after the value (installed rows, and
   * catalog entries already installed); Install is a tinted pill on iOS
   * (28px, 15px semibold) and a bordered push button on a Mac (22px, 6px
   * corners, 12px). On touch an installed row swipes from the trailing edge
   * to Remove (when `removable`) and a long press opens an action sheet with
   * Enable or Disable, and Remove (see `swipeRevealed`, `actionSheetOpen`).
   * `material`: no chevron, Install an outlined 32px pill. Inherits the
   * provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac`; only touch swipes. Inherited from the enclosing `SettingsScaffold`, `GroupedSection` or `AppShell`, else touch. */
  device?: AppleDevice;
  /** Apple touch, installed rows: draw the row swiped open, Remove showing in red. A static preview state. */
  swipeRevealed?: boolean;
  /** Apple touch, installed rows: draw the long-press action sheet over the screen (the nearest positioned ancestor). A static preview state. */
  actionSheetOpen?: boolean;
}

const statusLabels = { enabled: "On", disabled: "Off", inactive: "Inactive" };

/**
 * One plugin in the Plugins screen's Installed or Catalog list: a
 * `GroupedRow`, so stack rows in one `GroupedSection`. Status reads as
 * muted text, never as a pill; its switch lives in `PluginDetail`.
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
  const resolved = usePlatform(platform);
  const apple = resolved === "apple";
  const join = (parts: Array<string | false | undefined>) =>
    parts.filter(Boolean).join(" · ") || undefined;
  if (variant === "catalog") {
    return (
      <PlatformScope platform={resolved}>
        <GroupedRow
          title={plugin.name}
          meta={plugin.official ? "Official" : undefined}
          subtitle={join([plugin.maintainer, plugin.description])}
          value={
            !plugin.installed
              ? undefined
              : plugin.updateAvailable
                ? "Update available"
                : "Installed"
          }
          trailing={
            plugin.installed ? undefined : (
              <RowButton
                label="Install"
                busy={installing}
                onClick={onInstall}
                device={device}
              />
            )
          }
          chevron={!!plugin.installed && apple}
          selected={selected}
          onClick={onClick}
          device={device}
        />
      </PlatformScope>
    );
  }
  const enabled = (plugin.status ?? "enabled") === "enabled";
  return (
    <PlatformScope platform={resolved}>
      <RowActions
        title={plugin.name}
        actions={[
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
        ]}
        swipeRevealed={swipeRevealed}
        actionSheetOpen={actionSheetOpen}
        device={device}
        className="h-plugin-row"
      >
        <GroupedRow
          title={plugin.name}
          meta={plugin.version ? `v${plugin.version}` : undefined}
          subtitle={join([plugin.bundled && "Bundled", plugin.description])}
          warning={join([
            plugin.authRequired && "Needs login",
            plugin.removedReason && `Removed: ${plugin.removedReason}`,
          ])}
          value={statusLabels[plugin.status ?? "enabled"]}
          chevron={apple}
          selected={selected}
          onClick={onClick}
          device={device}
        />
      </RowActions>
    </PlatformScope>
  );
}
