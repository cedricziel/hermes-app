import {
  GroupedListView,
  HermesProvider,
  SchedulePicker,
} from "@hermes-app/ui";
import type { SchedulePickerProps } from "@hermes-app/ui";

const pair = { display: "flex", gap: 12, alignItems: "flex-start" } as const;
const touch = { width: 390, paddingBottom: 12 } as const;
const mac = { width: 400, paddingBottom: 12 } as const;

const both = (props: SchedulePickerProps, theme?: "dark") => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider
        key={platform}
        platform={platform}
        theme={theme}
        style={touch}
      >
        <GroupedListView>
          <SchedulePicker {...props} />
        </GroupedListView>
      </HermesProvider>
    ))}
  </div>
);

/** Daily: the segmented control and a Time value row, the next runs as the footer. iPhone and Material. */
export const Daily = () =>
  both({
    mode: "daily",
    time: "08:00",
    nextRuns:
      "Oct 10, 2026 8:00 AM, Oct 11, 2026 8:00 AM, Oct 12, 2026 8:00 AM",
  });

/** Every: a number field and a Unit menu row (open on the Mac). iPhone and Mac. */
export const Every = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={touch}>
      <GroupedListView>
        <SchedulePicker
          mode="every"
          amount="1"
          unit="hours"
          nextRuns="Oct 9, 2026 3:45 AM, Oct 9, 2026 4:45 AM, Oct 9, 2026 5:45 AM"
        />
      </GroupedListView>
    </HermesProvider>
    <HermesProvider
      platform="apple"
      typeRamp="default"
      style={{ ...mac, height: 260 }}
    >
      <GroupedListView device="mac">
        <SchedulePicker
          mode="every"
          amount="1"
          unit="hours"
          unitMenuOpen
          nextRuns="Oct 9, 2026 3:45 AM, Oct 9, 2026 4:45 AM, Oct 9, 2026 5:45 AM"
        />
      </GroupedListView>
    </HermesProvider>
  </div>
);

/** Weekly: the seven day pills (Mon–Fri filled) and Time. iPhone and Material. */
export const Weekly = () =>
  both({
    mode: "weekly",
    days: ["Mon", "Tue", "Wed", "Thu", "Fri"],
    time: "08:00",
    nextRuns: "Oct 9, 2026 8:00 AM, Oct 12, 2026 8:00 AM, Oct 13, 2026 8:00 AM",
  });

/** Once (Date and Time) on iPhone, and Cron (a monospace field, the hint and "the server works it out") on Material. */
export const OnceAndCron = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={touch}>
      <GroupedListView>
        <SchedulePicker
          mode="once"
          date="Oct 10, 2026"
          time="09:00"
          nextRuns="Oct 10, 2026 9:00 AM"
        />
      </GroupedListView>
    </HermesProvider>
    <HermesProvider platform="material" style={touch}>
      <GroupedListView>
        <SchedulePicker mode="cron" cron="0 9 * * 1-5" />
      </GroupedListView>
    </HermesProvider>
  </div>
);

/** Dark: Weekly on iPhone and Material. */
export const Dark = () =>
  both(
    {
      mode: "weekly",
      days: ["Sat", "Sun"],
      time: "10:30",
      nextRuns: "Oct 10, 2026 10:30 AM, Oct 11, 2026 10:30 AM",
    },
    "dark",
  );
