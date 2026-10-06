import { useState } from "react";
import { Badge } from "../Badge/Badge";
import { Button } from "../Button/Button";
import { FactList, type Fact } from "../FactList/FactList";
import { Icon } from "../Icon/Icon";
import { IconButton } from "../IconButton/IconButton";
import { Menu, MenuAnchor } from "../Menu/Menu";
import {
  scheduleJobStatusText,
  scheduleJobTone,
  type ScheduleJob,
} from "../ScheduleJobRow/ScheduleJobRow";
import { Spinner } from "../Spinner/Spinner";
import { SwitchRow } from "../SwitchRow/SwitchRow";
import {
  cx,
  PlatformScope,
  usePlatform,
  useRowDevice,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./ScheduleJobDetail.css";

/** A job as its detail shows it: the list row's job plus what only the detail has. */
export interface ScheduleJobDetailItem extends ScheduleJob {
  /** What Hermes does each run, shown in full. */
  prompt?: string;
  /** A cron job's expression, shown as a chip under the schedule (Mac: a "Cron" fact): `0 8 * * 1-5`. */
  cronExpression?: string;
  /** The job's settings as label and value, in order: Skills, Model, Provider, Script, Working directory, Takes context from. Deliver to and Profile are added from the job. */
  settings?: { label: string; value: string }[];
  /** The last delivery's error when the run itself went fine: "Telegram: chat not found". */
  deliveryError?: string;
  /** Hermes blocked the job before it could run, so it has no runs: the empty history explains that. */
  blocked?: boolean;
}

/** A run of a job in its history. */
export interface ScheduleRunItem {
  /** Stable id. */
  id: string;
  /** When it started, formatted: "Today 08:00", "Sep 17, 08:00". */
  started: string;
  /** How it went, in a word or its length: "Running", "Unfinished", "42 s", "3 min". */
  outcome: string;
  /** Still running: a spinner. */
  active?: boolean;
  /** Mac: the latest run of a failing job, marked with a red error icon and "Failed". */
  failed?: boolean;
}

export interface ScheduleJobDetailProps {
  /** The job. */
  job: ScheduleJobDetailItem;
  /** Its runs, newest first. */
  runs?: ScheduleRunItem[];
  /** `ready` lists `runs`; `loading` a spinner; `error` "Could not load the runs" with Retry. */
  runsState?: "ready" | "loading" | "error";
  /** More runs can be loaded: "Show more" under the history. */
  canShowMore?: boolean;
  /** The job's alerts are muted; omit where notifications can't be muted (no Mute switch or menu entry). */
  muted?: boolean;
  /**
   * `default`: the phone's pushed detail and the right pane of the split
   * layout: the title, a status card, Run now / Pause / Edit, Mute
   * notifications, then Schedule, Task, Settings, Run history and "Delete
   * task". `mac`: the Mac window's detail, at most 560px wide: a header with
   * the schedule and next run beside "…" (Pause, Mute Notifications,
   * Delete…), Edit and Run now, the last failure in a card, the settings as
   * a grid and "Recent runs" in a card. Under `platform="apple"` inside a Mac
   * `AppShell` it is `mac` by itself.
   */
  variant?: "default" | "mac";
  /** `apple`: the Apple switch and iOS type ramp; menus follow `device`. Inherits the provider's platform. */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac`; `mac` also picks the `mac` variant when `variant` is left out. */
  device?: AppleDevice;
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
 * One scheduled job in full: how it is doing, what it does, its settings
 * and its runs, with Run now, Pause, Edit and Delete. The detail pane of
 * `SchedulesScreen` (pushed over the list on a phone). Built from `Button`,
 * `SwitchRow`, `FactList`, `Badge` and `Menu`.
 */
export function ScheduleJobDetail({
  job,
  runs = [],
  runsState = "ready",
  canShowMore = false,
  muted,
  variant,
  platform,
  device,
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
  const rowDevice = useRowDevice(device);
  const mac =
    (variant ??
      (resolvedPlatform === "apple" && rowDevice === "mac"
        ? "mac"
        : "default")) === "mac";
  const locked = job.state === "completed";
  const next =
    job.state === "scheduled" && job.nextRun ? job.nextRun : undefined;
  const history =
    runsState === "loading" ? (
      <div className="h-job-detail__center">
        <Spinner />
      </div>
    ) : runsState === "error" ? (
      <div className="h-job-detail__retry">
        <span>Could not load the runs</span>
        <Button variant="text" onClick={onRetryRuns}>
          Retry
        </Button>
      </div>
    ) : runs.length === 0 ? (
      job.blocked ? (
        <div className="h-job-detail__blocked">
          <span>
            Hermes blocked this task before it could start, so no run was
            recorded. It tries again at the next scheduled time.
          </span>
          {job.failureReason ? (
            <span className="h-job-detail__mono-muted">
              {job.failureReason}
            </span>
          ) : null}
        </div>
      ) : (
        <div>No runs yet</div>
      )
    ) : null;
  const showMore = canShowMore ? (
    <div>
      <Button variant="text" onClick={onShowMore}>
        Show more
      </Button>
    </div>
  ) : null;
  const toneName = scheduleJobTone(job);

  if (mac) {
    const failing =
      job.outcome === "failed" || job.outcome === "deliveryFailed";
    const delivery = job.outcome === "deliveryFailed";
    const facts: Fact[] = [
      ...(job.profile ? [{ label: "Profile", value: job.profile }] : []),
      { label: "Deliver to", value: job.deliverTo },
      {
        label: "Status",
        value:
          job.state === "paused"
            ? "Paused"
            : job.state === "completed"
              ? "Completed"
              : "Active",
      },
      ...(job.cronExpression
        ? [{ label: "Cron", value: job.cronExpression, mono: true }]
        : []),
      ...(job.deliveryError && !delivery
        ? [{ label: "Delivery", value: `Failed: ${job.deliveryError}` }]
        : []),
      ...(job.settings ?? []),
      ...(job.prompt ? [{ label: "Prompt", value: job.prompt }] : []),
    ];
    const subtitle = [job.scheduleText, next ? `next run ${next}` : undefined]
      .filter(Boolean)
      .join(" · ");
    return (
      <PlatformScope platform={resolvedPlatform}>
        <div className="h-job-detail h-job-detail--mac">
          <div className="h-job-detail__mac-column">
            <div className="h-job-detail__mac-header">
              <div className="h-job-detail__mac-heading">
                <div className="h-job-detail__mac-title">{job.title}</div>
                {subtitle ? (
                  <div className="h-job-detail__mac-subtitle">{subtitle}</div>
                ) : null}
              </div>
              <div className="h-job-detail__mac-buttons">
                <MacMore
                  paused={job.state === "paused"}
                  locked={locked}
                  muted={muted}
                  defaultOpen={defaultMenuOpen}
                  device={device}
                  onTogglePaused={onTogglePaused}
                  onMutedChange={onMutedChange}
                  onDelete={onDelete}
                />
                <Button variant="outlined" compact onClick={onEdit}>
                  Edit
                </Button>
                <Button icon="play_arrow" compact onClick={onRunNow}>
                  Run now
                </Button>
              </div>
            </div>
            {failing ? (
              <div className="h-job-detail__card h-job-detail__mac-failure">
                <Badge tone={delivery ? "warning" : "error"}>
                  {delivery ? "Delivery failed" : "Failed"}
                </Badge>
                <span className="h-job-detail__mac-failure-text">
                  {[
                    delivery ? job.deliveryError : job.failureReason,
                    job.lastRun,
                  ]
                    .filter(Boolean)
                    .join(" · ")}
                </span>
              </div>
            ) : null}
            <FactList facts={facts} labelWidth={110} mono={false} />
            <div className="h-job-detail__section">
              <div className="h-job-detail__heading">Recent runs</div>
              {history ?? (
                <div className="h-job-detail__card h-job-detail__mac-runs">
                  {runs.map((run) => (
                    <button
                      key={run.id}
                      type="button"
                      className="h-job-detail__mac-run"
                      onClick={() => onOpenRun?.(run)}
                    >
                      {run.active ? (
                        <Spinner size={14} />
                      ) : run.failed ? (
                        <Icon name="error" size={16} color="var(--h-error)" />
                      ) : run.outcome === "Unfinished" ? (
                        <Icon
                          name="warning"
                          size={16}
                          color="var(--h-warning)"
                        />
                      ) : (
                        <Icon
                          name="check_circle"
                          size={16}
                          color="var(--h-success)"
                        />
                      )}
                      <span className="h-job-detail__mac-run-time">
                        {run.started}
                      </span>
                      <span className="h-job-detail__mac-run-outcome">
                        {run.failed
                          ? run.outcome === "Unfinished"
                            ? "Failed"
                            : `Failed · ${run.outcome}`
                          : run.outcome}
                      </span>
                      <Icon
                        name="chevron_right"
                        size={14}
                        color="var(--h-muted)"
                      />
                    </button>
                  ))}
                </div>
              )}
              {showMore}
            </div>
          </div>
        </div>
      </PlatformScope>
    );
  }

  const settings: Fact[] = [
    ...(job.settings ?? []),
    { label: "Deliver to", value: job.deliverTo },
    ...(job.profile ? [{ label: "Profile", value: job.profile }] : []),
  ];
  const failed = job.outcome === "failed";
  return (
    <PlatformScope platform={resolvedPlatform}>
      <div className="h-job-detail">
        <div className="h-job-detail__title">{job.title}</div>
        <div
          className={cx(
            "h-job-detail__card h-job-detail__status",
            `h-job-detail__status--${toneName}`,
          )}
        >
          <div className="h-job-detail__status-line">
            <span className="h-job-detail__dot" />
            <span>{scheduleJobStatusText(job)}</span>
          </div>
          {failed && job.failureReason ? (
            <div className="h-job-detail__reason">{job.failureReason}</div>
          ) : null}
          {job.deliveryError && job.outcome !== "deliveryFailed" ? (
            <div>{`Delivery failed: ${job.deliveryError}`}</div>
          ) : null}
          {job.outcome === "deliveryFailed" && job.deliveryError ? (
            <div className="h-job-detail__delivery">{job.deliveryError}</div>
          ) : null}
          {next ? (
            <div className="h-job-detail__next">{`Next run ${next}`}</div>
          ) : null}
        </div>
        <div className="h-job-detail__buttons">
          <Button icon="play_arrow" onClick={onRunNow}>
            Run now
          </Button>
          <Button
            variant="outlined"
            icon={job.state === "paused" ? "play_arrow" : "pause"}
            disabled={locked}
            onClick={onTogglePaused}
          >
            {job.state === "paused" ? "Resume" : "Pause"}
          </Button>
          <Button variant="outlined" icon="edit" onClick={onEdit}>
            Edit
          </Button>
        </div>
        {muted !== undefined ? (
          <SwitchRow
            title="Mute notifications"
            subtitle="No alert when this task runs"
            checked={muted}
            onChange={onMutedChange}
          />
        ) : null}
        <div className="h-job-detail__section">
          <div className="h-job-detail__heading">Schedule</div>
          <div className="h-job-detail__schedule">
            {job.scheduleText || "Unknown"}
          </div>
          {job.cronExpression ? (
            <div>
              <Badge>{job.cronExpression}</Badge>
            </div>
          ) : null}
        </div>
        {job.prompt ? (
          <div className="h-job-detail__section">
            <div className="h-job-detail__heading">Task</div>
            <div className="h-job-detail__card">{job.prompt}</div>
          </div>
        ) : null}
        <div className="h-job-detail__section">
          <div className="h-job-detail__heading">Settings</div>
          <FactList facts={settings} labelWidth={130} mono={false} />
        </div>
        <div className="h-job-detail__section">
          <div className="h-job-detail__heading">Run history</div>
          {history ??
            runs.map((run) => (
              <button
                key={run.id}
                type="button"
                className="h-job-detail__run"
                onClick={() => onOpenRun?.(run)}
              >
                {run.active ? (
                  <Spinner size={16} />
                ) : (
                  <Icon name="chat_bubble" size={18} color="var(--h-border)" />
                )}
                <span className="h-job-detail__run-text">
                  <span>{run.started}</span>
                  <span className="h-job-detail__run-outcome">
                    {run.outcome}
                  </span>
                </span>
                <Icon name="chevron_right" size={20} />
              </button>
            ))}
          {showMore}
        </div>
        <div>
          <Button
            variant="text"
            icon="delete"
            className="h-job-detail__delete"
            onClick={onDelete}
          >
            Delete task
          </Button>
        </div>
      </div>
    </PlatformScope>
  );
}

function MacMore({
  paused,
  locked,
  muted,
  defaultOpen,
  device,
  onTogglePaused,
  onMutedChange,
  onDelete,
}: {
  paused: boolean;
  locked: boolean;
  muted?: boolean;
  defaultOpen: boolean;
  device?: AppleDevice;
  onTogglePaused?: () => void;
  onMutedChange?: (muted: boolean) => void;
  onDelete?: () => void;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <MenuAnchor>
      <IconButton
        icon="more_horiz"
        label="More"
        size={32}
        onClick={() => setOpen(!open)}
      />
      {open ? (
        <Menu
          align="end"
          label="More"
          device={device}
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
  );
}
