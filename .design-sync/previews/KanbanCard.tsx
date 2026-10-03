import { HermesProvider, KanbanCard } from "@hermes-app/ui";

const col = {
  display: "flex",
  flexDirection: "column",
  gap: 8,
  width: 260,
} as const;

export const Running = () => (
  <div style={col}>
    <KanbanCard
      task={{
        id: "t_run",
        title: "Migrate webhooks to v2 signing",
        status: "running",
        assignee: "coder",
        priority: 2,
        commentCount: 4,
        progressDone: 2,
        progressTotal: 5,
      }}
    />
    <KanbanCard
      task={{
        id: "t_run2",
        title: "Rotate staging certificates",
        status: "running",
        assignee: "ops-assistant-with-a-long-name",
        tenant: "acme",
        progressDone: 0,
        progressTotal: 3,
      }}
    />
  </div>
);

export const Simple = () => (
  <div style={col}>
    <KanbanCard
      task={{
        id: "t_triage",
        title: "Investigate flaky checkout test",
        status: "triage",
        priority: 1,
      }}
    />
    <KanbanCard
      task={{
        id: "t_todo",
        title:
          "Write docs for the webhook signing migration and its rollout plan across every environment we run",
        status: "todo",
        assignee: "writer",
        commentCount: 12,
      }}
    />
    <KanbanCard
      task={{ id: "t_done1", title: "Bump dependencies", status: "done" }}
    />
  </div>
);

export const WithWarnings = () => (
  <div style={col}>
    <KanbanCard
      task={{
        id: "t_rich",
        title:
          "Migrate every outgoing webhook to v2 signing and roll it out across all environments",
        status: "running",
        assignee: "coder",
        priority: 2,
        tenant: "acme",
        commentCount: 12,
        progressDone: 2,
        progressTotal: 5,
        warningCount: 2,
      }}
    />
  </div>
);

export const SelectedWithHandle = () => (
  <div style={{ ...col, width: 360 }}>
    <KanbanCard
      selected
      showHandle
      task={{
        id: "t_run",
        title: "Migrate webhooks",
        status: "running",
        assignee: "coder",
        priority: 2,
        commentCount: 4,
        progressDone: 2,
        progressTotal: 5,
      }}
    />
    <KanbanCard
      showHandle
      task={{
        id: "t_blocked1",
        title: "Upgrade the database",
        status: "blocked",
        assignee: "coder",
      }}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={col}>
      <KanbanCard
        task={{
          id: "t_run",
          title: "Migrate webhooks",
          status: "running",
          assignee: "coder",
          priority: 2,
          commentCount: 4,
          progressDone: 2,
          progressTotal: 5,
        }}
      />
      <KanbanCard
        selected
        task={{
          id: "t_rich",
          title: "Rotate staging certificates",
          status: "review",
          assignee: "ops-assistant",
          tenant: "acme",
          warningCount: 2,
        }}
      />
    </div>
  </HermesProvider>
);
