import { HermesProvider, SchedulePicker } from "@hermes-app/ui";

const box = {
  width: 380,
  padding: 16,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  background: "var(--h-bg)",
} as const;

/** Daily at a time, with the next three runs. */
export const Daily = () => (
  <div style={box}>
    <SchedulePicker
      mode="daily"
      time="08:00"
      nextRuns="tomorrow 08:00, Thu 08:00, Fri 08:00"
    />
  </div>
);

/** Every 30 minutes: a number and a unit. */
export const Every = () => (
  <div style={box}>
    <SchedulePicker
      mode="every"
      amount="30"
      unit="minutes"
      nextRuns="12:30, 13:00, 13:30"
    />
  </div>
);

/** Weekly on weekdays, with the time. */
export const Weekly = () => (
  <div style={box}>
    <SchedulePicker
      mode="weekly"
      days={["Mon", "Tue", "Wed", "Thu", "Fri"]}
      time="09:15"
      nextRuns="Mon 09:15, Tue 09:15, Wed 09:15"
    />
  </div>
);

/** Once on a date, and a cron expression the server works out on save. */
export const OnceAndCron = () => (
  <div style={{ display: "flex", gap: 16 }}>
    <div style={box}>
      <SchedulePicker
        mode="once"
        date="Sep 18, 2026"
        time="09:00"
        nextRuns="Sep 18, 2026 09:00"
      />
    </div>
    <div style={box}>
      <SchedulePicker mode="cron" cron="0 9 * * 1-5" />
    </div>
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ width: "fit-content", padding: 16 }}>
    <div style={box}>
      <SchedulePicker
        mode="weekly"
        days={["Mon", "Thu"]}
        time="07:30"
        nextRuns="Mon 07:30, Thu 07:30, Mon 07:30"
      />
    </div>
  </HermesProvider>
);
