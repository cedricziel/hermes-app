import { Button } from "../Button/Button";
import { IconButton } from "../IconButton/IconButton";
import { SectionHeader } from "../SectionHeader/SectionHeader";
import { Spinner } from "../Spinner/Spinner";
import { SwitchRow } from "../SwitchRow/SwitchRow";
import { Tag } from "../Tag/Tag";
import type { PluginItem } from "../PluginRow/PluginRow";
import { PlatformScope, usePlatform, type Platform } from "../../platform";
import "./PluginDetail.css";

/** A plugin with everything its detail shows, on top of what its row shows. */
export interface PluginDetails extends PluginItem {
  /** Installed: where it came from, after the version: "git", "bundled". */
  source?: string;
  /** Installed: hidden from the web dashboard's sidebar. */
  hidden?: boolean;
  /** Installed: Hermes can update it from its source; adds an Update button. */
  canUpdate?: boolean;
  /** Installed, `authRequired`: the command to run on the server, shown with a copy button: "hermes auth netbox". Without it the block says a login is needed. */
  authCommand?: string;
  /** Catalog: "Requires Hermes >=0.9". */
  requiresHermes?: string;
  /** Catalog: platforms it runs on: ["linux", "macos"]. */
  platforms?: string[];
  /** Catalog: tool names it provides, as monospace tags. */
  tools?: string[];
  /** Catalog: hook names it provides. */
  hooks?: string[];
  /** Catalog: middleware it provides. */
  middleware?: string[];
  /** Catalog: environment variables it needs. */
  env?: string[];
  /** Catalog: a docs address; adds a "Documentation" link. */
  docsUrl?: string;
}

export interface PluginDetailProps {
  /** The plugin to show. */
  plugin: PluginDetails;
  /**
   * `installed`: an installed plugin, with the Enabled and "Hide from
   * dashboard sidebar" switches, Update, the login block and Remove plugin.
   * `catalog`: a catalog entry, with its maintainer, tags, requirements, what
   * it provides, a docs link and, when not installed, "Enable after install"
   * and Install.
   */
  variant?: "installed" | "catalog";
  /** A change to this plugin is running: switches and buttons are disabled, Update or Install spins. */
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
  /** "Remove plugin". The app asks before removing. */
  onRemove?: () => void;
  /** Copy the login command. */
  onCopyLogin?: () => void;
  /** Catalog: Install. */
  onInstall?: () => void;
  /** Catalog: the Documentation link. */
  onOpenDocs?: () => void;
  /** Switches and spinners follow the platform; the layout is the same. Inherits the provider's platform. */
  platform?: Platform;
}

function Group({ title, names }: { title: string; names?: string[] }) {
  if (!names?.length) return null;
  return (
    <div className="h-plugin-detail__group">
      <SectionHeader variant="label" title={title} />
      <div className="h-plugin-detail__tags">
        {names.map((n) => (
          <Tag key={n} mono>
            {n}
          </Tag>
        ))}
      </div>
    </div>
  );
}

