import {
  ActivityPanel,
  AgentNoticeCard,
  HermesProvider,
  SessionStatusCard,
  SideResultCard,
  TodoPlanCard,
  type TodoPlanItem,
} from "@hermes-app/ui";

const plan: TodoPlanItem[] = [
  { content: "Define the agent's role", status: "completed" },
  { content: "List the agents it oversees", status: "completed" },
  { content: "Draft the daily brief", status: "in_progress" },
  { content: "Schedule the brief", status: "pending" },
];

const now = [
  <SessionStatusCard
    key="status"
    waits={["robot-notes — recalled 5 memories"]}
  />,
];

const session = [
  <SideResultCard
    key="btw"
    result={{
      kind: "btw",
      question: "What does a chief of staff agent do?",
      text: "It reads what other agents produce and brings you decisions.",
    }}
  />,
  <AgentNoticeCard key="notice" text="Capabilities refreshed." />,
];

const inspector = {
  width: 380,
  height: 640,
  border: "1px solid var(--h-border)",
};
const sheet = {
  width: 390,
  height: 520,
  background: "var(--h-scrim)",
  display: "flex",
  alignItems: "flex-end",
};

/** The inspector beside a wide chat with every section. */
export const Inspector = () => (
  <div style={inspector}>
    <ActivityPanel
      now={now}
      plan={<TodoPlanCard items={plan} defaultOpen />}
      session={session}
    />
  </div>
);

/** The phone sheet, with the grab handle and "Close activity". */
export const PhoneSheet = () => (
  <div style={sheet}>
    <div style={{ width: "100%", height: "88%" }}>
      <ActivityPanel
        frame="sheet"
        now={now}
        plan={<TodoPlanCard items={plan} defaultOpen />}
        session={session}
        onClose={() => {}}
      />
    </div>
  </div>
);

/** Only a plan: the other sections are left out. */
export const PlanOnly = () => (
  <div style={{ ...inspector, height: 440 }}>
    <ActivityPanel plan={<TodoPlanCard items={plan} defaultOpen />} />
  </div>
);

/** Only reference items, under This session. */
export const SessionOnly = () => (
  <div style={{ ...inspector, height: 300 }}>
    <ActivityPanel session={session} />
  </div>
);

/** No activity yet. */
export const Empty = () => (
  <div style={{ ...inspector, height: 360 }}>
    <ActivityPanel />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={inspector}>
      <ActivityPanel
        now={now}
        plan={<TodoPlanCard items={plan} defaultOpen />}
        session={session}
      />
    </div>
  </HermesProvider>
);
