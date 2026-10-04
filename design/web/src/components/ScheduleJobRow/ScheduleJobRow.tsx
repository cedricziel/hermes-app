import { Switch } from "../Switch/Switch";
import { RowActions } from "../SwipeActions/RowActions";
import {
  PlatformScope,
  usePlatform,
  type AppleDevice,
  type Platform,
} from "../../platform";
import "./ScheduleJobRow.css";

/** A cron job of a Hermes profile, as the Schedules list shows it. */
export interface ScheduleJob {
  /** Stable job id. */
  id: string;
  /** Job name, e.g. "Morning brief". Wraps to two lines, then ellipsis. */
  title: string;
  /** Where results go, already labelled: "Local", "Origin chat", "Telegram", "Discord". */
  deliverTo: string;
  /** Profile the job belongs to; shown as a second chip when `showProfile` is set. */
  profile?: string;
  /** The schedule in words: "Every 30 minutes", "Weekdays at 08:00", "once on 2026-09-18 09:00". */
  scheduleText: string;
  /** `scheduled`: active. `paused`: switched off by the user. `completed`: a one-shot job that already ran (switch disabled). */
  state: "scheduled" | "paused" | "completed";
  /** How the last run went: `none` (never ran), `ok`, `failed` (the run errored) or `deliveryFailed` (ran, but the message could not be delivered). */
  outcome: "none" | "ok" | "failed" | "deliveryFailed";
  /** Relative time of the last run, e.g. "40 min ago". */
  lastRun?: string;
  /** Relative time of the next run, e.g. "in 20 min". Hidden while paused or completed. */
  nextRun?: string;
  /** First line of the run or delivery error, shown in monospace under a failed status: "Provider timeout". */
  failureReason?: string;
}

export interface ScheduleJobRowProps {
  /** The job to show. */
  job: ScheduleJob;
  /** Highlighted as the job open in the detail pane (wide layout). */
  selected?: boolean;
  /** Add the job's profile as a chip, for the "All profiles" filter. */
  showProfile?: boolean;
  /** The row was clicked: open the job. */
  onClick?: () => void;
  /** The switch was flipped; `true` pauses the job, `false` resumes it. */
  onPausedChange?: (paused: boolean) => void;
  /**
   * `apple`: an inset grouped list row instead of a bordered card. Stack the
   * rows as siblings in one container: the first and last get the group's
   * 10px corners, a hairline separates the rest, and the switch is the Apple
   * toggle. On touch the row swipes from the trailing edge to Delete and a
   * long press opens an action sheet with Run now, Pause or Resume, and
   * Delete (see `swipeRevealed`, `actionSheetOpen`); a Mac right-clicks for
   * them. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` (default) or `mac`; only touch swipes. Inherited from the enclosing `AppShell`. */
  device?: AppleDevice;
  /** Apple touch: draw the row swiped open, Delete showing in red. A static preview state. */
  swipeRevealed?: boolean;
  /** Apple touch: draw the long-press action sheet over the screen (the nearest positioned ancestor). A static preview state. */
  actionSheetOpen?: boolean;
  /** An action from the swipe or the action sheet was picked. */
  onAction?: (action: ScheduleJobAction) => void;
}

/** What a job's swipe and action sheet ask for. */
export type ScheduleJobAction = "run-now" | "pause" | "resume" | "delete";

function statusText(job: ScheduleJob): string {
  if (job.state === "paused") return "Paused";
  if (job.state === "completed") return "Completed";
  const at = job.lastRun ? ` ${job.lastRun}` : "";
  switch (job.outcome) {
    case "ok":
      return `Last run succeeded${at}`;
    case "failed":
      return `Failed${at}`;
    case "deliveryFailed":
      return `Ran, but delivery failed${at}`;
    default:
      return "Not run yet";
  }
}

function tone(job: ScheduleJob): string {
  if (job.state !== "scheduled") return "muted";
  switch (job.outcome) {
    case "failed":
      return "error";
    case "deliveryFailed":
      return "warning";
    case "ok":
      return "success";
    default:
      return "muted";
  }
}

/**
 * One cron job in the Schedules list: a bordered card with the name, delivery
 * chip and an on/off switch, the schedule in words, and a status line with the
 * last run's outcome and the next run.
 */
export function ScheduleJobRow({
  job,
  selected = false,
  showProfile = false,
  onClick,
  onPausedChange,
  platform,
  device,
  swipeRevealed,
  actionSheetOpen,
  onAction,
}: ScheduleJobRowProps) {
  const resolvedPlatform = usePlatform(platform);
  const apple = resolvedPlatform === "apple";
  const on = job.state === "scheduled";
  const locked = job.state === "completed";
  const failing = job.outcome === "failed" || job.outcome === "deliveryFailed";
  const reason =
    failing && job.state === "scheduled" ? job.failureReason : undefined;
  const next = on && job.nextRun ? `Next run ${job.nextRun}` : null;
  const classes = [
    "h-schedule-job-row",
    `h-schedule-job-row--${tone(job)}`,
    selected ? "h-schedule-job-row--selected" : null,
    apple ? "h-schedule-job-row--apple" : null,
  ]
    .filter(Boolean)
    .join(" ");
  const actions = [
    { label: "Run now", icon: "play_arrow", value: "run-now" as const },
    ...(locked
      ? []
      : [
          on
            ? { label: "Pause", icon: "pause", value: "pause" as const }
            : { label: "Resume", icon: "play_arrow", value: "resume" as const },
        ]),
    {
      label: "Delete",
      icon: "delete",
      value: "delete" as const,
      destructive: true,
    },
  ].map((a) => ({ ...a, onPress: () => onAction?.(a.value) }));
  return (
    <PlatformScope platform={resolvedPlatform}>
      <RowActions
        title={job.title}
        actions={actions}
        swipeRevealed={swipeRevealed}
        actionSheetOpen={actionSheetOpen}
        device={device}
        className="h-schedule-job-row__swipe"
      >
        <div
          className={classes}
          role="button"
          tabIndex={0}
          aria-pressed={selected}
          onClick={onClick}
          onKeyDown={(e) => {
            if (e.key === "Enter" || e.key === " ") {
              e.preventDefault();
              onClick?.();
            }
          }}
        >
          <div className="h-schedule-job-row__head">
            <div className="h-schedule-job-row__titles">
              <span className="h-schedule-job-row__title">{job.title}</span>
              <span className="h-schedule-job-row__chip">{job.deliverTo}</span>
              {showProfile && job.profile ? (
                <span className="h-schedule-job-row__chip">{job.profile}</span>
              ) : null}
            </div>
            <Switch
              checked={on}
              label={on ? "Pause" : "Resume"}
              disabled={locked}
              onClick={(e) => e.stopPropagation()}
              onChange={() => onPausedChange?.(on)}
            />
          </div>
          {job.scheduleText ? (
            <div className="h-schedule-job-row__schedule">
              {job.scheduleText}
            </div>
          ) : null}
          <hr className="h-schedule-job-row__divider" />
          <div className="h-schedule-job-row__status">
            <span className="h-schedule-job-row__dot" />
            <span className="h-schedule-job-row__status-text">
              {statusText(job)}
            </span>
            {next ? (
              <span className="h-schedule-job-row__next">{next}</span>
            ) : null}
          </div>
          {reason ? (
            <div className="h-schedule-job-row__reason">{reason}</div>
          ) : null}
        </div>
      </RowActions>
    </PlatformScope>
  );
}
