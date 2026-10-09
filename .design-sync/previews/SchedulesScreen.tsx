import { HermesProvider, SchedulesScreen } from "@hermes-app/ui";
import type { ScheduleJob, ScheduleJobDetailProps } from "@hermes-app/ui";

const jobs: ScheduleJob[] = [
  {
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
  },
  {
    id: "job2",
    title: "Morning brief",
    deliverTo: "Local",
    profile: "work",
    scheduleText: "Weekdays at 08:00",
    state: "scheduled",
    outcome: "ok",
    lastRun: "3 h ago",
    nextRun: "in 20 h",
  },
  {
    id: "job3",
    title: "Weekly digest",
    deliverTo: "Telegram",
    profile: "home",
    scheduleText: "Fridays at 17:00",
    state: "paused",
    outcome: "none",
  },
];

const list = { jobs, activeProfile: "work", failingCount: 1 };

const detail: ScheduleJobDetailProps = {
  job: {
    ...jobs[0],
    prompt: "Say good morning",
  },
  runs: [
    {
      id: "r3",
      started: "Oct 9, 2026 3:22 AM",
      outcome: "1 min",
      failed: true,
    },
    { id: "r2", started: "Oct 9, 2026 2:52 AM", outcome: "1 min" },
    { id: "r1", started: "Oct 9, 2026 2:22 AM", outcome: "1 min" },
  ],
};

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 560 } as const;
const pair = { display: "flex", gap: 12, alignItems: "flex-start" } as const;
const noop = () => {};

/** iPhone: "Schedules" over "work ⌄", filter, Refresh and "+" in the 44px bar, the jobs as one inset group of switch rows (failure on the error line). Light and dark. */
export const ApplePhone = () => (
  <div style={pair}>
    {(["light", "dark"] as const).map((theme) => (
      <HermesProvider key={theme} platform="apple" theme={theme} style={phone}>
        <SchedulesScreen {...list} onOpenMenu={noop} />
      </HermesProvider>
    ))}
  </div>
);

/** Android: the 56px bar with the title at the start, no floating button; the filter menu open (All tasks, Failing (1), Paused) and, beside it, the subtitle's profile menu with every profile listed. */
export const MaterialPhone = () => (
  <div style={pair}>
    <HermesProvider platform="material" style={phone}>
      <SchedulesScreen {...list} filterMenuOpen onOpenMenu={noop} />
    </HermesProvider>
    <HermesProvider platform="material" style={phone}>
      <SchedulesScreen {...list} allProfiles scopeMenuOpen onOpenMenu={noop} />
    </HermesProvider>
  </div>
);

/** Desktop (Linux, Windows): the 400px job group beside the selected job's grouped detail. */
export const Desktop = () => (
  <HermesProvider platform="material" style={desktop}>
    <SchedulesScreen
      layout="desktop"
      {...list}
      selectedId="job1"
      detail={{ ...detail, muted: false }}
    />
  </HermesProvider>
);

/** Mac window: the toolbar ("Schedules" over "3 jobs", This profile / All profiles, filter, Refresh, New Schedule), the job group in a 250px column, the selected row filled, and the Mac detail. */
export const MacWindow = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <SchedulesScreen
      layout="desktop"
      device="mac"
      listWidth={250}
      {...list}
      selectedId="job1"
      detail={{ ...detail, muted: false }}
    />
  </HermesProvider>
);

/** iPhone: a row swiped open to Delete (clipped with the group), and a row's long-press action sheet. */
export const AppleActionSheet = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={phone}>
      <SchedulesScreen {...list} swipedId="job2" onOpenMenu={noop} />
    </HermesProvider>
    <HermesProvider platform="apple" style={phone}>
      <SchedulesScreen {...list} actionSheetId="job2" onOpenMenu={noop} />
    </HermesProvider>
  </div>
);

const small = { ...phone, width: 268, height: 420 } as const;

/** No jobs, loading, and a failed first load. */
export const EmptyLoadingError = () => (
  <div style={pair}>
    <HermesProvider platform="material" style={small}>
      <SchedulesScreen jobs={[]} activeProfile="work" />
    </HermesProvider>
    <HermesProvider platform="material" style={small}>
      <SchedulesScreen state="loading" activeProfile="work" />
    </HermesProvider>
    <HermesProvider platform="material" style={small}>
      <SchedulesScreen
        state="error"
        error="Could not reach the server"
        activeProfile="work"
      />
    </HermesProvider>
  </div>
);

/** A refresh that failed over the loaded list with the Failing filter on, then no match for the Paused filter. Dark. */
export const RefreshFailedDark = () => (
  <div style={pair}>
    <HermesProvider platform="material" theme="dark" style={phone}>
      <SchedulesScreen
        jobs={[jobs[0]]}
        activeProfile="work"
        filter="failing"
        failingCount={1}
        error="Could not refresh"
        onOpenMenu={noop}
      />
    </HermesProvider>
    <HermesProvider platform="apple" theme="dark" style={phone}>
      <SchedulesScreen
        jobs={[]}
        activeProfile="work"
        filter="paused"
        onOpenMenu={noop}
      />
    </HermesProvider>
  </div>
);
