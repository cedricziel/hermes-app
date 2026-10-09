import { GroupedSwitchRow } from "../GroupedSwitchRow/GroupedSwitchRow";
import { RowActions } from "../SwipeActions/RowActions";
import { type AppleDevice, type Platform } from "../../platform";
import "./ScheduleJobRow.css";

/** A cron job of a Hermes profile, as the Schedules list shows it. */
export interface ScheduleJob {
  /** Stable job id. */
  id: string;
  /** Job name, e.g. "Morning brief". One line, then an ellipsis. */
  title: string;
  /** Where results go, already labelled: "Local", "Origin chat", "Telegram", "Discord". */
  deliverTo: string;
  /** Profile the job belongs to; added to the subtitle when `showProfile` is set. */
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
  /** First line of the run or delivery error, joined to the failed status on the row's error or warning line: "Request timed out". */
  failureReason?: string;
}

export interface ScheduleJobRowProps {
  /** The job to show. */
  job: ScheduleJob;
  /** Filled with the border color as the job open in the detail pane (wide layout). */
  selected?: boolean;
  /** Adds the job's profile to the subtitle ("Weekdays at 08:00 · Local · work"), for "All profiles". */
  showProfile?: boolean;
  /** The row was clicked: open the job. */
  onClick?: () => void;
  /** The switch was flipped; `true` pauses the job, `false` resumes it. */
  onPausedChange?: (paused: boolean) => void;
  /**
   * The row's metrics follow the platform: iOS 17px title over a 15px
   * subtitle and 13px caption with the 51x31 switch; Mac 13/11/11px with
   * the small 36x22 switch; Material 16/14/13px with the Material switch.
   * On Apple touch the row swipes from the trailing edge to Delete and a
   * long press opens an action sheet with Run now, Pause or Resume, and
   * Delete (see `swipeRevealed`, `actionSheetOpen`); a Mac right-clicks for
   * them. Inherits the provider's platform.
   */
  platform?: Platform;
  /** Under `apple`, `touch` or `mac`; only touch swipes. Inherited from the enclosing `GroupedSection`, `GroupedListView` or `AppShell`. */
  device?: AppleDevice;
  /** Apple touch: draw the row swiped open, Delete showing in red and clipped with the group. A static preview state. */
  swipeRevealed?: boolean;
  /** Apple touch: draw the long-press action sheet over the screen (the nearest positioned ancestor). A static preview state. */
  actionSheetOpen?: boolean;
  /** An action from the swipe or the action sheet was picked. */
  onAction?: (action: ScheduleJobAction) => void;
}

/** What a job's swipe and action sheet ask for. */
export type ScheduleJobAction = "run-now" | "pause" | "resume" | "delete";

/** A job's status line: "Paused", "Failed 40 min ago", "Last run succeeded 2 h ago"… */
export function scheduleJobStatusText(job: ScheduleJob): string {
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

/** What the row and the detail flag about the last run: `failed`, `undelivered` (it ran, the delivery failed), or nothing while the job is fine, paused or completed. */
export function scheduleJobAlert(
  job: ScheduleJob,
): "failed" | "undelivered" | undefined {
  if (job.state !== "scheduled") return undefined;
  if (job.outcome === "deliveryFailed") return "undelivered";
  return job.outcome === "failed" ? "failed" : undefined;
}

/**
 * One cron job as a row of the Schedules list's `GroupedSection`, a
 * `GroupedSwitchRow`: the name, "schedule · delivery" as the subtitle, the
 * next run (or the last run's outcome and the next run) as the caption, a
 * failure on the error line ("Failed 20 min ago · Request timed out") or an
 * undelivered result on the warning line, and a switch that pauses the job.
 * Put a list's rows in one `GroupedSection`.
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
  const on = job.state === "scheduled";
  const locked = job.state === "completed";
  const alert = scheduleJobAlert(job);
  const status = [scheduleJobStatusText(job), alert && job.failureReason]
    .filter(Boolean)
    .join(" · ");
  const next = on && job.nextRun ? `Next run ${job.nextRun}` : undefined;
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
    <RowActions
      title={job.title}
      actions={actions}
      swipeRevealed={swipeRevealed}
      actionSheetOpen={actionSheetOpen}
      platform={platform}
      device={device}
      className="h-schedule-job-row__swipe"
    >
      <GroupedSwitchRow
        title={job.title}
        subtitle={[
          job.scheduleText,
          job.deliverTo,
          showProfile ? job.profile : undefined,
        ]
          .filter(Boolean)
          .join(" · ")}
        caption={alert ? next : [status, next].filter(Boolean).join(" · ")}
        error={alert === "failed" ? status : undefined}
        warning={alert === "undelivered" ? status : undefined}
        selected={selected}
        checked={on}
        disabled={locked}
        onChange={(checked) => onPausedChange?.(!checked)}
        onClick={onClick}
        platform={platform}
        device={device}
      />
    </RowActions>
  );
}
