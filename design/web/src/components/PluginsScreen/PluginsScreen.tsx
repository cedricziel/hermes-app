import { Button } from "../Button/Button";
import { FormSection } from "../FormSection/FormSection";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { ListDetailLayout } from "../ListDetailLayout/ListDetailLayout";
import { ListRow } from "../ListRow/ListRow";
import { PluginDetail, type PluginDetails } from "../PluginDetail/PluginDetail";
import { PluginRow } from "../PluginRow/PluginRow";
import { RadioRow } from "../RadioRow/RadioRow";
import { SectionHeader } from "../SectionHeader/SectionHeader";
import { Sheet } from "../Sheet/Sheet";
import { Spinner } from "../Spinner/Spinner";
import { SwitchRow } from "../SwitchRow/SwitchRow";
import { Tag } from "../Tag/Tag";
import { TextField } from "../TextField/TextField";
import { usePlatform, type Platform } from "../../platform";
import { noop, ScreenFrame, ScreenState } from "../../screen";
import "./PluginsScreen.css";

/** How a tab's content loaded. `unsupported`: the server has no such endpoint ("not available on this server"). */
export type PluginsTabState = "loaded" | "loading" | "failed" | "unsupported";

/** A memory provider the server offers. */
export interface MemoryProviderOption {
  /** "honcho", "mem0". */
  name: string;
  description?: string;
  /** `ready` can be picked; `needsSetup` and `unavailable` cannot (unless already in use) and list what they need. */
  status: "ready" | "needsSetup" | "unavailable";
  /** What it needs on the server, shown under "What it needs" when not ready. All empty: "The server did not say what it needs." */
  needs?: {
    env?: string[];
    tools?: { name: string; install?: string }[];
    python?: string[];
  };
}

/** A context engine the server offers. */
export interface ContextEngineOption {
  name: string;
  description?: string;
}

/** The Install from Git URL dialog's fields. */
export interface GitInstallState {
  /** The typed address. It can carry a token, so the app never keeps or logs it. */
  url?: string;
  /** "I trust this source": Install needs it. */
  trust?: boolean;
  /** "Enable after install". Default on. */
  enable?: boolean;
  /** The Advanced section is open, with "Overwrite existing (force)". */
  advancedOpen?: boolean;
  force?: boolean;
  /** The install is running: everything is disabled and Install spins. */
  busy?: boolean;
}

export interface PluginsScreenProps {
  /** The open tab. */
  tab?: "installed" | "catalog" | "providers";
  /** `desktop` (900px and wider): the list (400px) and the detail pane side by side. `phone`: the list alone; a plugin opens in a bottom sheet (`detailOpen`). */
  layout?: "phone" | "desktop";

  /** Installed tab: the dashboard's agent plugins. */
  plugins?: PluginDetails[];
  installedState?: PluginsTabState;
  /** Catalog tab: the curated catalog. */
  catalog?: PluginDetails[];
  catalogState?: PluginsTabState;
  /** Catalog tab: the search field's text; filters names, maintainers and descriptions. */
  query?: string;
  /** Catalog tab: names being installed (Install spins). */
  installing?: string[];
  /** The plugin open in the detail pane (desktop) or the sheet (phone, with `detailOpen`). */
  selected?: string;
  /** Phone: draw the selected plugin's detail in a bottom sheet. */
  detailOpen?: boolean;
  /** A change to the selected plugin is running. */
  busy?: boolean;
  /** Draw the "Install from Git URL" dialog (Catalog tab). */
  gitInstall?: GitInstallState;

  /** Providers tab: memory providers ("Built-in" is always first). */
  memoryProviders?: MemoryProviderOption[];
  /** The picked memory provider; "" is Built-in. */
  memoryChoice?: string;
  /** The provider in use on the server; it stays pickable even when not ready. */
  memoryInUse?: string;
  /** Providers whose "What it needs" is open. */
  needsOpen?: string[];
  contextEngines?: ContextEngineOption[];
  contextChoice?: string;
  providersState?: PluginsTabState;
  /** Something changed since the last save: Save is enabled. */
  providersDirty?: boolean;
  providersSaving?: boolean;

