import type { ReactNode } from "react";
import { BusyBar } from "../BusyBar/BusyBar";
import { Button } from "../Button/Button";
import { Chip } from "../Chip/Chip";
import { HubSkillRow, type HubSkill } from "../HubSkillRow/HubSkillRow";
import { ListRow } from "../ListRow/ListRow";
import { SectionHeader } from "../SectionHeader/SectionHeader";
import { SkillRow, type Skill } from "../SkillRow/SkillRow";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import { TextField } from "../TextField/TextField";
import { ScreenFrame, type ScreenLayout } from "../../screenFrame";
import { usePlatform, type AppleDevice, type Platform } from "../../platform";
import "./SkillsScreen.css";

/** The Installed tab's filter chips. */
export type SkillFilter = "all" | "enabled" | "hub" | "bundled" | "agent";

const filterLabels: Record<SkillFilter, string> = {
  all: "All",
  enabled: "Enabled",
  hub: "Hub",
  bundled: "Bundled",
  agent: "Agent",
};

/** Installed skills under one category heading. */
export interface SkillGroup {
  /** Category, shown upper-case: "github". */
  category: string;
  skills: Skill[];
}

/** The Discover tab: the skills hub. */
export interface SkillsHubView {
  /** `loaded` (default), `loading`, `failed` ("Could not load the hub" with Retry) or `unsupported`. */
  state?: "loaded" | "loading" | "failed" | "unsupported";
  /** The hub search field's text. With text the tab shows `results` instead of Featured and Official. */
  query?: string;
  /** The hub's sources, as filter chips after "All": `{ id: "github", label: "GitHub" }`. */
  sources?: { id: string; label: string }[];
  /** Id of the selected source chip; leave out for "All". */
  source?: string;
  featured?: HubSkill[];
  official?: HubSkill[];
  /** Search results while `query` has text. */
  results?: HubSkill[];
  /** The search is running and has nothing yet: a spinner. */
  searching?: boolean;
  /** The search failed: "Could not search the hub" with Retry. */
  searchFailed?: boolean;
  /** Number of sources that timed out on this search: a row with Retry. */
  timedOut?: number;
  /** Names of hub skills already installed: a check instead of the chevron. */
  installed?: string[];
}

export interface SkillsScreenProps {
  /** `installed` (default) or `discover`. Discover exists only with `hub`. */
  tab?: "installed" | "discover";
  /** The Installed tab: `loaded` (default), `loading`, `failed` ("Could not load skills" with Retry), `unsupported`, or `empty` ("This profile has no skills yet."). */
  state?: "loaded" | "loading" | "failed" | "unsupported" | "empty";
  /** The profile whose skills are shown, as a chip in the bar. */
  profile?: string;
  /** Other profiles to look at: the chip opens a menu of them. */
  profiles?: string[];
  /** The search field's text. */
  query?: string;
  /** The selected filter chip. Default `all`. */
  filter?: SkillFilter;
  /** The installed skills by category, already searched and filtered. Empty: "No skills match." with Clear filters. */
  groups?: SkillGroup[];
  /** Hub skills are installed: a "Check for updates" row ends the list (needs `hub`). */
  canCheckUpdates?: boolean;
  /** A skills hub is connected: the Installed and Discover tabs. */
  hub?: SkillsHubView;
  /** A hub job runs in the background: a bar under the tabs with its title and a busy bar. Pressing it reopens the job sheet. */
  job?: { title: string };
  onBack?: () => void;
  onTabChange?: (tab: "installed" | "discover") => void;
  onProfileClick?: () => void;
  onQueryChange?: (query: string) => void;
  onFilterChange?: (filter: SkillFilter) => void;
  onClearFilters?: () => void;
  onOpenSkill?: (name: string) => void;
  onSkillEnabledChange?: (name: string, enabled: boolean) => void;
  /** "New skill": the Material floating button, or the "+" in the bar under `apple`. Shown on the Installed tab once it has loaded. */
  onNewSkill?: () => void;
  onCheckUpdates?: () => void;
  onOpenJob?: () => void;
  onRetry?: () => void;
  onHubQueryChange?: (query: string) => void;
  onHubSourceChange?: (source: string | undefined) => void;
  onOpenHubSkill?: (skill: HubSkill) => void;
  onHubRetry?: () => void;
  /** `phone` or `desktop`; the lists stay in a 720px column. */
  layout?: ScreenLayout;
  /** `apple`: chevron back with "Chat", a segmented control for the tabs, "+" in the bar instead of the floating button, iOS rows and toggles. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple` + `desktop`: `mac` (default) or `touch` for a full-screen iPad. */
  device?: AppleDevice;
}

