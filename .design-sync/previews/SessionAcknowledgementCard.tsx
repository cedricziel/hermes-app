import { SessionAcknowledgementCard, HermesProvider } from "@hermes-app/ui";

const col = { width: 420, display: "flex", flexDirection: "column" } as const;

/** Collapsed, then opened with its one explanatory line. */
export const States = () => (
  <div style={col}>
    <SessionAcknowledgementCard acknowledgement="vibe" />
    <SessionAcknowledgementCard acknowledgement="vibe" defaultOpen />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark">
    <div style={{ ...col, padding: 8 }}>
      <SessionAcknowledgementCard acknowledgement="vibe" defaultOpen />
    </div>
  </HermesProvider>
);
