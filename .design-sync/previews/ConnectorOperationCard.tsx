import { ConnectorOperationCard, HermesProvider } from "@hermes-app/ui";

const col = { width: 420, display: "flex", flexDirection: "column" } as const;

const calendar = {
  name: "Calendar",
  kind: "connector",
  action: "authorize",
  state: "initiated",
  instructions: "Continue in the browser to approve access.",
  connectUrl: "https://connect.example.com/verify",
};

const actions = {
  onOpen: () => {},
  onSkip: () => {},
  onContinue: () => {},
};

/** Needs you: collapsed, then opened with the target, its instructions and destination, Open connection, Skip and Continue. */
export const Actionable = () => (
  <div style={col}>
    <ConnectorOperationCard operation={{ targets: [calendar] }} {...actions} />
    <ConnectorOperationCard
      defaultOpen
      operation={{ targets: [calendar] }}
      {...actions}
    />
  </div>
);

/** A response in flight or waiting on Hermes: the header says so and every control is disabled. */
export const Waiting = () => (
  <div style={col}>
    <ConnectorOperationCard
      defaultOpen
      awaitingFinalStatus
      operation={{ targets: [calendar] }}
      {...actions}
    />
    <ConnectorOperationCard
      defaultOpen
      pending
      operation={{ targets: [calendar] }}
      {...actions}
    />
  </div>
);

/** A refused response keeps the card open for another try, with the reason under the target. */
export const Refused = () => (
  <div style={col}>
    <ConnectorOperationCard
      defaultOpen
      error="The server refused this response."
      operation={{ targets: [calendar] }}
      {...actions}
    />
  </div>
);

/** Reference states: settled (with why), read-only (another chat owns it) and no targets. */
export const Reference = () => (
  <div style={col}>
    <ConnectorOperationCard
      defaultOpen
      operation={{
        settled: true,
        settledBy: "user",
        targets: [{ ...calendar, state: "connected", resolved: true }],
      }}
      {...actions}
    />
    <ConnectorOperationCard
      defaultOpen
      readOnly
      operation={{ targets: [calendar] }}
      {...actions}
    />
    <ConnectorOperationCard defaultOpen operation={{ targets: [] }} />
  </div>
);

/** A plugin install cannot be finished here: the target says so and offers only Skip. */
export const Unavailable = () => (
  <div style={col}>
    <ConnectorOperationCard
      defaultOpen
      operation={{
        targets: [
          {
            name: "Calendar",
            kind: "plugin",
            action: "install",
            state: "initiated",
            instructions: "Continue in the browser to approve access.",
            connectUrl: "https://connect.example.com/verify",
          },
        ],
      }}
      {...actions}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ width: "fit-content", padding: 16, borderRadius: 14 }}
  >
    <div style={{ ...col, padding: 8 }}>
      <ConnectorOperationCard
        defaultOpen
        operation={{ targets: [calendar] }}
        {...actions}
      />
    </div>
  </HermesProvider>
);
