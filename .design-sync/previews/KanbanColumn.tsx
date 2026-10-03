import { HermesProvider, KanbanColumn } from "@hermes-app/ui";

const triage = [
  {
    id: "t_triage",
    title: "Investigate flaky checkout test",
    status: "triage",
    priority: 1,
  },
  { id: "t_tri2", title: "Triage the support inbox", status: "triage" },
];

const todo = [
  {
    id: "t_todo",
    title:
      "Write docs for the webhook signing migration and its rollout plan across every environment we run",
    status: "todo",
    assignee: "writer",
    commentCount: 12,
  },
  {
    id: "t_todo3",
    title: "Write the release notes",
    status: "todo",
    assignee: "reviewer",
    priority: 3,
    commentCount: 3,
  },
];

const running = [
  {
    id: "t_run",
    title: "Migrate webhooks",
    status: "running",
    assignee: "coder",
    priority: 2,
    commentCount: 4,
    progressDone: 2,
    progressTotal: 5,
  },
  {
    id: "t_run2",
    title: "Rotate staging certificates",
    status: "running",
    assignee: "ops-assistant-with-a-long-name",
    tenant: "acme",
    progressDone: 0,
    progressTotal: 3,
    warningCount: 2,
  },
];

const review = [
  {
    id: "t_review1",
    title: "Review the settings layout",
    status: "review",
    assignee: "reviewer",
    tenant: "mobile",
  },
];

const board = {
  display: "flex",
  gap: 12,
  padding: 12,
  width: 1100,
  height: 420,
  alignItems: "stretch",
} as const;

export const Board = () => (
  <div style={board}>
    <KanbanColumn status="triage" tasks={triage} />
    <KanbanColumn status="todo" tasks={todo} />
    <KanbanColumn status="running" tasks={running} selectedIds={["t_run"]} />
    <KanbanColumn status="review" tasks={review} />
  </div>
);

export const EmptyAndDropTarget = () => (
  <div style={{ ...board, width: 560, height: 200 }}>
    <KanbanColumn status="scheduled" tasks={[]} />
    <KanbanColumn status="ready" tasks={[]} dropTarget />
  </div>
);

export const PhoneList = () => (
  <div style={{ width: 390, border: "1px dashed var(--h-border)" }}>
    <KanbanColumn variant="list" status="running" tasks={running} />
  </div>
);

export const PhoneEmpty = () => (
  <div style={{ width: 390, height: 180, border: "1px dashed var(--h-border)" }}>
    <KanbanColumn variant="list" status="scheduled" tasks={[]} />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ ...board, width: 830, height: 340, padding: 0 }}>
      <KanbanColumn status="triage" tasks={triage} />
      <KanbanColumn status="running" tasks={running} />
      <KanbanColumn status="review" tasks={review} dropTarget />
    </div>
  </HermesProvider>
);
