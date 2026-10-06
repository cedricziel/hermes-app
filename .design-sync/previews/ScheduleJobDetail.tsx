import { HermesProvider, ScheduleJobDetail } from "@hermes-app/ui";
import type { ScheduleJobDetailItem, ScheduleRunItem } from "@hermes-app/ui";

const healthy: ScheduleJobDetailItem = {
  id: "job1",
  title: "Morning brief",
  deliverTo: "Telegram",
  profile: "work",
  scheduleText: "Every day at 08:00",
  cronExpression: "0 8 * * *",
  state: "scheduled",
  outcome: "ok",
  lastRun: "3 h ago",
  nextRun: "in 21 h",
  prompt: "Summarize my calendar for today and the overnight news on AI.",
  settings: [
    { label: "Skills", value: "news, calendar" },
    { label: "Model", value: "claude-opus-4" },
  ],
};

const failing: ScheduleJobDetailItem = {
  id: "job2",
  title: "Check the status page",
  deliverTo: "Local",
  profile: "work",
  scheduleText: "Every 30 minutes",
  state: "scheduled",
  outcome: "failed",
  lastRun: "20 min ago",
  nextRun: "in 10 min",
  failureReason: "Request timed out",
  prompt: "Check status.example.com and tell me when something is down.",
};

const runs: ScheduleRunItem[] = [
  { id: "r3", started: "Today 08:00", outcome: "42 s" },
  { id: "r2", started: "Yesterday 08:00", outcome: "1 min" },
  { id: "r1", started: "Sep 30, 08:00", outcome: "Unfinished" },
];

const pane = {
  width: 420,
  height: 640,
  border: "1px solid var(--h-border)",
  overflow: "auto",
  background: "var(--h-bg)",
} as const;

/** Material: a healthy job with its schedule, cron chip, task, settings and runs. */
export const Healthy = () => (
  <div style={pane}>
    <ScheduleJobDetail job={healthy} runs={runs} muted={false} canShowMore />
  </div>
);

/** iPhone: a failing job (red status card and reason), Apple Mute switch, a run in progress. */
export const AppleFailing = () => (
  <HermesProvider platform="apple">
    <div style={{ ...pane, width: 390 }}>
      <ScheduleJobDetail
        job={failing}
        muted
        runs={[
          {
            id: "r9",
            started: "Today 11:30",
            outcome: "Running",
            active: true,
          },
          { id: "r8", started: "Today 11:00", outcome: "30 s" },
        ]}
      />
    </div>
  </HermesProvider>
);

/** Mac window detail: header with Edit and Run now, the failure card, the settings grid and Recent runs; the "…" menu open. */
export const MacFailing = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={{ ...pane, width: 600, height: 520 }}>
      <ScheduleJobDetail
        variant="mac"
        device="mac"
        job={failing}
        muted={false}
        defaultMenuOpen
        runs={[
          { id: "r8", started: "Today 11:30", outcome: "30 s", failed: true },
          { id: "r7", started: "Today 11:00", outcome: "28 s" },
          { id: "r6", started: "Today 10:30", outcome: "Unfinished" },
        ]}
      />
    </div>
  </HermesProvider>
);

/** A paused job whose runs are loading, and one blocked before it ever ran; the runs failed to load on a third. */
export const PausedAndRunStates = () => (
  <div style={{ display: "flex", gap: 16 }}>
    <div style={{ ...pane, width: 260, height: 520 }}>
      <ScheduleJobDetail
        job={{
          id: "job3",
          title: "Weekly digest",
          deliverTo: "Local",
          scheduleText: "Fridays at 17:00",
          state: "paused",
          outcome: "none",
        }}
        runsState="loading"
      />
    </div>
    <div style={{ ...pane, width: 260, height: 520 }}>
      <ScheduleJobDetail
        job={{
          id: "job4",
          title: "Sync the CRM",
          deliverTo: "Local",
          scheduleText: "Every hour",
          state: "scheduled",
          outcome: "failed",
          failureReason: "Script not allowed: sync.sh",
          blocked: true,
        }}
      />
    </div>
    <div style={{ ...pane, width: 260, height: 520 }}>
      <ScheduleJobDetail
        job={{
          id: "job5",
          title: "Renew the TLS certificate",
          deliverTo: "Local",
          scheduleText: "once on 2026-09-18 09:00",
          state: "completed",
          outcome: "ok",
        }}
        runsState="error"
      />
    </div>
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ width: "fit-content" }}>
    <div style={{ ...pane, height: 520 }}>
      <ScheduleJobDetail job={healthy} runs={runs} muted={false} />
    </div>
  </HermesProvider>
);
