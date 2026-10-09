import { GroupedRow } from "../GroupedRow/GroupedRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { GroupedSwitchRow } from "../GroupedSwitchRow/GroupedSwitchRow";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { Spinner } from "../Spinner/Spinner";
import type { PluginItem } from "../PluginRow/PluginRow";
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
import "./PluginDetail.css";

/** A plugin with everything its detail shows, on top of what its row shows. */
export interface PluginDetails extends PluginItem {
  /** Installed: where it came from, after the version: "v1.2.0 · git". */
  source?: string;
  /** Installed: hidden from the web dashboard's sidebar. */
  hidden?: boolean;
  /** Installed: Hermes can update it from its source; adds an Update row. */
  canUpdate?: boolean;
  /** Installed, `authRequired`: the command to run on the server, in monospace with a copy button: "hermes auth netbox". Without it the group says a login is needed. */
  authCommand?: string;
  /** Catalog: a "Requires Hermes" row: ">=0.9". */
  requiresHermes?: string;
  /** Catalog: a "Platforms" row: ["linux", "macos"]. */
  platforms?: string[];
  /** Catalog: tool names it provides, a "Tools" group with a row each. */
  tools?: string[];
  /** Catalog: hook names it provides, a "Hooks" group. */
  hooks?: string[];
  /** Catalog: middleware it provides, a "Middleware" group. */
  middleware?: string[];
  /** Catalog: environment variables it needs, an "Environment variables" group. */
  env?: string[];
  /** Catalog: a docs address; adds a "Documentation" row with an open-in-browser glyph. */
  docsUrl?: string;
}

export interface PluginDetailProps {
  /** The plugin to show. */
  plugin: PluginDetails;
  /**
   * `installed`: an installed plugin: a "Removed" warning group, the
   * Enabled and "Hide from dashboard sidebar" switches, a "Needs login"
   * group with the command, and Update and "Remove plugin" (red) rows.
   * `catalog`: a catalog entry: when not installed "Enable after install"
   * and a full-width Install button, then Status, Commit, "Requires
   * Hermes" and Platforms rows, groups of what it provides and needs, and
   * a Documentation row.
   */
  variant?: "installed" | "catalog";
  /** A change to this plugin is running: switches and rows are disabled, Update or Install spins. */
  busy?: boolean;
  /** Catalog: "Enable after install". Default on. */
  enableAfterInstall?: boolean;
  /** Installed: the Enabled switch. */
  onEnabledChange?: (enabled: boolean) => void;
  /** Catalog: the "Enable after install" switch. */
  onEnableAfterInstallChange?: (enable: boolean) => void;
  /** The "Hide from dashboard sidebar" switch. */
  onHiddenChange?: (hidden: boolean) => void;
  onUpdate?: () => void;
  /** "Remove plugin", shown when `removable`. The app asks before removing. */
  onRemove?: () => void;
  /** Copy the login command. */
  onCopyLogin?: () => void;
  /** Catalog: Install. */
  onInstall?: () => void;
  /** Catalog: the Documentation row. */
  onOpenDocs?: () => void;
  /**
   * The header (name at the row title size + 3, semibold; a muted
   * "v1.2.0 · git" or "Official · maintainer" line; the description) over
   * `GroupedSection`s in the platform's grouped look: iOS 17px rows,
   * Mac 13px, Material 16px. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`: `mac` or `touch`; inherited from `SettingsScaffold` or `AppShell`, else touch. */
  device?: AppleDevice;
}

function Names({ header, names }: { header: string; names?: string[] }) {
  if (!names?.length) return null;
  return (
    <GroupedSection header={header}>
      {names.map((n) => (
        <GroupedRow key={n} title={n} />
      ))}
    </GroupedSection>
  );
}

/**
 * One plugin's details and what the user can change, from the Plugins
 * screen's Installed or Catalog tab, as the app's `DetailPage`: a header
 * and grouped sections. Put it in a `Sheet dragHandle padding={0}` below
 * 900px and in `PluginsScreen`'s right-hand pane from 900px; it does not
 * know which.
 */
