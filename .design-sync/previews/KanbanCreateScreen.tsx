import { AppShell, HermesProvider, KanbanCreateScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;

const desktop = {
  width: 800,
  height: 560,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;

const assignees = ["coder", "writer", "reviewer"];

/** iPhone: a typed task with an assignee, a picked model and effort, P2, starting in Todo. */
export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <KanbanCreateScreen
        title="Rotate the staging certificates"
        description="Renew the wildcard cert and roll the ingress pods."
        assignees={assignees}
        assignee="coder"
        model="claude-opus-4"
        effort="High"
        priority={2}
        triage={false}
      />
    </div>
  </HermesProvider>
);

/** Android: an empty form with the assignee dropdown open. */
export const MaterialPhone = () => (
  <div style={phone}>
    <KanbanCreateScreen assignees={assignees} defaultOpen="assignee" />
  </div>
);

/** Mac window: the form at most 560px wide, centred beside the sidebar. */
export const MacWindow = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <AppShell
        layout="desktop"
        current="kanban"
        showTrafficLights
        sidebarWidth={220}
        account="Ada Lovelace"
      >
        <KanbanCreateScreen
          layout="desktop"
          title="Write the release notes"
          assignees={assignees}
          estimate="About 1 hour: collect the merged PRs and group them."
        />
      </AppShell>
    </div>
  </HermesProvider>
);

/** The plugin lists no models: a typed model name instead of the pill. Estimating. */
export const NoModelList = () => (
  <div style={phone}>
    <KanbanCreateScreen
      title="Backfill usage metrics"
      assignees={assignees}
      modelField="freeText"
      modelName="gpt-5-mini"
      estimating
      priority={1}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ width: "fit-content" }}>
    <div style={phone}>
      <KanbanCreateScreen
        title="Review the settings layout"
        assignees={assignees}
        assignee="reviewer"
      />
    </div>
  </HermesProvider>
);
