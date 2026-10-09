import type { ReactNode } from "react";
import { Button } from "../Button/Button";
import { FormSection } from "../FormSection/FormSection";
import { GroupedChoiceRow } from "../GroupedChoiceRow/GroupedChoiceRow";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { ListRow } from "../ListRow/ListRow";
import { PluginDetail, type PluginDetails } from "../PluginDetail/PluginDetail";
import { PluginRow } from "../PluginRow/PluginRow";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { SettingsSearchField } from "../SettingsSearchField/SettingsSearchField";
import { Sheet } from "../Sheet/Sheet";
import { Spinner } from "../Spinner/Spinner";
import { SwitchRow } from "../SwitchRow/SwitchRow";
import { TextField } from "../TextField/TextField";
import {
  cx,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { noop, ScreenCenter, ScreenFrame, ScreenState } from "../../screen";
import "./PluginsScreen.css";

/** How a tab's content loaded. `unsupported`: the server has no such endpoint ("not available on this server"). */
export type PluginsTabState = "loaded" | "loading" | "failed" | "unsupported";

/** A memory provider the server offers. */
export interface MemoryProviderOption {
  /** "honcho", "mem0". */
  name: string;
  description?: string;
  /** `ready` can be picked ("Ready" muted after the name); `needsSetup` and `unavailable` cannot (unless already in use): a warning line says why, and a "What it needs" row follows. */
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
  /** `desktop` (900px and wider): the list (400px) and the detail pane side by side, "Select a plugin" until one is picked; under `apple` a Mac window. `phone`: the list alone; a plugin opens in a bottom sheet (`detailOpen`). */
  layout?: "phone" | "desktop";
  /** The profile the screen shows, under the title: "work". On a Mac with the counts of the loaded list: "work · 4 installed · 2 on". */
  profile?: string;

  /** Installed tab: the dashboard's agent plugins. */
  plugins?: PluginDetails[];
  installedState?: PluginsTabState;
  /** Catalog tab: the curated catalog. */
  catalog?: PluginDetails[];
  catalogState?: PluginsTabState;
  /** Catalog tab: the search field's text ("Search catalog"; in the Mac toolbar); filters names, maintainers and descriptions. */
  query?: string;
  /** Catalog tab: names being installed (Install spins). */
  installing?: string[];
  /** The plugin open in the detail pane (desktop) or the sheet (phone, with `detailOpen`). */
  selected?: string;
  /** Phone: draw the selected plugin's detail in a bottom sheet. */
  detailOpen?: boolean;
  /** A change to the selected plugin is running. */
  busy?: boolean;
  /** Draw the "Install from Git URL" dialog, which the bar's "+" opens. */
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
  /** The Update row in an installed plugin's detail. */
  onUpdate?: (name: string) => void;
  /** The copy button beside the login command. */
  onCopyLogin?: (name: string) => void;
  /** The Documentation row in a catalog entry's detail. */
  onOpenDocs?: (name: string) => void;
  /** Catalog detail: "Enable after install". Default on. */
  enableAfterInstall?: boolean;
  onEnableAfterInstallChange?: (enable: boolean) => void;
  onQueryChange?: (query: string) => void;
  /** The bar's "+" ("Install from Git"), on every tab. */
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
   * `apple`: the iOS bar (chevron back labelled "Chat", the title centred
   * over the profile, "+") and segmented control on a phone; the Mac
   * toolbar (tabs, the catalog search, "+") on `desktop`; chevrons on the
   * rows, blue checks on the picked providers, swipe to Remove on touch.
   * `material`: the 56px bar, a pill segmented control and leading radio
   * buttons. Every list is an inset `GroupedSection`. Inherits the
   * provider's platform.
   */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

const TABS = ["installed", "catalog", "providers"] as const;

const statusLabels = {
  ready: "Ready",
  needsSetup: "Needs setup",
  unavailable: "Unavailable",
};

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

function Needs({ option }: { option: MemoryProviderOption }) {
  const n = option.needs ?? {};
  if (!n.env?.length && !n.tools?.length && !n.python?.length) {
    return <div>The server did not say what it needs.</div>;
  }
  const names = (title: string, list?: string[]) =>
    list?.length ? (
      <div>
        <div className="h-plugins__needs-label">{title}</div>
        {list.map((e) => (
          <div key={e} className="h-plugins__mono">
            {e}
          </div>
        ))}
      </div>
    ) : null;
  return (
    <>
      {names("Environment variables", n.env)}
      {n.tools?.length ? (
        <div>
          <div className="h-plugins__needs-label">Tools</div>
          {n.tools.map((t) => (
            <div key={t.name}>
              <div>{t.name}</div>
              {t.install ? (
                <div className="h-plugins__command">
                  <span className="h-plugins__mono">{t.install}</span>
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
      {names("Python packages", n.python)}
      <div className="h-plugins__needs-note">Set this up on the server.</div>
    </>
  );
}

/** "What it needs" under a provider that is not ready: a disclosure inside the memory group, as the app's padded `DisclosureTile`. */
function NeedsDisclosure({
  option,
  open,
  onToggle,
}: {
  option: MemoryProviderOption;
  open: boolean;
  onToggle?: () => void;
}) {
  return (
    <div className="h-plugins__disclosure">
      <button
        type="button"
        className="h-plugins__disclosure-button"
        aria-expanded={open}
        aria-label={`What ${option.name} needs`}
        onClick={onToggle}
      >
        <span>What it needs</span>
        <Icon name={open ? "expand_less" : "expand_more"} size={20} />
      </button>
      {open ? (
        <div className="h-plugins__needs">
          <Needs option={option} />
        </div>
      ) : null}
    </div>
  );
}

/**
 * The Plugins screen on `SettingsScaffold`: Installed, Catalog and
 * Providers tabs and a "+" that installs from a Git URL. Installed and
 * Catalog are `PluginRow`s in one `GroupedSection`, with a `PluginDetail`
 * in a pane beside them from 900px or in a bottom `Sheet` on a phone;
 * Catalog searches ("Search catalog", in the Mac toolbar). Providers picks
 * the memory provider and context engine with `GroupedChoiceRow`s over a
 * Save bar. Covers each tab's loading, failed and not-available states.
 * Fills its parent; give it a size.
 */
export function PluginsScreen({
  tab = "installed",
  layout = "desktop",
  profile,
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
  onUpdate,
  onCopyLogin,
  onOpenDocs,
  enableAfterInstall = true,
  onEnableAfterInstallChange = noop,
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
  device,
}: PluginsScreenProps) {
  const resolved = usePlatform(platform);
  const desktop = layout === "desktop";
  const mac = desktop && resolved === "apple" && device !== "touch";

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
      onUpdate={() => onUpdate?.(picked.name)}
      onCopyLogin={() => onCopyLogin?.(picked.name)}
      onOpenDocs={() => onOpenDocs?.(picked.name)}
      enableAfterInstall={enableAfterInstall}
      onEnableAfterInstallChange={onEnableAfterInstallChange}
      onRemove={() => onRemove?.(picked.name)}
      onInstall={() => onInstall?.(picked.name)}
    />
  ) : undefined;

  const empty = (text: string) => (
    <GroupedListView>
      <div className="h-plugins__empty">{text}</div>
    </GroupedListView>
  );

  let list: ReactNode;
  if (tab === "installed") {
    list =
      notLoaded(
        installedState,
        "The plugin list is not available on this server",
        "Could not load plugins",
        onRetry,
      ) ??
      (plugins.length === 0 ? (
        empty("No plugins installed")
      ) : (
        <GroupedListView>
          <GroupedSection>
            {plugins.map((p) => (
              <PluginRow
                key={p.name}
                plugin={p}
                selected={desktop && p.name === selected}
                onClick={() => onOpen?.(p.name)}
                onEnabledChange={(on) => onEnabledChange?.(p.name, on)}
                onRemove={() => onRemove?.(p.name)}
              />
            ))}
          </GroupedSection>
        </GroupedListView>
      ));
  } else if (tab === "catalog") {
    list = (
      <div className="h-plugins__column">
        {mac ? null : (
          <div className="h-plugins__search">
            <SettingsSearchField
              hint="Search catalog"
              query={query}
              onChange={onQueryChange}
            />
          </div>
        )}
        {notLoaded(
          catalogState,
          "The catalog is not available on this server",
          "Could not load the catalog",
          onRetry,
        ) ??
          (visibleCatalog.length === 0 ? (
            empty(
              catalog.length === 0
                ? "The catalog is empty"
                : "No plugins match",
            )
          ) : (
            <GroupedListView>
              <GroupedSection>
                {visibleCatalog.map((p) => (
                  <PluginRow
                    key={p.name}
                    plugin={p}
                    variant="catalog"
                    selected={desktop && p.name === selected}
                    installing={installing.includes(p.name)}
                    onClick={() => onOpen?.(p.name)}
                    onInstall={() => onInstall?.(p.name)}
                  />
                ))}
              </GroupedSection>
            </GroupedListView>
          ))}
      </div>
    );
  } else {
    const singleEngine = contextEngines.length <= 1;
    list = notLoaded(
      providersState,
      "The provider settings are not available on this server",
      "Could not load provider settings",
      onRetry,
    ) ?? (
      <div className="h-plugins__column">
        <GroupedListView>
          <GroupedSection
            header="Memory provider"
            footer="Where the agent keeps long-term memory."
            dividerIndent="choice"
          >
            <GroupedChoiceRow
              title="Built-in"
              subtitle="No external memory"
              checked={memoryChoice === ""}
              disabled={providersSaving}
              onSelect={() => onChooseMemory?.("")}
            />
            {memoryProviders.flatMap((o) => {
              const ready = o.status === "ready";
              const row = (
                <GroupedChoiceRow
                  key={o.name}
                  title={o.name}
                  meta={ready ? "Ready" : undefined}
                  warning={ready ? undefined : statusLabels[o.status]}
                  subtitle={o.description}
                  checked={memoryChoice === o.name}
                  disabled={
                    providersSaving || (!ready && o.name !== memoryInUse)
                  }
                  onSelect={() => onChooseMemory?.(o.name)}
                />
              );
              return ready
                ? [row]
                : [
                    row,
                    <NeedsDisclosure
                      key={`${o.name}-needs`}
                      option={o}
                      open={needsOpen.includes(o.name)}
                      onToggle={() => onToggleNeeds?.(o.name)}
                    />,
                  ];
            })}
          </GroupedSection>
          <GroupedSection
            header="Context engine"
            footer="How long conversations are compressed."
            dividerIndent={singleEngine ? undefined : "choice"}
          >
            {singleEngine ? (
              <GroupedRow
                title={contextEngines[0]?.name ?? "None"}
                subtitle="No other context engines are available on this server"
              />
            ) : (
              contextEngines.map((o) => (
                <GroupedChoiceRow
                  key={o.name}
                  title={o.name}
                  subtitle={o.description}
                  checked={contextChoice === o.name}
                  disabled={providersSaving}
                  onSelect={() => onChooseContext?.(o.name)}
                />
              ))
            )}
          </GroupedSection>
        </GroupedListView>
        <div className="h-plugins__save-bar">
          <span>Changes apply to new chats</span>
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

  const loadedCount = installedState === "loaded";
  const subtitle =
    [
      profile,
      ...(mac && loadedCount
        ? [
            `${plugins.length} installed`,
            `${plugins.filter((p) => (p.status ?? "enabled") === "enabled").length} on`,
          ]
        : []),
    ]
      .filter(Boolean)
      .join(" · ") || undefined;

  const split = desktop && tab !== "providers";
  return (
    <ScreenFrame platform={resolved}>
      <SettingsScaffold
        device={mac ? "mac" : "touch"}
        title="Plugins"
        subtitle={subtitle}
        onBack={onBack ?? noop}
        tabs={["Installed", "Catalog", "Providers"]}
        activeTab={TABS.indexOf(tab)}
        onTabChange={(i) => onTabChange?.(TABS[i])}
        search={
          mac && tab === "catalog"
            ? { hint: "Search catalog", query, onChange: onQueryChange }
            : undefined
        }
        actions={[
          { icon: "add", label: "Install from Git", onClick: onGitInstall },
        ]}
      >
        {split ? (
          <div className="h-plugins__split">
            <div className="h-plugins__list">{list}</div>
            <div
              className={cx(
                "h-plugins__pane",
                !detail && "h-plugins__pane--empty",
              )}
            >
              {detail ?? <ScreenCenter>Select a plugin</ScreenCenter>}
            </div>
          </div>
        ) : (
          list
        )}
      </SettingsScaffold>
      {!desktop && detailOpen && detail ? (
        <Sheet
          dragHandle
          padding={0}
          label="Plugin details"
          onDismiss={onDismissDetail}
        >
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
