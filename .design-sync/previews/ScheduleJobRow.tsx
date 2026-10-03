import { HermesProvider, ScheduleJobRow } from "@hermes-app/ui";

const column = {
  width: 368,
  display: "flex",
  flexDirection: "column",
  gap: 10,
} as const;

export const List = () => (
  <div style={column}>
    <ScheduleJobRow
      selected
      job={{
        id: "price-watch",
        title: "Price watch",
        deliverTo: "Local",
        scheduleText: "Every 30 minutes",
        state: "scheduled",
        outcome: "failed",
        lastRun: "40 min ago",
        nextRun: "in 20 min",
        failureReason: "Provider timeout",
      }}
    />
    <ScheduleJobRow
      job={{
        id: "morning-brief",
        title: "Morning brief",
        deliverTo: "Local",
        scheduleText: "Weekdays at 08:00",
        state: "scheduled",
        outcome: "ok",
        lastRun: "2 h ago",
        nextRun: "in 3 h",
      }}
    />
    <ScheduleJobRow
      job={{
        id: "check-build",
        title: "Check the build and tell me",
        deliverTo: "Local",
        scheduleText: "Every 6 hours",
        state: "scheduled",
        outcome: "none",
        nextRun: "in 6 h",
      }}
    />
  </div>
);

export const DeliveryFailed = () => (
  <div style={column}>
    <ScheduleJobRow
      job={{
        id: "standup",
        title: "Standup notes",
        deliverTo: "Telegram",
        scheduleText: "Weekdays at 08:00",
        state: "scheduled",
        outcome: "deliveryFailed",
        lastRun: "5 h ago",
        nextRun: "in 19 h",
        failureReason: "Telegram: chat not found",
      }}
    />
  </div>
);

export const PausedAndCompleted = () => (
  <div style={column}>
    <ScheduleJobRow
      job={{
        id: "weekly-digest",
        title: "Weekly digest",
        deliverTo: "Local",
        scheduleText: "Mondays at 09:00",
        state: "paused",
        outcome: "ok",
      }}
    />
    <ScheduleJobRow
      job={{
        id: "renew-tls",
        title: "Renew the TLS certificate",
        deliverTo: "Local",
        scheduleText: "once on 2026-09-18 09:00",
        state: "completed",
        outcome: "ok",
      }}
    />
  </div>
);

export const LongTextAllProfiles = () => (
  <div style={column}>
    <ScheduleJobRow
      showProfile
      job={{
        id: "pr-summary",
        title:
          "Summarise every open pull request across all of the repositories in the organisation",
        deliverTo: "Discord",
        profile: "work",
        scheduleText:
          "Every weekday at 08:00, 12:00 and 17:00 except public holidays in the organisation's home country",
        state: "scheduled",
        outcome: "failed",
        lastRun: "5 min ago",
        nextRun: "in 2 min",
        failureReason:
          "ConnectionError: HTTPSConnectionPool(host='api.github.com', port=443): Max retries exceeded",
      }}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={column}>
      <ScheduleJobRow
        selected
        job={{
          id: "price-watch",
          title: "Price watch",
          deliverTo: "Local",
          scheduleText: "Every 30 minutes",
          state: "scheduled",
          outcome: "failed",
          lastRun: "40 min ago",
          nextRun: "in 20 min",
          failureReason: "Provider timeout",
        }}
      />
      <ScheduleJobRow
        job={{
          id: "morning-brief",
          title: "Morning brief",
          deliverTo: "Local",
          scheduleText: "Weekdays at 08:00",
          state: "scheduled",
          outcome: "ok",
          lastRun: "2 h ago",
          nextRun: "in 3 h",
        }}
      />
      <ScheduleJobRow
        job={{
          id: "weekly-digest",
          title: "Weekly digest",
          deliverTo: "Local",
          scheduleText: "Mondays at 09:00",
          state: "paused",
          outcome: "ok",
        }}
      />
    </div>
  </HermesProvider>
);

const jobs = [
  {
    id: "price-watch",
    title: "Price watch",
    deliverTo: "Local",
    scheduleText: "Every 30 minutes",
    state: "scheduled" as const,
    outcome: "failed" as const,
    lastRun: "40 min ago",
    nextRun: "in 20 min",
    failureReason: "Provider timeout",
  },
  {
    id: "morning-brief",
    title: "Morning brief",
    deliverTo: "Telegram",
    scheduleText: "Weekdays at 08:00",
    state: "scheduled" as const,
    outcome: "ok" as const,
    lastRun: "2 h ago",
    nextRun: "in 3 h",
  },
  {
    id: "weekly",
    title: "Weekly digest",
    deliverTo: "Local",
    scheduleText: "Fridays at 17:00",
    state: "paused" as const,
    outcome: "none" as const,
  },
];

/** Apple: one inset grouped list. Rows are siblings; the first and last get the group's corners. */
export const InsetGrouped = () => (
  <HermesProvider platform="apple" style={{ width: 390, padding: "16px 0" }}>
    <div>
      {jobs.map((job) => (
        <ScheduleJobRow key={job.id} job={job} />
      ))}
    </div>
  </HermesProvider>
);