  onBack?: () => void;
  onTabChange?: (tab: "installed" | "catalog" | "providers") => void;
  onOpen?: (name: string) => void;
  onDismissDetail?: () => void;
  onInstall?: (name: string) => void;
  onEnabledChange?: (name: string, enabled: boolean) => void;
  onRemove?: (name: string) => void;
  /** "Hide from dashboard sidebar" in an installed plugin's detail. */
  onHiddenChange?: (name: string, hidden: boolean) => void;
  onQueryChange?: (query: string) => void;
  /** The "Git URL" button next to the search. */
  onGitInstall?: () => void;
  /** A field of the Git URL dialog changed: the whole new state. */
  onGitChange?: (next: GitInstallState) => void;
  onGitCancel?: () => void;
  onGitConfirm?: () => void;
  onChooseMemory?: (name: string) => void;
  onChooseContext?: (name: string) => void;
  onToggleNeeds?: (name: string) => void;
  onSaveProviders?: () => void;
  onRetry?: () => void;
  /**
   * `apple`: a chevron back labelled "Chat" on a phone, the iOS segmented
   * control instead of underline tabs, iOS toggles and spinners; rows swipe
   * to Remove. Inherits the provider's platform.
   */
  platform?: Platform;
}

const TABS = ["installed", "catalog", "providers"] as const;

function notLoaded(
  state: PluginsTabState,
  unsupportedTitle: string,
  failedTitle: string,
  onRetry?: () => void,
) {
  if (state === "loaded") return null;
  return (
    <ScreenState
      state={state}
      failedTitle={failedTitle}
      unsupportedTitle={unsupportedTitle}
      retryVariant="outlined"
      onRetry={onRetry}
    />
  );
}

function StatusTag({ status }: { status: MemoryProviderOption["status"] }) {
  return status === "ready" ? (
    <Tag variant="filled">Ready</Tag>
  ) : (
    <Tag>{status === "needsSetup" ? "Needs setup" : "Unavailable"}</Tag>
  );
}

function Needs({ option }: { option: MemoryProviderOption }) {
  const n = option.needs ?? {};
  const any = n.env?.length || n.tools?.length || n.python?.length;
  if (!any)
    return (
      <div className="h-body-md">The server did not say what it needs.</div>
    );
  return (
    <div className="h-plugins__needs">
      {n.env?.length ? (
        <div>
          <SectionHeader variant="label" title="Environment variables" />
          {n.env.map((e) => (
            <div key={e} className="h-mono">
              {e}
            </div>
          ))}
        </div>
      ) : null}
      {n.tools?.length ? (
        <div>
          <SectionHeader variant="label" title="Tools" />
          {n.tools.map((t) => (
            <div key={t.name}>
              <div className="h-body-md">{t.name}</div>
              {t.install ? (
                <div className="h-plugins__command">
                  <span className="h-mono">{t.install}</span>
                  <IconButton
                    icon="content_copy"
                    label="Copy command"
                    size={32}
                  />
                </div>
              ) : null}
            </div>
          ))}
        </div>
      ) : null}
      {n.python?.length ? (
        <div>
          <SectionHeader variant="label" title="Python packages" />
          {n.python.map((p) => (
            <div key={p} className="h-mono">
              {p}
            </div>
          ))}
        </div>
      ) : null}
      <div className="h-body-sm h-muted">Set this up on the server.</div>
    </div>
  );
}

/**
 * The Plugins screen: an app bar with Installed, Catalog and Providers tabs
 * (a segmented control on Apple, underline tabs on Material). Installed and
 * Catalog are `PluginRow` lists with a `PluginDetail` in a pane beside
 * them from 900px, or in a bottom `Sheet` on a phone; Catalog adds a search
 * field and the "Git URL" button that opens the unreviewed-code install
 * dialog. Providers picks the memory provider and context engine with
 * `RadioRow`s over a Save bar. Covers each tab's loading, failed and
 * not-available states. Fills its parent; give it a size.
 */
