import { HermesProvider, KanbanStatusChips } from "@hermes-app/ui";

const statuses = [
  { name: "triage", count: 1 },
  { name: "todo", count: 1 },
  { name: "scheduled", count: 0 },
  { name: "ready", count: 0 },
  { name: "running", count: 2 },
  { name: "blocked", count: 1 },
  { name: "review", count: 2 },
  { name: "done", count: 7 },
];

export const Phone = () => (
  <div style={{ width: 390 }}>
    <KanbanStatusChips statuses={statuses} selected="triage" />
  </div>
);

export const RunningSelected = () => (
  <div style={{ width: 720 }}>
    <KanbanStatusChips statuses={statuses} selected="running" />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ width: 720 }}>
      <KanbanStatusChips statuses={statuses} selected="running" />
    </div>
  </HermesProvider>
);