function Note({ text, action }: { text: string; action?: ReactNode }) {
  return (
    <div className="h-skills__note">
      <StateMessage title={text} action={action} />
    </div>
  );
}

/**
 * The Skills screen, pushed from the chat sidebar: the skills of a profile
 * with a search field, filter `Chip`s and `SkillRow`s under category
 * headings, and, with a hub, a Discover tab of `HubSkillRow`s (Featured,
 * Official, or search results). A background hub job shows as a `BusyBar`
 * strip under the tabs.
 */
export function SkillsScreen({
  tab = "installed",
  state = "loaded",
  profile,
  profiles = [],
  query = "",
  filter = "all",
  groups = [],
  canCheckUpdates = false,
  hub,
  job,
  onBack,
  onTabChange,
  onProfileClick,
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
  const discover = !!hub && tab === "discover";
  const canAdd = !discover && state === "loaded" && !!onNewSkill;
  // A loading, failed or unsupported tab is a note centred on the screen.
  const noteOnly = discover
    ? !!hub?.state && hub.state !== "loaded"
    : state !== "loaded";
  const installedBody = () => {
    switch (state) {
      case "loading":
        return (
          <div className="h-skills__note">
            <Spinner size={36} label="Loading skills" />
          </div>
        );
      case "unsupported":
        return <Note text="The connected Hermes does not support skills." />;
      case "failed":
        return (
          <Note
            text="Could not load skills"
            action={<Button onClick={onRetry}>Retry</Button>}
          />
        );
      case "empty":
        return <Note text="This profile has no skills yet." />;
    }
    return (
      <>
        <div className="h-skills__search">
          <TextField
            variant="search"
            leadingIcon="search"
            placeholder="Search skills"
            value={query}
            onChange={(e) => onQueryChange?.(e.target.value)}
          />
        </div>
        <div className="h-skills__chips">
          {(Object.keys(filterLabels) as SkillFilter[]).map((f) => (
            <Chip
              key={f}
              label={filterLabels[f]}
              selected={f === filter}
              onClick={() => onFilterChange?.(f)}
            />
          ))}
        </div>
        {groups.length === 0 ? (
          <Note
            text="No skills match."
            action={
              <Button variant="text" onClick={onClearFilters}>
                Clear filters
              </Button>
            }
          />
        ) : (
          <div className="h-skills__list">
            {groups.map((g) => (
              <div key={g.category}>
                <div className="h-skills__heading">
                  <SectionHeader title={g.category} variant="overline" />
                </div>
                {g.skills.map((s) => (
                  <SkillRow
                    key={s.name}
                    skill={s}
                    onClick={() => onOpenSkill?.(s.name)}
                    onEnabledChange={(v) => onSkillEnabledChange?.(s.name, v)}
                  />
                ))}
              </div>
            ))}
            {hub && canCheckUpdates ? (
              <ListRow
                grouped={false}
                icon="system_update_alt"
                title="Check for updates"
                subtitle="Updates the skills from the hub"
                disabled={!!job}
                onClick={onCheckUpdates}
              />
            ) : null}
          </div>
        )}
      </>
    );
  };
  const discoverBody = () => {
    const h = hub ?? {};
    switch (h.state) {
      case "loading":
        return (
          <div className="h-skills__note">
            <Spinner size={36} label="Loading the hub" />
          </div>
        );
      case "unsupported":
        return (
          <Note text="The connected Hermes does not support the skills hub." />
        );
      case "failed":
        return (
          <Note
            text="Could not load the hub"
            action={<Button onClick={onHubRetry}>Retry</Button>}
          />
        );
    }
    const installed = new Set(h.installed ?? []);
    const row = (s: HubSkill) => (
      <HubSkillRow
        key={s.name}
        skill={s}
        installed={installed.has(s.name)}
        onClick={() => onOpenHubSkill?.(s)}
      />
    );
    const searching = !!h.query;
    let list: ReactNode;
    if (searching && h.searchFailed) {
      list = (
        <Note
          text="Could not search the hub"
          action={<Button onClick={onHubRetry}>Retry</Button>}
        />
      );
    } else if (searching && h.searching && !(h.results ?? []).length) {
      list = (
        <div className="h-skills__note">
          <Spinner size={36} label="Searching" />
        </div>
      );
    } else if (searching) {
      const results = h.results ?? [];
      list = (
        <div className="h-skills__list">
          {results.length === 0 ? <Note text="No skills found." /> : null}
          {results.map(row)}
          {h.timedOut ? (
            <ListRow
              grouped={false}
              icon="hourglass_empty"
              title={`${h.timedOut} source${h.timedOut === 1 ? "" : "s"} timed out`}
              trailing={
                <Button variant="text" onClick={onHubRetry}>
                  Retry
                </Button>
              }
            />
          ) : null}
        </div>
      );
    } else if (!(h.featured ?? []).length && !(h.official ?? []).length) {
      list = <Note text="No skills to show." />;
    } else {
      list = (
        <div className="h-skills__list">
          {(h.featured ?? []).length ? (
            <>
              <div className="h-skills__heading">
                <SectionHeader title="Featured" variant="overline" />
              </div>
              {h.featured!.map(row)}
            </>
          ) : null}
          {(h.official ?? []).length ? (
            <>
              <div className="h-skills__heading">
                <SectionHeader title="Official" variant="overline" />
              </div>
              {h.official!.map(row)}
            </>
          ) : null}
        </div>
      );
    }
    return (
      <>
        <div className="h-skills__search">
          <TextField
            variant="search"
            leadingIcon="search"
            placeholder="Search the skills hub"
            value={h.query ?? ""}
            onChange={(e) => onHubQueryChange?.(e.target.value)}
          />
        </div>
        {(h.sources ?? []).length ? (
          <div className="h-skills__chips">
            <Chip
              label="All"
              selected={!h.source}
              onClick={() => onHubSourceChange?.(undefined)}
            />
            {h.sources!.map((s) => (
              <Chip
                key={s.id}
                label={s.label}
                selected={h.source === s.id}
                onClick={() => onHubSourceChange?.(s.id)}
              />
            ))}
          </div>
        ) : null}
        {list}
      </>
    );
  };
  return (
    <ScreenFrame
      title="Skills"
      onBack={onBack}
      backLabel="Chat"
      actions={
        profile ? (
          <span className="h-skills__profile">
            <Chip
              label={profile}
              icon={profiles.length ? "arrow_drop_down" : undefined}
              onClick={profiles.length ? onProfileClick : undefined}
            />
          </span>
        ) : undefined
      }
      tabs={hub ? ["Installed", "Discover"] : undefined}
      activeTab={discover ? 1 : 0}
      onTabChange={(i) => onTabChange?.(i === 1 ? "discover" : "installed")}
      onAdd={canAdd ? onNewSkill : undefined}
      addLabel="New skill"
      layout={layout}
      platform={resolved}
      device={device}
      maxWidth={720}
      centered={noteOnly}
      banner={
        hub && job ? (
          <div
            className="h-skills__job"
            role="button"
            tabIndex={0}
            onClick={onOpenJob}
          >
            <div className="h-body-md">{job.title}…</div>
            <BusyBar label={job.title} />
          </div>
        ) : undefined
      }
    >
      {discover ? discoverBody() : installedBody()}
    </ScreenFrame>
  );
}
