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
