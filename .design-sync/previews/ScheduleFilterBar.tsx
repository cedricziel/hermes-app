import { HermesProvider, ScheduleFilterBar } from "@hermes-app/ui";

const box = {
  width: 400,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  background: "var(--h-bg)",
} as const;

/** The active profile picked, two failing jobs counted, no filter on. */
export const ActiveProfile = () => (
  <div style={box}>
    <ScheduleFilterBar activeProfile="work" failingCount={2} />
  </div>
);

/** All profiles with the Failing filter on. */
export const AllFailing = () => (
  <div style={box}>
    <ScheduleFilterBar
      activeProfile="work"
      allProfiles
      filter="failing"
      failingCount={2}
    />
  </div>
);

/** A long profile name wraps the chips onto a second line rather than scrolling. */
export const Wrapping = () => (
  <div style={{ ...box, width: 320 }}>
    <ScheduleFilterBar activeProfile="research-assistant" filter="paused" />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={box}>
      <ScheduleFilterBar
        activeProfile="work"
        filter="failing"
        failingCount={1}
      />
    </div>
  </HermesProvider>
);
