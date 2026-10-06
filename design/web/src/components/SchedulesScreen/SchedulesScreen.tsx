import { Button } from "../Button/Button";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { ListDetailLayout } from "../ListDetailLayout/ListDetailLayout";
import {
  ScheduleFilterBar,
  type ScheduleFilter,
} from "../ScheduleFilterBar/ScheduleFilterBar";
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
  MacToolbar,
  MacToolbarButton,
  MacToolbarSeparator,
} from "../MacToolbar/MacToolbar";
import { SegmentedControl } from "../SegmentedControl/SegmentedControl";
import { Spinner } from "../Spinner/Spinner";
import { StateMessage } from "../StateMessage/StateMessage";
import {
  cx,
  PlatformScope,
  usePlatform,
  useAppleDevice,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./SchedulesScreen.css";

export interface SchedulesScreenProps {
  /** `ready` lists `jobs`; `loading` a spinner (first load); `error` the failure (`error`) with "Try again". */
  state?: "ready" | "loading" | "error";
  /** The failure: on a first load in place of the list; once loaded, as a red note with Retry above the jobs. */
  error?: string;
  /**
   * `phone`: the list alone, a menu button that opens the navigation drawer
   * and a job opening as its own screen (render `ScheduleJobDetail` for
   * that). `desktop` (900px and up): the 400px list beside the selected
   * job's detail.
   */
  layout?: "phone" | "desktop";
  /** The jobs shown, after the filters. */
  jobs?: ScheduleJob[];
  /** Id of the job open in the detail pane. */
  selectedId?: string;
  /** Desktop: the selected job's detail; without it the pane says "Select a task". */
  detail?: ScheduleJobDetailProps;
  /** The active profile, for the "work (active)" chip. */
  activeProfile?: string;
  /** Every profile's jobs are listed (rows show their profile). */
  allProfiles?: boolean;
  /** Failing or Paused filter in effect. */
  filter?: ScheduleFilter;
  /** Jobs failing, for "Failing (2)". */
  failingCount?: number;
  /** Apple touch rows: the id of the row drawn swiped open, a static preview state. */
  swipedId?: string;
  /** Apple touch rows: the id of the row whose action sheet is open, a static preview state. */
  actionSheetId?: string;
  /**
   * `apple`: the jobs as one inset grouped list, Apple switches, a "+" in
   * the bar instead of the "New" floating button, swipes and long-press
   * sheets on touch rows. In a Mac window (`apple`, `layout="desktop"`,
   * `device` `mac`) the page follows the Mac app: a `MacToolbar`
   * ("Schedules" over the job count, the This profile / All profiles
   * control, Refresh and New Schedule) instead of the app bar and the
   * profile chips, the jobs as separate cards in a `listWidth` column and
   * the detail in its Mac form. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac` for the rows; inherited from the enclosing `AppShell`. */
  device?: AppleDevice;
  /** Mac: the job column's width, 340 from a 760px wide page (default) or 250 below. */
  listWidth?: number;
  /** A job row pressed. */
  onSelect?: (job: ScheduleJob) => void;
  /** A row's switch flipped. */
  onPausedChange?: (job: ScheduleJob, paused: boolean) => void;
  /** A row's swipe or sheet action picked. */
  onAction?: (job: ScheduleJob, action: ScheduleJobAction) => void;
  /** "New" (or "+") pressed: opens the blueprint gallery. */
  onNew?: () => void;
  /** Refresh, Retry or Try again pressed. */
  onRefresh?: () => void;
  /** A profile chip pressed. */
  onAllProfilesChange?: (all: boolean) => void;
  /** Failing or Paused toggled. */
  onFilterChange?: (filter: ScheduleFilter) => void;
  /** Phone: the menu button pressed. */
  onOpenMenu?: () => void;
}

/**
 * The Schedules destination, the server's cron jobs: `ListDetailLayout`
 * with Refresh and New in the bar, `ScheduleFilterBar` over the
 * `ScheduleJobRow`s (Material cards, or one inset grouped list under
 * `platform="apple"`), and on a desktop the selected job's
 * `ScheduleJobDetail` beside them. Loading, failed and empty states
 * included. Fills its parent; put it in an `AppShell` with
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
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const split = layout === "desktop";
  const appleDevice = useAppleDevice("desktop", device);
  const mac = apple && split && appleDevice === "mac";
  const loaded = state === "ready";
  const body = !loaded ? (
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
    <div
      className={cx(
        "h-schedules-screen__jobs",
        apple && !mac && "h-schedules-screen__jobs--grouped",
        mac && "h-schedules-screen__jobs--mac",
      )}
    >
      {jobs.map((job) => (
        <ScheduleJobRow
          key={job.id}
          job={job}
          selected={split && job.id === selectedId}
          showProfile={allProfiles}
          device={mac ? "mac" : device}
          swipeRevealed={job.id === swipedId}
          actionSheetOpen={job.id === actionSheetId}
          onClick={() => onSelect?.(job)}
          onPausedChange={(paused) => onPausedChange?.(job, paused)}
          onAction={(action) => onAction?.(job, action)}
        />
      ))}
    </div>
  );
  const note =
    loaded && error ? (
      <div className="h-schedules-screen__note" role="status">
        <Icon name="error" size={16} color="var(--h-error)" />
        <span className="h-schedules-screen__note-text">{error}</span>
        <Button variant="text" compact onClick={onRefresh}>
          Retry
        </Button>
      </div>
    ) : null;
  const filters = (
    <ScheduleFilterBar
      activeProfile={activeProfile}
      allProfiles={allProfiles}
      filter={filter}
      failingCount={failingCount}
      showScope={!mac}
      onAllProfilesChange={onAllProfilesChange}
      onFilterChange={onFilterChange}
    />
  );
  if (mac) {
    return (
      <PlatformScope platform={resolvedPlatform}>
        <div className="h-schedules-screen h-schedules-screen--mac">
          <MacToolbar
            title="Schedules"
            subtitle={jobs.length === 1 ? "1 job" : `${jobs.length} jobs`}
            border
            actions={
              <>
                <div className="h-schedules-screen__scope">
                  <SegmentedControl
                    labels={["This profile", "All profiles"]}
                    value={allProfiles ? 1 : 0}
                    label="Profile scope"
                    onChange={(i) => onAllProfilesChange?.(i === 1)}
                  />
                </div>
                <MacToolbarSeparator />
                <MacToolbarButton
                  icon="refresh"
                  label="Refresh"
                  onClick={onRefresh}
                />
                <MacToolbarButton
                  icon="add"
                  label="New Schedule"
                  shortcut="⌘N"
                  onClick={onNew}
                />
              </>
            }
          />
          <div className="h-schedules-screen__mac-body">
            <div
              className="h-schedules-screen__mac-list"
              style={{ width: listWidth ?? 340 }}
            >
              <div className="h-schedules-screen__list">
                {filters}
                {note}
                {body}
              </div>
            </div>
            <div className="h-schedules-screen__mac-detail">
              {detail ? (
                <ScheduleJobDetail variant="mac" device="mac" {...detail} />
              ) : (
                <div className="h-schedules-screen__placeholder">
                  Select a task
                </div>
              )}
            </div>
          </div>
        </div>
      </PlatformScope>
    );
  }
  return (
    <PlatformScope platform={resolvedPlatform}>
      <ListDetailLayout
        layout={split ? "split" : "list"}
        title="Schedules"
        onOpenMenu={split ? undefined : onOpenMenu}
        actions={
          <IconButton icon="refresh" label="Refresh" onClick={onRefresh} />
        }
        onAdd={onNew ?? (() => {})}
        addLabel="New"
        listWidth={400}
        detailPadding={0}
        placeholder="Select a task"
        detail={detail ? <ScheduleJobDetail {...detail} /> : undefined}
        list={
          <div className="h-schedules-screen__list">
            {filters}
            {note}
            {body}
          </div>
        }
      />
    </PlatformScope>
  );
}
