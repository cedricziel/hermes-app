import { type ReactNode } from "react";
import { Button } from "../Button/Button";
import { GroupedListView } from "../GroupedListView/GroupedListView";
import { GroupedRow } from "../GroupedRow/GroupedRow";
import { GroupedSection } from "../GroupedSection/GroupedSection";
import { GroupedSwitchRow } from "../GroupedSwitchRow/GroupedSwitchRow";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { Menu, MenuAnchor, useMenuState } from "../Menu/Menu";
import {
  scheduleJobAlert,
  scheduleJobStatusText,
  type ScheduleJob,
} from "../ScheduleJobRow/ScheduleJobRow";
import { SettingsScaffold } from "../SettingsScaffold/SettingsScaffold";
import { Spinner } from "../Spinner/Spinner";
import {
  cx,
  DeviceScope,
  PlatformScope,
  useGroupedChrome,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import { groupedMetrics } from "../../grouped";
import "./ScheduleJobDetail.css";

/** A job as its detail shows it: the list row's job plus what only the detail has. */
export interface ScheduleJobDetailItem extends ScheduleJob {
  /** What Hermes does each run, shown in full in the "Task" group. */
  prompt?: string;
  /** A cron job's expression, a "Cron" row in monospace under "Repeats": `0 8 * * 1-5`. */
  cronExpression?: string;
  /** The job's settings as label and value, in order: Skills, Model, Provider, Script, Working directory, Takes context from. Deliver to and Profile are added from the job. */
  settings?: { label: string; value: string }[];
  /** The last delivery's error: the warning line of the status row ("Delivery failed: …" when the run itself failed too). */
  deliveryError?: string;
  /** Hermes blocked the job before it could run, so it has no runs: the empty history explains that. */
  blocked?: boolean;
}

/** A run of a job in its history. */
export interface ScheduleRunItem {
  /** Stable id. */
  id: string;
  /** When it started, formatted: "Oct 9, 2026 3:22 AM". */
  started: string;
  /** How it went, in a word or its length: "Running", "Unfinished", "42 s", "1 min". */
  outcome: string;
  /** Still running: a spinner in place of the icon. */
  active?: boolean;
  /** The latest run of a failing job: a red error icon and "Failed · 1 min". */
  failed?: boolean;
  /** It never finished (no duration): an amber warning icon. Defaults to `outcome === "Unfinished"`. */
  unfinished?: boolean;
}

export interface ScheduleJobDetailProps {
  /** The job. */
  job: ScheduleJobDetailItem;
  /** Its runs, newest first. */
  runs?: ScheduleRunItem[];
  /** `ready` lists `runs`; `loading` a spinner; `error` "Could not load the runs" with Retry. */
  runsState?: "ready" | "loading" | "error";
  /** More runs can be loaded: a "Show more" row closes the history. */
  canShowMore?: boolean;
  /** The job's alerts are muted; omit where notifications can't be muted (no Mute switch or menu entry). */
  muted?: boolean;
  /**
   * The detail as grouped sections, after the app's `ScheduleDetailView`:
   * the status row (status, next run, the failure on the error line), a
   * "Mute notifications" switch row, Run now / Pause / Edit rows with
   * leading icons, then "Schedule" (Repeats, Cron), "Task" (the prompt),
   * "Settings" (the job's settings, Deliver to, Profile), "Run history"
   * (each run with a success, failure or warning icon, the start time and
   * its outcome as the value) and a red "Delete task" row. On a Mac
   * (`apple` + `mac`) the pane leads with the title over "schedule · next
   * run" beside "…" (Pause, Mute Notifications, Delete…), Edit and Run now
   * instead of those rows, and the history is "Recent runs". Inherits the
   * provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac`. Inherited from the enclosing `SettingsScaffold`, `GroupedListView` or `AppShell`. */
  device?: AppleDevice;
  /** A pushed page on a phone: wraps the detail in a `SettingsScaffold` titled with the job, with a back button to "Schedules". Without it the detail is a pane and, off a Mac, names the job in a headline above the groups. */
  onBack?: () => void;
  /** Mac: start with the "…" menu open, for previews. */
  defaultMenuOpen?: boolean;
  /** Run now pressed. */
  onRunNow?: () => void;
  /** Pause or Resume pressed. */
  onTogglePaused?: () => void;
  /** Edit pressed (opens the job form). */
  onEdit?: () => void;
  /** Delete pressed (the app confirms). */
  onDelete?: () => void;
  /** Mute flipped. */
  onMutedChange?: (muted: boolean) => void;
  /** A run pressed (opens its chat). */
  onOpenRun?: (run: ScheduleRunItem) => void;
  /** Retry pressed after the runs failed to load. */
  onRetryRuns?: () => void;
  /** Show more pressed. */
  onShowMore?: () => void;
}

/**
 * One scheduled job in full, as grouped sections: how it is doing, what can
 * be done with it, what it does and its runs. The detail pane of
 * `SchedulesScreen`, or with `onBack` the page pushed over the list on a
 * phone. Built from `GroupedListView`, `GroupedSection`, `GroupedRow` and
 * `GroupedSwitchRow`.
 */
export function ScheduleJobDetail({
  job,
  runs = [],
  runsState = "ready",
  canShowMore = false,
  muted,
  platform,
  device,
  onBack,
  defaultMenuOpen = false,
  onRunNow,
  onTogglePaused,
  onEdit,
  onDelete,
  onMutedChange,
  onOpenRun,
  onRetryRuns,
  onShowMore,
}: ScheduleJobDetailProps) {
  const resolvedPlatform = usePlatform(platform);
  const chrome = useGroupedChrome(resolvedPlatform, device);
  const mac = chrome === "mac";
  const locked = job.state === "completed";
  const paused = job.state === "paused";
  const alert = scheduleJobAlert(job);
  const next =
    job.state === "scheduled" && job.nextRun ? job.nextRun : undefined;
  const warning =
    alert && job.deliveryError
      ? alert === "undelivered"
        ? job.deliveryError
        : `Delivery failed: ${job.deliveryError}`
      : undefined;
  const fact = (label: string, value: string, mono = false) =>
    chrome === "material" ? (
      <GroupedRow
        key={label}
        title={label}
        subtitle={value}
        monospaceSubtitle={mono}
      />
    ) : mono ? (
      <GroupedRow
        key={label}
        title={label}
        trailing={<span className="h-job-detail__mono">{value}</span>}
      />
    ) : (
      <GroupedRow key={label} title={label} value={value} />
    );
  const body = (
    <GroupedListView>
      {mac ? (
        <MacHeader
          job={job}
          next={next}
          locked={locked}
          paused={paused}
          muted={muted}
          defaultMenuOpen={defaultMenuOpen}
          onRunNow={onRunNow}
          onEdit={onEdit}
          onTogglePaused={onTogglePaused}
          onMutedChange={onMutedChange}
          onDelete={onDelete}
        />
      ) : onBack ? null : (
        <h2 className="h-job-detail__title">{job.title}</h2>
      )}
      <GroupedSection>
        <GroupedRow
          title={scheduleJobStatusText(job)}
          subtitle={next ? `Next run ${next}` : undefined}
          error={alert === "failed" ? job.failureReason : undefined}
          warning={warning}
        />
        {!mac && muted !== undefined ? (
          <GroupedSwitchRow
            title="Mute notifications"
            subtitle="No alert when this task runs"
            checked={muted}
            onChange={(m) => onMutedChange?.(m)}
          />
        ) : null}
      </GroupedSection>
      {mac ? null : (
        <GroupedSection dividerIndent="leading">
          <GroupedRow
            icon="play_arrow"
            title="Run now"
            chevron={false}
            onClick={onRunNow}
          />
          {locked ? null : (
            <GroupedRow
              icon={paused ? "play_arrow" : "pause"}
              title={paused ? "Resume" : "Pause"}
              chevron={false}
              onClick={onTogglePaused}
            />
          )}
          <GroupedRow icon="edit" title="Edit" onClick={onEdit} />
        </GroupedSection>
      )}
      <GroupedSection header="Schedule">
        {fact("Repeats", job.scheduleText || "Unknown")}
        {job.cronExpression ? fact("Cron", job.cronExpression, true) : null}
      </GroupedSection>
      {job.prompt ? (
        <GroupedSection header="Task">
          <Padded className="h-job-detail__prompt">{job.prompt}</Padded>
        </GroupedSection>
      ) : null}
      <GroupedSection header="Settings">
        {(job.settings ?? []).map((s) => fact(s.label, s.value))}
        {fact("Deliver to", job.deliverTo)}
        {job.profile ? fact("Profile", job.profile) : null}
      </GroupedSection>
      <GroupedSection
        header={mac ? "Recent runs" : "Run history"}
        dividerIndent="leading"
      >
        {runsState === "loading" ? (
          <Padded className="h-job-detail__center">
            <Spinner />
          </Padded>
        ) : runsState === "error" ? (
          <Padded className="h-job-detail__retry">
            <span>Could not load the runs</span>
            <Button variant="text" compact onClick={onRetryRuns}>
              Retry
            </Button>
          </Padded>
        ) : runs.length === 0 ? (
          <Padded className="h-job-detail__empty">
            {job.blocked ? (
              <>
                <span>
                  Hermes blocked this task before it could start, so no run was
                  recorded. It tries again at the next scheduled time.
                </span>
                {job.failureReason ? (
                  <span className="h-job-detail__mono h-job-detail__muted">
                    {job.failureReason}
                  </span>
                ) : null}
              </>
            ) : (
              "No runs yet"
            )}
          </Padded>
        ) : (
          runs.map((run) => (
            <RunRow key={run.id} run={run} onClick={() => onOpenRun?.(run)} />
          ))
        )}
        {canShowMore && runsState === "ready" ? (
          <GroupedRow title="Show more" chevron={false} onClick={onShowMore} />
        ) : null}
      </GroupedSection>
      {mac ? null : (
        <GroupedSection>
          <GroupedRow
            title="Delete task"
            destructive
            chevron={false}
            onClick={onDelete}
          />
        </GroupedSection>
      )}
    </GroupedListView>
  );
  return (
    <PlatformScope platform={resolvedPlatform}>
      <DeviceScope device={device}>
        {onBack ? (
          <SettingsScaffold
            title={job.title}
            onBack={onBack}
            backLabel="Schedules"
          >
            {body}
          </SettingsScaffold>
        ) : (
          <div className="h-job-detail">{body}</div>
        )}
      </DeviceScope>
    </PlatformScope>
  );
}

function Padded({
  className,
  children,
}: {
  className?: string;
  children: ReactNode;
}) {
  return (
    <div className={cx("h-job-detail__padded", className)}>{children}</div>
  );
}

function RunRow({
  run,
  onClick,
}: {
  run: ScheduleRunItem;
  onClick: () => void;
}) {
  const unfinished = run.unfinished ?? run.outcome === "Unfinished";
  const size = groupedMetrics[useGroupedChrome()].titleSize + 5;
  const icon = run.active ? (
    <Spinner size={size - 4} />
  ) : run.failed ? (
    <Icon name="error_outline" size={size} color="var(--h-error)" />
  ) : unfinished ? (
    <Icon name="warning" size={size} color="var(--h-warning)" />
  ) : (
    <Icon name="check_circle" size={size} color="var(--h-success)" />
  );
  return (
    <GroupedRow
      leading={
        <span className="h-job-detail__run-icon" style={{ width: size }}>
          {icon}
        </span>
      }
      title={run.started}
      value={
        run.failed
          ? unfinished
            ? "Failed"
            : `Failed · ${run.outcome}`
          : run.outcome
      }
      onClick={onClick}
    />
  );
}

function MacHeader({
  job,
  next,
  locked,
  paused,
  muted,
  defaultMenuOpen,
  onRunNow,
  onEdit,
  onTogglePaused,
  onMutedChange,
  onDelete,
}: {
  job: ScheduleJobDetailItem;
  next?: string;
  locked: boolean;
  paused: boolean;
  muted?: boolean;
  defaultMenuOpen: boolean;
  onRunNow?: () => void;
  onEdit?: () => void;
  onTogglePaused?: () => void;
  onMutedChange?: (muted: boolean) => void;
  onDelete?: () => void;
}) {
  const [open, setOpen] = useMenuState(defaultMenuOpen);
  const subtitle = [job.scheduleText, next ? `next run ${next}` : undefined]
    .filter(Boolean)
    .join(" · ");
  return (
    <div className="h-job-detail__mac-header">
      <div className="h-job-detail__mac-heading">
        <div className="h-job-detail__mac-title">{job.title}</div>
        {subtitle ? (
          <div className="h-job-detail__mac-subtitle">{subtitle}</div>
        ) : null}
      </div>
      <div className="h-job-detail__mac-buttons">
        <MenuAnchor>
          <IconButton
            icon="more_horiz"
            label="More"
            size={32}
            aria-haspopup="menu"
            aria-expanded={open}
            onClick={() => setOpen(!open)}
          />
          {open ? (
            <Menu
              align="end"
              label="More"
              device="mac"
              style={{ minWidth: 200 }}
              items={[
                {
                  label: paused ? "Resume" : "Pause",
                  value: "pause",
                  disabled: locked,
                },
                ...(muted !== undefined
                  ? [
                      {
                        label: "Mute Notifications",
                        value: "mute",
                        checked: muted,
                      },
                    ]
                  : []),
                "divider" as const,
                { label: "Delete…", value: "delete", destructive: true },
              ]}
              onSelect={(item) => {
                setOpen(false);
                if (item.value === "pause") onTogglePaused?.();
                else if (item.value === "mute") onMutedChange?.(!muted);
                else onDelete?.();
              }}
            />
          ) : null}
        </MenuAnchor>
        <Button variant="outlined" compact onClick={onEdit}>
          Edit
        </Button>
        <Button icon="play_arrow" compact onClick={onRunNow}>
          Run now
        </Button>
      </div>
    </div>
  );
}
