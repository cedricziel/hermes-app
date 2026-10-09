import type { ReactNode } from "react";
import { BusyBar } from "../BusyBar/BusyBar";
import { Button } from "../Button/Button";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { HubSkillRow, type HubSkill } from "../HubSkillRow/HubSkillRow";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import type { SettingsSearch } from "../SettingsSearchField/SettingsSearchField";
import { SkillRow, type Skill } from "../SkillRow/SkillRow";
import { StateMessage } from "../StateMessage/StateMessage";
import {
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { RowButton } from "../../rowButton";
import { noop, ScreenCenter, ScreenFrame, ScreenState } from "../../screen";
import "./SkillsScreen.css";

/** The Installed tab's filters, in the search field's filter menu. */
export type SkillFilter = "all" | "enabled" | "hub" | "bundled" | "agent";

const FILTERS: SkillFilter[] = ["all", "enabled", "hub", "bundled", "agent"];

const filterLabels: Record<SkillFilter, string> = {
  all: "All",
  enabled: "Enabled",
  hub: "Hub",
  bundled: "Bundled",
  agent: "Agent",
};

const brandedCategories: Record<string, string> = {
  devops: "DevOps",
  github: "GitHub",
  gitlab: "GitLab",
  mlops: "MLOps",
  macos: "macOS",
  ios: "iOS",
};

/** A category as a group's header: "apple" reads "Apple", "github" "GitHub". */
function categoryLabel(category: string) {
  return (
    brandedCategories[category.toLowerCase()] ??
    category.charAt(0).toUpperCase() + category.slice(1)
  );
}

/** Installed skills under one category header. */
export interface SkillGroup {
  /** Category, shown capitalised as the group's header (brand casing kept: "GitHub", "DevOps"): "github". */
  category: string;
  skills: Skill[];
}

/** The Discover tab: the skills hub. */
export interface SkillsHubView {
  /** `loaded` (default), `loading`, `failed` ("Could not load the hub" with Retry) or `unsupported`. */
  state?: "loaded" | "loading" | "failed" | "unsupported";
  /** The hub search field's text ("Search the skills hub"). With text the tab shows `results` instead of Featured and Official. */
  query?: string;
  /** The hub's sources, in the search's filter menu after "All sources": `{ id: "github", label: "GitHub" }`. */
  sources?: { id: string; label: string }[];
  /** Id of the picked source; leave out for "All sources". */
  source?: string;
  featured?: HubSkill[];
  official?: HubSkill[];
  /** Search results while `query` has text, a "Results" group. */
  results?: HubSkill[];
  /** The search is running and has nothing yet: a spinner. */
  searching?: boolean;
  /** The search failed: "Could not search the hub" with Retry. */
  searchFailed?: boolean;
  /** Number of sources that timed out on this search: a row with Retry. */
  timedOut?: number;
  /** Names of hub skills already installed: "Installed" before the chevron. */
  installed?: string[];
}

export interface SkillsScreenProps {
  /** `installed` (default) or `discover`. Discover exists only with `hub`. */
  tab?: "installed" | "discover";
  /** The Installed tab: `loaded` (default), `loading`, `failed` ("Could not load skills" with Retry), `unsupported`, or `empty` ("This profile has no skills yet."). */
  state?: "loaded" | "loading" | "failed" | "unsupported" | "empty";
  /** The profile whose skills are shown, under the title: "default". On a Mac with the count: "default · 3 skills". */
  profile?: string;
  /** Other profiles to look at: the subtitle becomes a button ("default ⌄") opening a menu of them, the current one checked. */
  profiles?: string[];
  /** Draws the profile menu open, for previews. */
  profileMenuOpen?: boolean;
  /** The search field's text ("Search skills"). */
  query?: string;
  /** The picked filter of the search's filter menu. Default `all`; any other marks the filter button. */
  filter?: SkillFilter;
  /** Draws the search's filter menu open, for previews. */
  filterMenuOpen?: boolean;
  /** The installed skills by category, already searched and filtered. Empty: "No skills match." with Clear filters. */
  groups?: SkillGroup[];
  /** Hub skills are installed: a "Check for updates" group ends the list (needs `hub`). */
  canCheckUpdates?: boolean;
  /** A skills hub is connected: the Installed and Discover tabs. */
  hub?: SkillsHubView;
  /** A hub job runs in the background: a tinted strip under the bar with its title and a busy bar. Pressing it reopens the job sheet. */
  job?: { title: string };
  onBack?: () => void;
  onTabChange?: (tab: "installed" | "discover") => void;
  /** A profile was picked from the subtitle's menu. */
  onProfileChange?: (profile: string) => void;
  onQueryChange?: (query: string) => void;
  onFilterChange?: (filter: SkillFilter) => void;
  onClearFilters?: () => void;
  onOpenSkill?: (name: string) => void;
  onSkillEnabledChange?: (name: string, enabled: boolean) => void;
  /** "New skill": the "+" in the bar, on the Installed tab once it has loaded. */
  onNewSkill?: () => void;
  onCheckUpdates?: () => void;
  onOpenJob?: () => void;
  onRetry?: () => void;
  onHubQueryChange?: (query: string) => void;
  onHubSourceChange?: (source: string | undefined) => void;
  onOpenHubSkill?: (skill: HubSkill) => void;
  onHubRetry?: () => void;
  /** `phone` or `desktop`. Under `apple`, `desktop` is a Mac window: the toolbar holds the tabs, the search with its filter button and "+". */
  layout?: "phone" | "desktop";
  /**
   * `apple`: the iOS bar ("Chat" back, the title centred over the profile,
   * "+"), segmented tabs and the iOS search field; on a Mac the toolbar.
   * `material`: the 56px bar, a pill segmented control and pill search.
   * The lists are inset `GroupedSection`s on every platform. Inherits the
   * provider's platform.
   */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

/** The group that checks the hub skills for updates: a "Hub skills" row with a bordered button on a Mac, a "Check for updates" row elsewhere (with a refresh glyph on Material). */
function UpdatesSection({
  busy,
  onCheck,
}: {
  busy: boolean;
  onCheck?: () => void;
}) {
  const chrome = useGroupedChrome();
  const onClick = busy ? undefined : (onCheck ?? noop);
  return (
    <GroupedSection
      footer="Updates the skills installed from the hub."
      dividerIndent={chrome === "material" ? "leading" : undefined}
    >
      {chrome === "mac" ? (
        <GroupedRow
          title="Hub skills"
          trailing={
            <RowButton
              label="Check for Updates"
              disabled={busy}
              onClick={onCheck}
            />
          }
        />
      ) : (
        <GroupedRow
          title="Check for updates"
          icon={chrome === "material" ? "refresh" : undefined}
          chevron={false}
          disabled={busy}
          onClick={onClick}
        />
      )}
    </GroupedSection>
  );
}

/** A message centred in the body, with an optional action. */
function Note({ text, action }: { text: string; action?: ReactNode }) {
  return (
    <ScreenCenter>
      <StateMessage title={text} action={action} />
    </ScreenCenter>
  );
}

/**
 * The Skills screen on `SettingsScaffold`, pushed from the chat sidebar:
 * the profile's skills as `SkillRow`s in one `GroupedSection` per
 * category, searched and filtered from the bar's search field, a "Check
 * for updates" group, and with a hub a Discover tab of `HubSkillRow`s
 * (Featured, Official, or search Results). The profile under the title
 * switches profiles; a background hub job shows as a `BusyBar` strip.
 */
export function SkillsScreen({
  tab = "installed",
  state = "loaded",
  profile,
  profiles = [],
  profileMenuOpen,
  query = "",
  filter = "all",
  filterMenuOpen,
  groups = [],
  canCheckUpdates = false,
  hub,
  job,
  onBack,
  onTabChange,
  onProfileChange,
  onQueryChange,
  onFilterChange,
  onClearFilters,
  onOpenSkill,
  onSkillEnabledChange,
  onNewSkill,
  onCheckUpdates,
  onOpenJob,
  onRetry,
  onHubQueryChange,
  onHubSourceChange,
  onOpenHubSkill,
  onHubRetry,
  layout = "phone",
  platform,
  device,
}: SkillsScreenProps) {
  const resolved = usePlatform(platform);
  const mac =
    resolved === "apple" && layout === "desktop" && device !== "touch";
  const discover = !!hub && tab === "discover";
  const ready = state === "loaded";
  const skillCount = groups.reduce((n, g) => n + g.skills.length, 0);
  const menuProfiles = profile
    ? [profile, ...profiles.filter((p) => p !== profile)]
    : [];

  const skillsSearch: SettingsSearch = {
    query,
    onChange: onQueryChange,
    hint: "Search skills",
    filters: FILTERS.map((f) => ({
      label: filterLabels[f],
      selected: f === filter,
    })),
    onFilter: (i) => onFilterChange?.(FILTERS[i]),
    filterMenuOpen,
  };
  const hubSources = hub?.sources ?? [];
  const hubSearch: SettingsSearch | undefined =
    hub && (hub.state ?? "loaded") === "loaded"
      ? {
          query: hub.query,
          onChange: onHubQueryChange,
          hint: "Search the skills hub",
          filters: hubSources.length
            ? [
                { label: "All sources", selected: !hub.source },
                ...hubSources.map((s) => ({
                  label: s.label,
                  selected: hub.source === s.id,
                })),
              ]
            : undefined,
          onFilter: (i) =>
            onHubSourceChange?.(i === 0 ? undefined : hubSources[i - 1].id),
          filterMenuOpen,
        }
      : undefined;

  const installedBody = () => {
    if (state === "loading" || state === "failed" || state === "unsupported") {
      return (
        <ScreenState
          state={state}
          failedTitle="Could not load skills"
          unsupportedTitle="The connected Hermes does not support skills."
          onRetry={onRetry}
        />
      );
    }
    if (state === "empty")
      return <Note text="This profile has no skills yet." />;
    if (groups.length === 0) {
      return (
        <Note
          text="No skills match."
          action={
            <Button variant="text" onClick={onClearFilters}>
              Clear filters
            </Button>
          }
        />
      );
    }
    return (
      <GroupedListView>
        {groups.map((g) => (
          <GroupedSection key={g.category} header={categoryLabel(g.category)}>
            {g.skills.map((s) => (
              <SkillRow
                key={s.name}
                skill={s}
                onClick={() => onOpenSkill?.(s.name)}
                onEnabledChange={(v) => onSkillEnabledChange?.(s.name, v)}
              />
            ))}
          </GroupedSection>
        ))}
        {hub && canCheckUpdates ? (
          <UpdatesSection busy={!!job} onCheck={onCheckUpdates} />
        ) : null}
      </GroupedListView>
    );
  };

  const discoverBody = (h: SkillsHubView) => {
    const hubState = h.state ?? "loaded";
    if (hubState !== "loaded") {
      return (
        <ScreenState
          state={hubState}
          failedTitle="Could not load the hub"
          unsupportedTitle="The connected Hermes does not support the skills hub."
          onRetry={onHubRetry}
        />
      );
    }
    const installed = new Set(h.installed ?? []);
    const section = (header: string, skills: HubSkill[]) => (
      <GroupedSection key={header} header={header}>
        {skills.map((s) => (
          <HubSkillRow
            key={s.name}
            skill={s}
            installed={installed.has(s.name)}
            onClick={() => onOpenHubSkill?.(s)}
          />
        ))}
      </GroupedSection>
    );
    if (h.query) {
      const results = h.results ?? [];
      if (h.searchFailed) {
        return (
          <ScreenState
            state="failed"
            failedTitle="Could not search the hub"
            onRetry={onHubRetry}
          />
        );
      }
      if (h.searching && !results.length) {
        return <ScreenState state="loading" failedTitle="" />;
      }
      if (!results.length && !h.timedOut) {
        return <Note text="No skills found." />;
      }
      return (
        <GroupedListView>
          {results.length ? section("Results", results) : null}
          {h.timedOut ? (
            <GroupedSection>
              <GroupedRow
                icon="hourglass_empty"
                title={`${h.timedOut} source${h.timedOut === 1 ? "" : "s"} timed out`}
                trailing={
                  <Button variant="text" compact onClick={onHubRetry}>
                    Retry
                  </Button>
                }
              />
            </GroupedSection>
          ) : null}
        </GroupedListView>
      );
    }
    const featured = h.featured ?? [];
    const official = h.official ?? [];
    if (!featured.length && !official.length) {
      return <Note text="No skills to show." />;
    }
    return (
      <GroupedListView>
        {featured.length ? section("Featured", featured) : null}
        {official.length ? section("Official", official) : null}
      </GroupedListView>
    );
  };

  return (
    <ScreenFrame platform={resolved}>
      <SettingsScaffold
        device={mac ? "mac" : "touch"}
        title="Skills"
        subtitle={
          profile && mac && ready
            ? `${profile} · ${skillCount} skill${skillCount === 1 ? "" : "s"}`
            : profile
        }
        subtitleMenu={
          profile && profiles.length
            ? {
                label: "Profile",
                items: menuProfiles.map((p) => ({
                  label: p,
                  checked: p === profile,
                })),
                onSelect: (i) => onProfileChange?.(menuProfiles[i]),
                open: profileMenuOpen,
              }
            : undefined
        }
        onBack={onBack ?? noop}
        actions={
          !discover && ready && onNewSkill
            ? [
                {
                  icon: "add",
                  label: "New skill",
                  onClick: onNewSkill,
                },
              ]
            : []
        }
        tabs={hub ? ["Installed", "Discover"] : undefined}
        activeTab={discover ? 1 : 0}
        onTabChange={(i) => onTabChange?.(i === 1 ? "discover" : "installed")}
        search={discover ? hubSearch : ready ? skillsSearch : undefined}
      >
        {hub && job ? (
          <div
            className="h-skills__job"
            role="button"
            tabIndex={0}
            onClick={onOpenJob}
            onKeyDown={(e) => {
              if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                onOpenJob?.();
              }
            }}
          >
            <div className="h-skills__job-title">{job.title}…</div>
            <BusyBar label={job.title} />
          </div>
        ) : null}
        {discover ? discoverBody(hub) : installedBody()}
      </SettingsScaffold>
    </ScreenFrame>
  );
}