/**
 * One plugin's details and what the user can change, from the Plugins
 * screen's Installed or Catalog tab. Put it in a `Sheet dragHandle
 * padding={0}` below 900px and in `PluginsScreen`'s right-hand pane from
 * 900px; it does not know which.
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
}: PluginDetailProps) {
  const resolved = usePlatform(platform);
  const catalog = variant === "catalog";
  const meta = [
    plugin.version ? `v${plugin.version}` : null,
    plugin.source || null,
  ]
    .filter(Boolean)
    .join(" · ");
  const spinner = <Spinner size={16} color="var(--h-muted)" label="Working" />;
  return (
    <PlatformScope platform={resolved}>
      <div className="h-plugin-detail">
        <div className="h-plugin-detail__title">
          <span className="h-title-lg">{plugin.name}</span>
          {catalog && plugin.official ? (
            <Tag variant="filled">Official</Tag>
          ) : null}
        </div>
        {catalog ? (
          plugin.maintainer ? (
            <div className="h-body-sm h-muted">{plugin.maintainer}</div>
          ) : null
        ) : meta ? (
          <div className="h-body-sm h-muted">{meta}</div>
        ) : null}
        {plugin.description ? (
          <div className="h-body-md h-plugin-detail__description">
            {plugin.description}
          </div>
        ) : null}
        {catalog ? (
          <>
            <div className="h-plugin-detail__tags h-plugin-detail__gap-12">
              {plugin.commit ? <Tag mono>{plugin.commit}</Tag> : null}
              {plugin.installed ? <Tag variant="filled">Installed</Tag> : null}
              {plugin.installed && plugin.updateAvailable ? (
                <Tag variant="strong">Update available</Tag>
              ) : null}
            </div>
            {plugin.requiresHermes ? (
              <div className="h-body-md h-muted h-plugin-detail__gap-8">
                Requires Hermes {plugin.requiresHermes}
              </div>
            ) : null}
            {plugin.platforms?.length ? (
              <div className="h-body-md h-muted h-plugin-detail__gap-8">
                Platforms: {plugin.platforms.join(", ")}
              </div>
            ) : null}
            <Group title="Tools" names={plugin.tools} />
            <Group title="Hooks" names={plugin.hooks} />
            <Group title="Middleware" names={plugin.middleware} />
            <Group title="Environment variables" names={plugin.env} />
            {plugin.docsUrl ? (
              <div className="h-plugin-detail__docs">
                <Button variant="text" icon="open_in_new" onClick={onOpenDocs}>
                  Documentation
                </Button>
              </div>
            ) : null}
            {!plugin.installed ? (
              <div className="h-plugin-detail__install">
                <SwitchRow
                  title="Enable after install"
                  checked={enableAfterInstall}
                  disabled={busy}
                  onChange={onEnableAfterInstallChange}
                />
                <Button fullWidth disabled={busy} onClick={onInstall}>
                  {busy ? spinner : "Install"}
                </Button>
              </div>
            ) : null}
          </>
        ) : (
          <>
            {plugin.removedReason ? (
              <div className="h-plugin-detail__gap-12">
                <Tag variant="strong">{`Removed: ${plugin.removedReason}`}</Tag>
              </div>
            ) : null}
            <div className="h-plugin-detail__gap-8">
              <SwitchRow
                title="Enabled"
                subtitle="Applies to new chats"
                checked={(plugin.status ?? "enabled") === "enabled"}
                disabled={busy}
                onChange={onEnabledChange}
              />
              <SwitchRow
                title="Hide from dashboard sidebar"
                subtitle="Only affects the web dashboard"
                checked={Boolean(plugin.hidden)}
                disabled={busy}
                onChange={onHiddenChange}
              />
            </div>
            {plugin.canUpdate ? (
              <Button
                variant="outlined"
                fullWidth
                className="h-plugin-detail__gap-8 h-plugin-detail__tonal"
                disabled={busy}
                onClick={onUpdate}
              >
                {busy ? spinner : "Update"}
              </Button>
            ) : null}
            {plugin.authRequired ? (
              <div className="h-plugin-detail__login">
                <div className="h-label-lg">Needs login</div>
                {plugin.authCommand ? (
                  <div className="h-plugin-detail__command">
                    <span className="h-mono">{plugin.authCommand}</span>
                    <IconButton
                      icon="content_copy"
                      label="Copy command"
                      size={32}
                      onClick={onCopyLogin}
                    />
                  </div>
                ) : (
                  <div className="h-body-md">
                    This plugin needs a login on the server.
                  </div>
                )}
                <div className="h-body-sm h-muted">Run this on the server.</div>
              </div>
            ) : null}
            {plugin.removable ? (
              <Button
                variant="outlined"
                fullWidth
                className="h-plugin-detail__remove"
                disabled={busy}
                onClick={onRemove}
              >
                Remove plugin
              </Button>
            ) : null}
          </>
        )}
      </div>
    </PlatformScope>
  );
}
