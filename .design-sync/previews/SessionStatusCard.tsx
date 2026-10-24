import { HermesProvider, SessionStatusCard } from "@hermes-app/ui";

const col = { width: 640 } as const;

/** Working: what the agent waits on, folded to one summary line. */
export const Working = () => (
  <div style={col}>
    <SessionStatusCard waits={["robot-notes — recalled 5 memories"]} />
  </div>
);

export const PausedGoal = () => (
  <div style={col}>
    <SessionStatusCard
      goal={{
        title: "Review the change",
        status: "paused",
        turns_used: 2,
        max_turns: 5,
        paused_reason: "Waiting for review",
      }}
    />
  </div>
);

export const LoopAndHeartbeatOpen = () => (
  <div style={col}>
    <SessionStatusCard
      defaultOpen
      loop={{ status: "running", ticks_fired: 4, next_due_at: 1791849600 }}
      heartbeat={{ status: "running", fire_count: 3 }}
    />
  </div>
);

/** Needs you: another client took the session over; Reopen brings it back. */
export const Reclaimed = () => (
  <div style={col}>
    <SessionStatusCard
      defaultOpen
      reclaimedReason="Another client reopened this session."
      onReopen={() => {}}
    />
  </div>
);

export const FailedRestore = () => (
  <div style={col}>
    <SessionStatusCard
      defaultOpen
      resume={{
        phase: "history",
        status: "failed",
        message:
          "History remains available. Reopen to try restoring session activity again.",
      }}
      onReopen={() => {}}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    style={{ padding: 16, borderRadius: 14, width: 640 }}
  >
    <SessionStatusCard
      defaultOpen
      goal={{
        title: "Review the change",
        status: "paused",
        turns_used: 2,
        max_turns: 5,
        paused_reason: "Waiting for review",
      }}
      waits={["robot-notes — recalled 5 memories"]}
    />
  </HermesProvider>
);
