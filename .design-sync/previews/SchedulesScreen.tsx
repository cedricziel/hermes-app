import { AppShell, HermesProvider, SchedulesScreen } from "@hermes-app/ui";
import type { ScheduleJob } from "@hermes-app/ui";

const jobs: ScheduleJob[] = [
  {
    id: "job1",
    title: "Morning brief",
    deliverTo: "Telegram",
    profile: "work",
    scheduleText: "Every day at 08:00",
    state: "scheduled",
    outcome: "ok",
    lastRun: "3 h ago",
    nextRun: "in 21 h",
  },
  {
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
  },
  {
    id: "job3",
    title: "Weekly digest",
    deliverTo: "Local",
    profile: "home",
    scheduleText: "Fridays at 17:00",
    state: "paused",
    outcome: "none",
  },
];

const list = {
  jobs,
  activeProfile: "work",
  failingCount: 1,
};

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;

const desktop = {
  width: 800,
  height: 560,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;

/** iPhone: the jobs as one inset grouped list with Apple switches, a "+" in the bar. */
export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <SchedulesScreen {...list} onOpenMenu={() => {}} />
    </div>
  </HermesProvider>
);

/** Android: Material cards, the "New" floating button, every profile listed. */
export const MaterialPhone = () => (
  <div style={phone}>
    <SchedulesScreen {...list} allProfiles onOpenMenu={() => {}} />
  </div>
);

/** Desktop (Linux, Windows): the list beside the selected job's detail. */
export const Desktop = () => (
  <div style={desktop}>
    <SchedulesScreen
      layout="desktop"
      {...list}
      selectedId="job2"
      detail={{
        job: {
          ...jobs[1],
          prompt:
            "Check status.example.com and tell me when something is down.",
        },
        muted: false,
        runs: [
          { id: "r8", started: "Today 11:30", outcome: "30 s" },
          { id: "r7", started: "Today 11:00", outcome: "28 s" },
        ],
      }}
    />
  </div>
);

/** Mac window: the Mac toolbar with the profile scope, separate job cards in a 250px column (a narrow window) and the Mac detail. */
export const MacWindow = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <SchedulesScreen
        layout="desktop"
        device="mac"
        listWidth={250}
        {...list}
        selectedId="job2"
        detail={{
          job: {
            ...jobs[1],
            prompt:
              "Check status.example.com and tell me when something is down.",
          },
          muted: false,
          runs: [
            { id: "r8", started: "Today 11:30", outcome: "30 s", failed: true },
            { id: "r7", started: "Today 11:00", outcome: "28 s" },
          ],
        }}
      />
    </div>
  </HermesProvider>
);

/** iPhone: a row's long-press action sheet over the screen. */
export const AppleActionSheet = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <SchedulesScreen {...list} actionSheetId="job1" onOpenMenu={() => {}} />
    </div>
  </HermesProvider>
);

const half = { ...phone, width: 250, height: 420 } as const;

/** No jobs, no match for a filter, loading, and a failed first load. */
export const EmptyLoadingError = () => (
  <div style={{ display: "flex", gap: 12 }}>
    <div style={half}>
      <SchedulesScreen jobs={[]} activeProfile="work" onOpenMenu={() => {}} />
    </div>
    <div style={half}>
      <SchedulesScreen state="loading" activeProfile="work" />
    </div>
    <div style={half}>
      <SchedulesScreen
        state="error"
        error="Could not reach the server"
        activeProfile="work"
      />
    </div>
  </div>
);

/** A refresh that failed over the loaded list, with the Failing filter on. Dark. */
export const RefreshFailedDark = () => (
  <HermesProvider theme="dark" style={{ width: "fit-content" }}>
    <div style={phone}>
      <SchedulesScreen
        jobs={[jobs[1]]}
        activeProfile="work"
        filter="failing"
        failingCount={1}
        error="Could not refresh"
        onOpenMenu={() => {}}
      />
    </div>
  </HermesProvider>
);
