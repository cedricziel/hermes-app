import { Button } from "../Button/Button";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { Icon } from "../Icon/Icon";
import {
  ScheduleJobDetail,
  type ScheduleJobDetailProps,
} from "../ScheduleJobDetail/ScheduleJobDetail";
import {
  ScheduleJobRow,
  type ScheduleJob,
  type ScheduleJobAction,
} from "../ScheduleJobRow/ScheduleJobRow";
import {
  SettingsScaffold,
  type SettingsBarAction,
} from "../SettingsScaffold/SettingsScaffold";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import {
  cx,
  useAppleDevice,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./SchedulesScreen.css";

/** Which jobs the Schedules list shows: every job, or only the failing or the paused ones. */
export type ScheduleFilter = "all" | "failing" | "paused";

const filters: ScheduleFilter[] = ["all", "failing", "paused"];

export interface SchedulesScreenProps {
  /** `ready` lists `jobs`; `loading` a spinner (first load); `error` the failure (`error`) with "Try again". */
  state?: "ready" | "loading" | "error";
  /** The failure: on a first load in place of the list; once loaded, as a red note with Retry above the jobs. */
  error?: string;
  /**
   * `phone`: the list alone, a menu button that opens the navigation drawer
   * and a job opening as its own page (render `ScheduleJobDetail` with
   * `onBack` for that). `desktop` (900px and up; 760px in a Mac window):
   * the list column beside the selected job's detail.
   */
  layout?: "phone" | "desktop";
  /** The jobs shown, after the filter. */
  jobs?: ScheduleJob[];
  /** Id of the job open in the detail pane. */
  selectedId?: string;
  /** Desktop: the selected job's detail; without it the pane says "Select a task". */
  detail?: ScheduleJobDetailProps;
  /** The active profile: the bar's subtitle, whose menu offers "work (active)" and "All profiles". */
  activeProfile?: string;
  /** Every profile's jobs are listed: the subtitle reads "All profiles" and the rows add their profile. */
  allProfiles?: boolean;
  /** The bar's filter menu: All tasks, Failing or Paused. */
  filter?: ScheduleFilter;
  /** Jobs failing, for the menu's "Failing (2)". */
  failingCount?: number;
  /** Draws the filter menu open, for previews. */
  filterMenuOpen?: boolean;
  /** Draws the subtitle's profile menu open (iPhone, Material), for previews. */
  scopeMenuOpen?: boolean;
  /** Apple touch rows: the id of the row drawn swiped open, a static preview state. */
  swipedId?: string;
  /** Apple touch rows: the id of the row whose action sheet is open, a static preview state. */
  actionSheetId?: string;
  /**
   * The page is a `SettingsScaffold` with the jobs as one `GroupedSection`
   * of `ScheduleJobRow`s. iPhone (`apple`, touch): 44px bar, "Schedules"
   * centred over the profile with a menu chevron ("work ⌄"), filter, Refresh
   * and "+" as 44px icon buttons. Material: the 56px bar with the title at
   * the start and the same buttons; no floating button. Mac window (`apple`,
   * `layout="desktop"`, `device` `mac`): the toolbar's "Schedules" over the
   * job count, the This profile / All profiles segmented control, a
   * separator, the filter menu button, Refresh and New Schedule (⌘N); the
   * job group in a `listWidth` column beside the Mac detail. Inherits the
   * provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac`; inherited from the enclosing `AppShell`. */
  device?: AppleDevice;
  /** Mac: the job column's width, 340 from a 760px wide page (default) or 250 below. */
  listWidth?: number;
  /** A job row pressed. */
  onSelect?: (job: ScheduleJob) => void;
  /** A row's switch flipped. */
  onPausedChange?: (job: ScheduleJob, paused: boolean) => void;
  /** A row's swipe or sheet action picked. */
  onAction?: (job: ScheduleJob, action: ScheduleJobAction) => void;
  /** "+" (New Schedule) pressed: opens the blueprint gallery. */
  onNew?: () => void;
  /** Refresh, Retry or Try again pressed. */
  onRefresh?: () => void;
  /** The profile scope picked: `true` for "All profiles". */
  onAllProfilesChange?: (all: boolean) => void;
  /** A filter picked from the filter menu. */
  onFilterChange?: (filter: ScheduleFilter) => void;
  /** Phone: the menu button pressed. */
  onOpenMenu?: () => void;
}

/**
 * The Schedules destination, the server's cron jobs: a `SettingsScaffold`
 * with the profile scope, the filter menu, Refresh and "+" in the bar, the
 * jobs as one `GroupedSection` of `ScheduleJobRow`s and, on a desktop, the
 * selected job's `ScheduleJobDetail` beside them. Loading, failed and empty
 * states included. Fills its parent; put it in an `AppShell` with
 * `current="schedules"`.
 */
export function SchedulesScreen({
  state = "ready",
  error,
  layout = "phone",
  jobs = [],
  selectedId,
  detail,
  activeProfile,
  allProfiles = false,
  filter = "all",
  failingCount = 0,
  filterMenuOpen,
  scopeMenuOpen,
  swipedId,
  actionSheetId,
  platform,
  device,
  listWidth,
  onSelect,
  onPausedChange,
  onAction,
  onNew,
  onRefresh,
  onAllProfilesChange,
  onFilterChange,
  onOpenMenu,
}: SchedulesScreenProps) {
  const resolved = usePlatform(platform);
  const split = layout === "desktop";
  const appleDevice = useAppleDevice(split ? "desktop" : "phone", device);
  const mac = resolved === "apple" && split && appleDevice === "mac";
  const loaded = state === "ready";
  const list = !loaded ? (
    state === "error" ? (
      <StateMessage
        title={error ?? "Could not load the scheduled tasks"}
        action={<Button onClick={onRefresh}>Try again</Button>}
      />
    ) : (
      <div className="h-schedules-screen__center">
        <Spinner />
      </div>
    )
  ) : jobs.length === 0 ? (
    <StateMessage
      title={
        filter !== "all"
          ? "No tasks match this filter"
          : mac && !allProfiles
            ? "No schedules in this profile"
            : "No scheduled tasks"
      }
    />
  ) : (
    <GroupedListView className="h-schedules-screen__jobs">
      <GroupedSection>
        {jobs.map((job) => (
          <ScheduleJobRow
            key={job.id}
            job={job}
            selected={split && job.id === selectedId}
            showProfile={allProfiles}
            swipeRevealed={job.id === swipedId}
            actionSheetOpen={job.id === actionSheetId}
            onClick={() => onSelect?.(job)}
            onPausedChange={(paused) => onPausedChange?.(job, paused)}
            onAction={(action) => onAction?.(job, action)}
          />
        ))}
      </GroupedSection>
    </GroupedListView>
  );
  const column = (
    <div className="h-schedules-screen__list">
      {loaded && error ? (
        <div className="h-schedules-screen__note" role="status">
          <Icon name="error" size={16} color="var(--h-error)" />
          <span className="h-schedules-screen__note-text">{error}</span>
          <Button variant="text" compact onClick={onRefresh}>
            Retry
          </Button>
        </div>
      ) : null}
      {list}
    </div>
  );
  const filterAction: SettingsBarAction = {
    icon: "filter_list",
    label: "Filter",
    menuOpen: filterMenuOpen,
    menu: [
      { label: "All tasks", checked: filter === "all" },
      {
        label: failingCount > 0 ? `Failing (${failingCount})` : "Failing",
        checked: filter === "failing",
      },
      { label: "Paused", checked: filter === "paused" },
    ],
    onSelect: (i) => onFilterChange?.(filters[i]),
  };
  const actions: SettingsBarAction[] = [
    filterAction,
    { icon: "refresh", label: "Refresh", onClick: onRefresh },
    {
      icon: "add",
      label: mac ? "New Schedule" : "New scheduled task",
      shortcut: "⌘N",
      onClick: onNew,
    },
  ];
  const profileLabel =
    allProfiles || !activeProfile ? "All profiles" : activeProfile;
  return (
    <SettingsScaffold
      title="Schedules"
      platform={resolved}
      device={mac ? "mac" : "touch"}
      className={cx("h-schedules-screen", mac && "h-schedules-screen--mac")}
      subtitle={
        mac
          ? jobs.length === 1
            ? "1 job"
            : `${jobs.length} jobs`
          : profileLabel
      }
      subtitleMenu={
        !mac && activeProfile
          ? {
              label: "Profiles",
              open: scopeMenuOpen,
              items: [
                { label: `${activeProfile} (active)`, checked: !allProfiles },
                { label: "All profiles", checked: allProfiles },
              ],
              onSelect: (i) => onAllProfilesChange?.(i === 1),
            }
          : undefined
      }
      tabs={mac ? ["This profile", "All profiles"] : undefined}
      activeTab={allProfiles ? 1 : 0}
      onTabChange={(i) => onAllProfilesChange?.(i === 1)}
      onOpenMenu={split ? undefined : onOpenMenu}
      actions={actions}
    >
      {split ? (
        <div className="h-schedules-screen__split">
          <div
            className="h-schedules-screen__column"
            style={{ width: mac ? (listWidth ?? 340) : 400 }}
          >
            {column}
          </div>
          <div className="h-schedules-screen__detail">
            {detail ? (
              <ScheduleJobDetail {...detail} />
            ) : (
              <div className="h-schedules-screen__placeholder">
                Select a task
              </div>
            )}
          </div>
        </div>
      ) : (
        column
      )}
    </SettingsScaffold>
  );
}