export function PluginDetail({
  plugin,
  variant = "installed",
  busy = false,
  enableAfterInstall = true,
  onEnabledChange,
  onEnableAfterInstallChange,
  onHiddenChange,
  onUpdate,
  onRemove,
  onCopyLogin,
  onInstall,
  onOpenDocs,
  platform,
  device,
}: PluginDetailProps) {
  const resolved = usePlatform(platform);
  const chrome = useGroupedChrome(resolved, device);
  const catalog = variant === "catalog";
  const spinner = <Spinner size={chrome === "mac" ? 14 : 16} label="Working" />;
  const meta = (
    catalog
      ? [plugin.official && "Official", plugin.maintainer]
      : [plugin.version && `v${plugin.version}`, plugin.source]
  )
    .filter(Boolean)
    .join(" · ");
  const facts = [
    plugin.installed ? (
      <GroupedRow
        key="status"
        title="Status"
        value={plugin.updateAvailable ? "Update available" : "Installed"}
      />
    ) : null,
    plugin.commit ? (
      <GroupedRow key="commit" title="Commit" value={plugin.commit} />
    ) : null,
    plugin.requiresHermes ? (
      <GroupedRow
        key="requires"
        title="Requires Hermes"
        value={plugin.requiresHermes}
      />
    ) : null,
    plugin.platforms?.length ? (
      <GroupedRow
        key="platforms"
        title="Platforms"
        value={plugin.platforms.join(", ")}
      />
    ) : null,
  ].filter(Boolean);
  return (
    <PlatformScope platform={resolved}>
      <DeviceScope device={device}>
        <div className={cx("h-plugin-detail", metricsClass(chrome))}>
          <div className="h-plugin-detail__header">
            <div className="h-plugin-detail__title">{plugin.name}</div>
            {meta ? <div className="h-plugin-detail__meta">{meta}</div> : null}
            {plugin.description ? (
              <div className="h-plugin-detail__description">
                {plugin.description}
              </div>
            ) : null}
          </div>
          {catalog ? (
            <>
              {!plugin.installed ? (
                <>
                  <GroupedSection>
                    <GroupedSwitchRow
                      title="Enable after install"
                      checked={enableAfterInstall}
                      disabled={busy}
                      onChange={onEnableAfterInstallChange}
                    />
                  </GroupedSection>
                  <button
                    type="button"
                    className="h-plugin-detail__install"
                    disabled={busy}
                    onClick={onInstall}
                  >
                    {busy ? (
                      <Spinner
                        size={16}
                        color="currentColor"
                        label="Installing"
                      />
                    ) : (
                      "Install"
                    )}
                  </button>
                </>
              ) : null}
              {facts.length ? <GroupedSection>{facts}</GroupedSection> : null}
              <Names header="Tools" names={plugin.tools} />
              <Names header="Hooks" names={plugin.hooks} />
              <Names header="Middleware" names={plugin.middleware} />
              <Names header="Environment variables" names={plugin.env} />
              {plugin.docsUrl ? (
                <GroupedSection>
                  <GroupedRow
                    title="Documentation"
                    chevron={false}
                    trailing={
                      <span className="h-plugin-detail__external">
                        <Icon name="open_in_new" size={16} />
                      </span>
                    }
                    onClick={onOpenDocs}
                  />
                </GroupedSection>
              ) : null}
            </>
          ) : (
            <>
              {plugin.removedReason ? (
                <GroupedSection>
                  <GroupedRow title="Removed" warning={plugin.removedReason} />
                </GroupedSection>
              ) : null}
              <GroupedSection>
                <GroupedSwitchRow
                  title="Enabled"
                  subtitle="Applies to new chats"
                  checked={(plugin.status ?? "enabled") === "enabled"}
                  disabled={busy}
                  onChange={onEnabledChange}
                />
                <GroupedSwitchRow
                  title="Hide from dashboard sidebar"
                  subtitle="Only affects the web dashboard"
                  checked={Boolean(plugin.hidden)}
                  disabled={busy}
                  onChange={onHiddenChange}
                />
              </GroupedSection>
              {plugin.authRequired ? (
                plugin.authCommand ? (
                  <GroupedSection
                    header="Needs login"
                    footer="Run this on the server."
                  >
                    <div className="h-plugin-detail__command">
                      <span>{plugin.authCommand}</span>
                      <IconButton
                        icon="content_copy"
                        label="Copy command"
                        tone="muted"
                        size={chrome === "mac" ? 32 : 40}
                        onClick={onCopyLogin}
                      />
                    </div>
                  </GroupedSection>
                ) : (
                  <GroupedSection header="Needs login">
                    <GroupedRow title="This plugin needs a login on the server." />
                  </GroupedSection>
                )
              ) : null}
              {plugin.canUpdate || plugin.removable ? (
                <GroupedSection>
                  {plugin.canUpdate ? (
                    <GroupedRow
                      title="Update"
                      chevron={false}
                      trailing={busy ? spinner : undefined}
                      disabled={busy}
                      onClick={onUpdate}
                    />
                  ) : null}
                  {plugin.removable ? (
                    <GroupedRow
                      title="Remove plugin"
                      destructive
                      chevron={false}
                      disabled={busy}
                      onClick={onRemove}
                    />
                  ) : null}
                </GroupedSection>
              ) : null}
            </>
          )}
        </div>
      </DeviceScope>
    </PlatformScope>
  );
}
