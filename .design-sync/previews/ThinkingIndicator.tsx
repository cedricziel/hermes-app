import { HermesProvider, ThinkingIndicator } from "@hermes-app/ui";

export const Thinking = () => <ThinkingIndicator elapsedSeconds={4} />;

export const RunningATool = () => (
  <ThinkingIndicator elapsedSeconds={72} activity="Running git_show…" />
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <ThinkingIndicator elapsedSeconds={12} activity="Running shell…" />
  </HermesProvider>
);

/** Apple: the spinner is the activity indicator, in the muted text color like the rest of the line. */
export const Apple = () => (
  <HermesProvider
    platform="apple"
    style={{
      display: "flex",
      flexDirection: "column",
      gap: 12,
      padding: 16,
      borderRadius: 14,
    }}
  >
    <ThinkingIndicator elapsedSeconds={4} />
    <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
      <ThinkingIndicator elapsedSeconds={72} activity="Running git_show…" />
    </HermesProvider>
  </HermesProvider>
);
