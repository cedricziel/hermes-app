import { HermesProvider, ScheduleJobDetail } from "@hermes-app/ui";
import type { ScheduleJobDetailItem, ScheduleRunItem } from "@hermes-app/ui";

const failing: ScheduleJobDetailItem = {
  id: "job1",
  title: "Check the status page",
  deliverTo: "Local",
  profile: "work",
  scheduleText: "Every 30 minutes",
  state: "scheduled",
  outcome: "failed",
  lastRun: "20 min ago",
  nextRun: "in 9 min",
  failureReason: "Request timed out",
  prompt: "Say good morning",
};

const healthy: ScheduleJobDetailItem = {
  id: "job2",
  title: "Morning brief",
  deliverTo: "Telegram",
  profile: "work",
  scheduleText: "Weekdays at 08:00",
  cronExpression: "0 8 * * 1-5",
  state: "scheduled",
  outcome: "ok",
  lastRun: "3 h ago",
  nextRun: "in 20 h",
  prompt: "Summarize my calendar for today and the overnight news on AI.",
  settings: [
    { label: "Skills", value: "news, calendar" },
    { label: "Model", value: "claude-opus-4" },
  ],
};

const runs: ScheduleRunItem[] = [
  {
    id: "r3",
    started: "Oct 9, 2026 3:22 AM",
    outcome: "1 min",
    failed: true,
  },
  { id: "r2", started: "Oct 9, 2026 2:52 AM", outcome: "1 min" },
  { id: "r1", started: "Oct 9, 2026 2:22 AM", outcome: "1 min" },
];

const healthyRuns: ScheduleRunItem[] = [
  { id: "r9", started: "Oct 9, 2026 8:00 AM", outcome: "42 s" },
  {
    id: "r8",
    started: "Oct 8, 2026 8:00 AM",
    outcome: "Unfinished",
    unfinished: true,
  },
];

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;
const pair = { display: "flex", gap: 12, alignItems: "flex-start" } as const;
const noop = () => {};

/** Material: a healthy job as a pane (headline title), Mute switch, Run now / Pause / Edit, a cron row in monospace, its settings and runs (one unfinished), "Show more". */
export const Healthy = () => (
  <div style={pair}>
    <HermesProvider platform="material" style={phone}>
      <ScheduleJobDetail
        job={healthy}
        runs={healthyRuns}
        muted={false}
        canShowMore
      />
    </HermesProvider>
    <HermesProvider platform="material" style={phone}>
      <ScheduleJobDetail job={failing} runs={runs} muted onBack={noop} />
    </HermesProvider>
  </div>
);

/** iPhone, pushed over the list ("‹ Schedules"): the failure on the status row's error line, actions with leading icons, Schedule, Task, Settings with muted values, and the run history (a run in progress). */
export const AppleFailing = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={phone}>
      <ScheduleJobDetail
        job={failing}
        runs={runs}
        muted={false}
        onBack={noop}
      />
    </HermesProvider>
    <HermesProvider platform="apple" style={phone}>
      <ScheduleJobDetail
        job={healthy}
        muted
        onBack={noop}
        runs={[
          {
            id: "r10",
            started: "Oct 9, 2026 8:00 AM",
            outcome: "Running",
            active: true,
          },
          ...healthyRuns,
        ]}
      />
    </HermesProvider>
  </div>
);

/** Mac pane: the title over "schedule · next run" beside "…" (open: Pause, Mute Notifications, Delete…), Edit and Run now; the status, Schedule, Task, Settings and Recent runs groups. */
export const MacFailing = () => (
  <HermesProvider
    platform="apple"
    typeRamp="default"
    style={{ ...phone, width: 640, height: 560 }}
  >
    <ScheduleJobDetail
      device="mac"
      job={failing}
      muted={false}
      defaultMenuOpen
      runs={runs}
    />
  </HermesProvider>
);

const third = { ...phone, width: 268, height: 520 } as const;

/** A paused job whose runs are loading, one blocked before it ever ran, and a finished one-shot job whose runs failed to load. */
export const PausedAndRunStates = () => (
  <div style={pair}>
    <HermesProvider platform="material" style={third}>
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
    </HermesProvider>
    <HermesProvider platform="material" style={third}>
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
    </HermesProvider>
    <HermesProvider platform="apple" style={third}>
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
    </HermesProvider>
  </div>
);

/** Dark: iPhone and Material, an undelivered result on the warning line. */
export const Dark = () => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider
        key={platform}
        platform={platform}
        theme="dark"
        style={phone}
      >
        <ScheduleJobDetail
          job={{
            ...healthy,
            outcome: "deliveryFailed",
            deliveryError: "Telegram: chat not found",
          }}
          runs={healthyRuns}
          muted={false}
          onBack={noop}
        />
      </HermesProvider>
    ))}
  </div>
);