export function PluginsScreen({
  tab = "installed",
  layout = "desktop",
  plugins = [],
  installedState = "loaded",
  catalog = [],
  catalogState = "loaded",
  query = "",
  installing = [],
  selected,
  detailOpen = false,
  busy = false,
  gitInstall,
  memoryProviders = [],
  memoryChoice = "",
  memoryInUse,
  needsOpen = [],
  contextEngines = [],
  contextChoice,
  providersState = "loaded",
  providersDirty = false,
  providersSaving = false,
  onBack,
  onTabChange,
  onOpen,
  onDismissDetail,
  onInstall,
  onEnabledChange,
  onRemove,
  onHiddenChange,
  onQueryChange,
  onGitInstall,
  onGitChange,
  onGitCancel,
  onGitConfirm,
  onChooseMemory,
  onChooseContext,
  onToggleNeeds,
  onSaveProviders,
  onRetry,
  platform,
}: PluginsScreenProps) {
  const resolved = usePlatform(platform);
  const desktop = layout === "desktop";
  const device = desktop ? "mac" : "touch";
  const divider = <div className="h-plugins__divider" />;

  const q = query.trim().toLowerCase();
  const visibleCatalog = catalog.filter(
    (p) =>
      !q ||
      [p.name, p.maintainer, p.description].some((s) =>
        (s ?? "").toLowerCase().includes(q),
      ),
  );
  const items = tab === "catalog" ? catalog : plugins;
  const picked = items.find((p) => p.name === selected);
  const detail = picked ? (
    <PluginDetail
      plugin={picked}
      variant={tab === "catalog" ? "catalog" : "installed"}
      busy={busy || installing.includes(picked.name)}
      onEnabledChange={(on) => onEnabledChange?.(picked.name, on)}
      onHiddenChange={(hidden) => onHiddenChange?.(picked.name, hidden)}
      onRemove={() => onRemove?.(picked.name)}
      onInstall={() => onInstall?.(picked.name)}
    />
  ) : undefined;

  let list;
  if (tab === "installed") {
    list = notLoaded(
      installedState,
      "The plugin list is not available on this server",
      "Could not load plugins",
      onRetry,
    ) ?? (
      <div>
        {plugins.length === 0 ? (
          <div className="h-plugins__empty">No plugins installed</div>
        ) : (
          plugins.map((p, i) => (
            <div key={p.name}>
              {i > 0 ? divider : null}
              <PluginRow
                plugin={p}
                device={device}
                selected={desktop && p.name === selected}
                onClick={() => onOpen?.(p.name)}
                onEnabledChange={(on) => onEnabledChange?.(p.name, on)}
                onRemove={() => onRemove?.(p.name)}
              />
            </div>
          ))
        )}
      </div>
    );
  } else if (tab === "catalog") {
    list = (
      <div className="h-plugins__catalog">
        <div className="h-plugins__search">
          <div className="h-plugins__search-field">
            <TextField
              leadingIcon="search"
              placeholder="Search catalog"
              value={query}
              onChange={(e) => onQueryChange?.(e.target.value)}
            />
          </div>
          <Button variant="outlined" icon="link" onClick={onGitInstall}>
            Git URL
          </Button>
        </div>
        <div className="h-plugins__catalog-body">
          {notLoaded(
            catalogState,
            "The catalog is not available on this server",
            "Could not load the catalog",
            onRetry,
          ) ??
            (visibleCatalog.length === 0 ? (
              <div className="h-plugins__empty">
                {catalog.length === 0
                  ? "The catalog is empty"
                  : "No plugins match"}
              </div>
            ) : (
              visibleCatalog.map((p, i) => (
                <div key={p.name}>
                  {i > 0 ? divider : null}
                  <PluginRow
                    plugin={p}
                    variant="catalog"
                    selected={desktop && p.name === selected}
                    installing={installing.includes(p.name)}
                    onClick={() => onOpen?.(p.name)}
                    onInstall={() => onInstall?.(p.name)}
                  />
                </div>
              ))
            ))}
        </div>
      </div>
    );
  } else {
    list = notLoaded(
      providersState,
      "The provider settings are not available on this server",
      "Could not load provider settings",
      onRetry,
    ) ?? (
      <div className="h-plugins__providers">
        <div className="h-plugins__providers-list">
          <SectionHeader
            title="Memory provider"
            caption="Where the agent keeps long-term memory"
          />
          <RadioRow
            title="Built-in"
            subtitle="No external memory"
            selected={memoryChoice === ""}
            disabled={providersSaving}
            onSelect={() => onChooseMemory?.("")}
          />
          {memoryProviders.map((o) => (
            <RadioRow
              key={o.name}
              title={o.name}
              titleTrailing={<StatusTag status={o.status} />}
              subtitle={o.description}
              selected={memoryChoice === o.name}
              disabled={
                providersSaving ||
                (o.status !== "ready" && o.name !== memoryInUse)
              }
              onSelect={() => onChooseMemory?.(o.name)}
            >
              {o.status !== "ready" ? (
                <FormSection
                  collapsible
                  title="What it needs"
                  open={needsOpen.includes(o.name)}
                  onToggle={() => onToggleNeeds?.(o.name)}
                >
                  <Needs option={o} />
                </FormSection>
              ) : null}
            </RadioRow>
          ))}
          <SectionHeader
            title="Context engine"
            caption="How long conversations are compressed"
          />
          {contextEngines.length > 1 ? (
            contextEngines.map((o) => (
              <RadioRow
                key={o.name}
                title={o.name}
                subtitle={o.description}
                selected={contextChoice === o.name}
                disabled={providersSaving}
                onSelect={() => onChooseContext?.(o.name)}
              />
            ))
          ) : (
            <div className="h-plugins__single-engine h-body-md">
              {contextEngines[0] ? <div>{contextEngines[0].name}</div> : null}
              <div>No other context engines are available on this server</div>
            </div>
          )}
        </div>
        <div className="h-plugins__save-bar">
          <span className="h-body-sm h-muted">Changes apply to new chats</span>
          <Button
            disabled={!providersDirty || providersSaving}
            onClick={onSaveProviders}
          >
            {providersSaving ? (
              <Spinner size={16} color="var(--h-muted)" label="Saving" />
            ) : (
              "Save"
            )}
          </Button>
        </div>
      </div>
    );
  }

  const split = desktop && tab !== "providers";
  return (
    <ScreenFrame platform={resolved}>
      <ListDetailLayout
        layout={split ? "split" : "list"}
        title="Plugins"
        onBack={onBack ?? noop}
        backLabel="Chat"
        tabs={["Installed", "Catalog", "Providers"]}
        activeTab={TABS.indexOf(tab)}
        onTabChange={(i) => onTabChange?.(TABS[i])}
        listWidth={400}
        detailPadding={0}
        list={list}
        detail={
          detail ? <div className="h-plugins__pane">{detail}</div> : undefined
        }
        placeholder="Select a plugin"
      />
      {!desktop && detailOpen && detail ? (
        <Sheet dragHandle padding={0} onDismiss={onDismissDetail}>
          {detail}
        </Sheet>
      ) : null}
      {gitInstall ? (
        <Sheet
          presentation="dialog"
          title="Install from Git URL"
          width={480}
          onDismiss={gitInstall.busy ? undefined : onGitCancel}
          actions={
            <>
              <Button
                variant="text"
                disabled={gitInstall.busy}
                onClick={onGitCancel}
              >
                Cancel
              </Button>
              <Button
                disabled={
                  gitInstall.busy ||
                  !gitInstall.trust ||
                  !gitInstall.url?.trim()
                }
                onClick={onGitConfirm}
              >
                {gitInstall.busy ? (
                  <Spinner
                    size={16}
                    color="var(--h-muted)"
                    label="Installing"
                  />
                ) : (
                  "Install"
                )}
              </Button>
            </>
          }
        >
          <div className="h-plugins__git">
            <div className="h-plugins__git-url">
              <TextField
                label="Git URL or owner/repo"
                value={gitInstall.url ?? ""}
                readOnly={gitInstall.busy}
                onChange={(e) =>
                  onGitChange?.({ ...gitInstall, url: e.target.value })
                }
              />
            </div>
            <div className="h-plugins__unreviewed">
              <Icon name="gpp_maybe" size={20} />
              <span className="h-body-md">
                Unreviewed code. This plugin is not from the Hermes catalog. It
                runs on your server with full access.
              </span>
            </div>
            <div className="h-plugins__trust">
              <ListRow
                icon={
                  gitInstall.trust ? "check_box" : "check_box_outline_blank"
                }
                iconFilled={gitInstall.trust}
                title="I trust this source"
                grouped={false}
                disabled={gitInstall.busy}
                onClick={() =>
                  onGitChange?.({ ...gitInstall, trust: !gitInstall.trust })
                }
              />
            </div>
            <SwitchRow
              title="Enable after install"
              checked={gitInstall.enable ?? true}
              disabled={gitInstall.busy}
              onChange={(enable) => onGitChange?.({ ...gitInstall, enable })}
            />
            <FormSection
              collapsible
              title="Advanced"
              open={gitInstall.advancedOpen}
            >
              <SwitchRow
                title="Overwrite existing (force)"
                checked={Boolean(gitInstall.force)}
                disabled={gitInstall.busy}
                onChange={(force) => onGitChange?.({ ...gitInstall, force })}
              />
            </FormSection>
          </div>
        </Sheet>
      ) : null}
    </ScreenFrame>
  );
}
