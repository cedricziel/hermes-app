import { Button } from "../Button/Button";
import { DisclosureTile } from "./DisclosureTile";
import "./SessionStatusCard.css";

/** One control section Hermes reports (a goal, a loop or a heartbeat): flat fields of text, numbers and flags, keyed by the server's snake_case names. */
export type SessionControlSection = Record<string, string | number | boolean>;

/** Progress of restoring a session after it was reopened. */
export interface SessionResumeProgress {
  /** What is being restored: `history`, `activity`. */
  phase: string;
  /** Where it stands: `running`, `done`, `failed`. `failed` offers Reopen. */
  status: string;
  /** Longer explanation shown when open. */
  message?: string;
}

export interface SessionStatusCardProps {
  /** The session's goal: `title`, `status` (`active`, `paused`, `done`), `turns_used`, `max_turns`, `paused_reason`, `last_verdict`, `last_reason`. */
  goal?: SessionControlSection;
  /** A recurring loop: `prompt`, `status`, `mode`, `ticks_fired`, `max_ticks`, `interval_seconds`, `next_due_at` (epoch seconds, drawn as a local date and time), `paused_reason`, `last_stop_reason`. */
  loop?: SessionControlSection;
  /** A heartbeat: `prompt`, `status`, `fire_count`, `interval_seconds`. */
  heartbeat?: SessionControlSection;
  /** What the agent is waiting on right now, one line each ("robot-notes — recalled 5 memories"). Joined into the header and listed when open. */
  waits?: string[];
  /** Restoring the session after it was reopened. */
  resume?: SessionResumeProgress;
  /**
   * Another client took control of this session. Pass the server's reason, or
   * an empty string for the default text ("Another client took control of
   * this session."); leave out when the session was not reclaimed. Together
   * with a failed `resume` this is the "needs you" state that offers Reopen.
   */
  reclaimedReason?: string;
  /** Start opened, to preview the details. Folded by default. */
  defaultOpen?: boolean;
  /** The details were opened (the app logs it). */
  onDetails?: () => void;
  /** Shows the "Reopen session" button when the session was reclaimed or its restore failed. */
  onReopen?: () => void;
}

const goalLabels: Record<string, string> = {
  title: "Objective",
  status: "Status",
  turns_used: "Turns used",
  max_turns: "Maximum turns",
  paused_reason: "Paused reason",
  last_verdict: "Last verdict",
  last_reason: "Last reason",
};

const loopLabels: Record<string, string> = {
  prompt: "Prompt",
  status: "Status",
  mode: "Mode",
  ticks_fired: "Ticks fired",
  max_ticks: "Maximum ticks",
  interval_seconds: "Interval in seconds",
  next_due_at: "Next due",
  paused_reason: "Paused reason",
  last_stop_reason: "Last stop reason",
};

const heartbeatLabels: Record<string, string> = {
  prompt: "Prompt",
  status: "Status",
  fire_count: "Fire count",
  interval_seconds: "Interval in seconds",
};

function formatValue(key: string, value: string | number | boolean) {
  if (
    key === "next_due_at" &&
    typeof value === "number" &&
    Number.isFinite(value) &&
    value > 0 &&
    value < 8640000000
  ) {
    const time = new Date(Math.round(value * 1000));
    const date = time.toLocaleDateString("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
    });
    const clock = time.toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
    });
    return `${date} ${clock}`;
  }
  return String(value);
}

function Section({
  title,
  values,
  labels,
}: {
  title: string;
  values: SessionControlSection;
  labels: Record<string, string>;
}) {
  return (
    <div className="h-session-status__section">
      <div className="h-session-status__section-title">{title}</div>
      {Object.entries(labels).map(([key, label]) =>
        values[key] === undefined ? null : (
          <div key={key}>
            {label}: {formatValue(key, values[key])}
          </div>
        ),
      )}
    </div>
  );
}

/**
 * The Working-tier card for what a chat session is doing beyond the current
 * reply: a goal, a loop, a heartbeat, waits on the agent's own tools, session
 * restore progress, or "Session reclaimed" when another client took the
 * session over. Folded it is one summary line (up to two lines) joined with
 * " · "; opened it lists each section's fields and, when the session was
 * reclaimed or its restore failed, a "Reopen session" button. Draws nothing
 * when none of the inputs is set. Material on every platform, as in the app.
 */
export function SessionStatusCard({
  goal,
  loop,
  heartbeat,
  waits = [],
  resume,
  reclaimedReason,
  defaultOpen = false,
  onDetails,
  onReopen,
}: SessionStatusCardProps) {
  const reclaimed = reclaimedReason !== undefined;
  if (!goal && !loop && !heartbeat && !waits.length && !resume && !reclaimed)
    return null;
  const summary = [
    reclaimed ? "Session reclaimed" : null,
    resume ? `Restoring session: ${resume.phase} · ${resume.status}` : null,
    goal ? `Goal: ${goal.status ?? "Unavailable"}` : null,
    loop ? `Loop: ${loop.status ?? "Unavailable"}` : null,
    heartbeat ? `Heartbeat: ${heartbeat.status ?? "Unavailable"}` : null,
    ...waits,
  ]
    .filter((part): part is string => part !== null)
    .join(" · ");
  const canReopen = !!onReopen && (reclaimed || resume?.status === "failed");
  return (
    <DisclosureTile
      defaultOpen={defaultOpen}
      onOpen={onDetails}
      title={<span className="h-session-status__summary">{summary}</span>}
    >
      <div className="h-session-status__details">
        {reclaimed ? (
          <div>
            {reclaimedReason === ""
              ? "Another client took control of this session."
              : reclaimedReason}
          </div>
        ) : null}
        {resume ? (
          <>
            <div>
              {resume.phase}: {resume.status}
            </div>
            {resume.message ? <div>{resume.message}</div> : null}
          </>
        ) : null}
        {goal ? (
          <Section title="Goal" values={goal} labels={goalLabels} />
        ) : null}
        {loop ? (
          <Section title="Loop" values={loop} labels={loopLabels} />
        ) : null}
        {heartbeat ? (
          <Section
            title="Heartbeat"
            values={heartbeat}
            labels={heartbeatLabels}
          />
        ) : null}
        {waits.map((wait, i) => (
          <div key={i}>{wait}</div>
        ))}
        {canReopen ? (
          <div className="h-session-status__action">
            <Button variant="text" onClick={onReopen}>
              Reopen session
            </Button>
          </div>
        ) : null}
      </div>
    </DisclosureTile>
  );
}
