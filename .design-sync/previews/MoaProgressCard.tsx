import { HermesProvider, MoaProgressCard } from "@hermes-app/ui";

const col = { width: 640 } as const;

export const ReportedCounts = () => (
  <div style={col}>
    <MoaProgressCard phase="Advisors" done={1} total={3} />
  </div>
);

export const Aggregation = () => (
  <div style={col}>
    <MoaProgressCard phase="Aggregating" aggregator="claude-sonnet-5-5" />
  </div>
);

export const ExpandedReferences = () => (
  <div style={col}>
    <MoaProgressCard
      live={false}
      aggregator="claude-sonnet-5-5"
      done={2}
      total={2}
      defaultOpen
      references={[
        {
          label: "gpt-5.2",
          text: "Pin the Flutter SDK in CI and cache the pub directory; the flaky step is the unpinned install.",
        },
        {
          label: "gemini-3-pro",
          text: "The failure only shows on macOS runners, so check the Xcode version first.",
        },
      ]}
    />
  </div>
);

export const NoReferencesYet = () => (
  <div style={col}>
    <MoaProgressCard defaultOpen />
  </div>
);

export const UnavailableDetails = () => (
  <div style={col}>
    <MoaProgressCard live={false} referencesAvailable={false} defaultOpen />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ padding: 16, borderRadius: 14, width: 640 }}
  >
    <MoaProgressCard
      phase="Advisors"
      done={2}
      total={3}
      defaultOpen
      references={[
        {
          label: "gpt-5.2",
          text: "Pin the Flutter SDK in CI and cache the pub directory.",
        },
      ]}
    />
  </HermesProvider>
);
