import {
  GroupedListView,
  GroupedSection,
  HermesProvider,
  ScheduleJobRow,
} from "@hermes-app/ui";
import type { ScheduleJob } from "@hermes-app/ui";

const failing: ScheduleJob = {
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
};
const healthy: ScheduleJob = {
  id: "job2",
  title: "Morning brief",
  deliverTo: "Local",
  profile: "work",
  scheduleText: "Weekdays at 08:00",
  state: "scheduled",
  outcome: "ok",
  lastRun: "3 h ago",
  nextRun: "in 20 h",
};
const paused: ScheduleJob = {
  id: "job3",
  title: "Weekly digest",
  deliverTo: "Telegram",
  profile: "home",
  scheduleText: "Fridays at 17:00",
  state: "paused",
  outcome: "none",
};
const undelivered: ScheduleJob = {
  id: "job4",
  title: "Nightly backup report",
  deliverTo: "Telegram",
  scheduleText: "Every day at 03:00",
  state: "scheduled",
  outcome: "deliveryFailed",
  lastRun: "6 h ago",
  nextRun: "in 18 h",
  failureReason: "Telegram: chat not found",
};
const completed: ScheduleJob = {
  id: "job5",
  title: "Remind me about the dentist",
  deliverTo: "Origin chat",
  scheduleText: "once on 2026-10-08 09:00",
  state: "completed",
  outcome: "ok",
  lastRun: "yesterday",
};

const noop = () => {};
const pair = { display: "flex", gap: 12, alignItems: "flex-start" } as const;
const touch = { width: 390, padding: "8px 0" } as const;
const mac = { width: 300, padding: "8px 0" } as const;

const group = (jobs: ScheduleJob[], extra?: { showProfile?: boolean }) => (
  <GroupedListView>
    <GroupedSection>
      {jobs.map((job) => (
        <ScheduleJobRow
          key={job.id}
          job={job}
          showProfile={extra?.showProfile}
          onClick={noop}
          onPausedChange={noop}
        />
      ))}
    </GroupedSection>
  </GroupedListView>
);

/** The list on iPhone and Material: name, "schedule · delivery", the next run or last outcome, the failure on the error line, a switch. */
export const List = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={touch}>
      {group([failing, healthy, paused])}
    </HermesProvider>
    <HermesProvider platform="material" style={touch}>
      {group([failing, healthy, paused])}
    </HermesProvider>
  </div>
);

/** A result that could not be delivered: the status and its reason on the warning line. iPhone and Mac. */
export const DeliveryFailed = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={touch}>
      {group([undelivered])}
    </HermesProvider>
    <HermesProvider platform="apple" typeRamp="default" style={mac}>
      <GroupedListView device="mac">
        <GroupedSection>
          <ScheduleJobRow job={failing} selected onClick={noop} />
          <ScheduleJobRow job={undelivered} onClick={noop} />
        </GroupedSection>
      </GroupedListView>
    </HermesProvider>
  </div>
);

/** A paused job (switch off) and a finished one-shot job (switch disabled), Material and iPhone. */
export const PausedAndCompleted = () => (
  <div style={pair}>
    <HermesProvider platform="material" style={touch}>
      {group([paused, completed])}
    </HermesProvider>
    <HermesProvider platform="apple" style={touch}>
      {group([paused, completed])}
    </HermesProvider>
  </div>
);

/** "All profiles": each subtitle ends in the job's profile; long names and reasons end in an ellipsis. */
export const LongTextAllProfiles = () => (
  <HermesProvider platform="apple" style={touch}>
    {group(
      [
        {
          ...failing,
          title:
            "Summarize every open pull request in the infrastructure repos",
          failureReason:
            "Provider returned 529 overloaded after three retries, giving up",
        },
        healthy,
        paused,
      ],
      { showProfile: true },
    )}
  </HermesProvider>
);

/** iPhone: a row swiped open to Delete, clipped with the group's corners, in light and dark. */
export const AppleSwipe = () => (
  <div style={pair}>
    {(["light", "dark"] as const).map((theme) => (
      <HermesProvider key={theme} platform="apple" theme={theme} style={touch}>
        <GroupedListView>
          <GroupedSection>
            <ScheduleJobRow job={failing} onClick={noop} />
            <ScheduleJobRow job={healthy} swipeRevealed onClick={noop} />
            <ScheduleJobRow job={paused} swipeRevealed onClick={noop} />
          </GroupedSection>
        </GroupedListView>
      </HermesProvider>
    ))}
  </div>
);

/** Dark on Material and on a Mac. */
export const Dark = () => (
  <div style={pair}>
    <HermesProvider platform="material" theme="dark" style={touch}>
      {group([failing, undelivered, paused])}
    </HermesProvider>
    <HermesProvider
      platform="apple"
      typeRamp="default"
      theme="dark"
      style={mac}
    >
      <GroupedListView device="mac">
        <GroupedSection>
          <ScheduleJobRow job={failing} selected onClick={noop} />
          <ScheduleJobRow job={healthy} onClick={noop} />
          <ScheduleJobRow job={paused} onClick={noop} />
        </GroupedSection>
      </GroupedListView>
    </HermesProvider>
  </div>
);
