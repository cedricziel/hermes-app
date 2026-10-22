import { SessionUsageCard, HermesProvider } from "@hermes-app/ui";

const col = { width: 420, display: "flex", flexDirection: "column" } as const;

const complete = {
  model: "scripted",
  input: 72,
  output: 12,
  reasoning: 6,
  total: 84,
  calls: 2,
  contextUsed: 1234,
  contextMax: 8192,
  contextPercent: 15,
  compressions: 1,
  costUsd: 0.0152,
};

/** Collapsed with a total in the title, and opened with every metric Hermes reported. */
export const Complete = () => (
  <div style={col}>
    <SessionUsageCard snapshot={complete} />
    <SessionUsageCard snapshot={complete} defaultOpen onRefresh={() => {}} />
  </div>
);

/** Only what was reported is listed; an estimated context says so, and a cost status shows when given. */
export const PartialAndEstimated = () => (
  <div style={col}>
    <SessionUsageCard snapshot={{ input: 72, total: 84 }} defaultOpen />
    <SessionUsageCard
      defaultOpen
      snapshot={{
        total: 84,
        contextUsed: 1234,
        contextEstimated: true,
        costStatus: "estimated",
      }}
    />
  </div>
);

/** After a disconnect the numbers are marked stale and refresh is withdrawn. */
export const Stale = () => (
  <div style={col}>
    <SessionUsageCard
      defaultOpen
      freshness="stale"
      canRefresh={false}
      snapshot={{ model: "scripted", total: 84 }}
    />
  </div>
);

/** Loading before the first snapshot, and a refresh that failed. */
export const LoadingAndFailed = () => (
  <div style={col}>
    <SessionUsageCard
      defaultOpen
      loading
      canRefresh={false}
      freshness="unavailable"
    />
    <SessionUsageCard
      defaultOpen
      failed
      snapshot={{ model: "scripted", total: 84 }}
      onRefresh={() => {}}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark">
    <div style={{ ...col, padding: 8 }}>
      <SessionUsageCard snapshot={complete} defaultOpen onRefresh={() => {}} />
    </div>
  </HermesProvider>
);
