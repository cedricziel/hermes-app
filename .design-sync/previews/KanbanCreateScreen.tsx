import { HermesProvider, KanbanCreateScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 560 } as const;
const pair = { display: "flex", gap: 12, alignItems: "flex-start" } as const;
const noop = () => {};

const assignees = ["coder", "writer", "reviewer"];

/** iPhone: Cancel and Create in the bar; a typed task with an assignee, a picked model and effort, P2, starting in Todo. */
export const ApplePhone = () => (
  <HermesProvider platform="apple" style={phone}>
    <KanbanCreateScreen
      board="default"
      title="Rotate the staging certificates"
      description="Renew the wildcard cert and roll the ingress pods."
      assignees={assignees}
      assignee="coder"
      model="claude-opus-4"
      effort="High"
      priority={2}
      triage={false}
      onBack={noop}
    />
  </HermesProvider>
);

/** Android: an empty form (close X, floating labels, "Estimate the work" greyed out) with the assignee menu open. */
export const MaterialPhone = () => (
  <HermesProvider platform="material" style={phone}>
    <KanbanCreateScreen
      board="default"
      assignees={assignees}
      defaultOpen="assignee"
      onBack={noop}
    />
  </HermesProvider>
);

/** A Mac window: back button and the small filled Create in the toolbar, pop-up buttons for Assignee and Model, the estimate under its row. */
export const MacWindow = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <KanbanCreateScreen
      device="mac"
      board="default"
      title="Write the release notes"
      assignees={assignees}
      estimate="About 1 hour: collect the merged PRs and group them."
      onBack={noop}
    />
  </HermesProvider>
);

/** The plugin lists no models: a typed model name with its footer. Estimating, P1. */
export const NoModelList = () => (
  <HermesProvider platform="material" style={phone}>
    <KanbanCreateScreen
      title="Backfill usage metrics"
      assignees={assignees}
      modelField="freeText"
      modelName="gpt-5-mini"
      estimating
      priority={1}
      onBack={noop}
    />
  </HermesProvider>
);

export const Dark = () => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider
        key={platform}
        theme="dark"
        platform={platform}
        style={phone}
      >
        <KanbanCreateScreen
          title="Review the settings layout"
          assignees={assignees}
          assignee="reviewer"
          onBack={noop}
        />
      </HermesProvider>
    ))}
  </div>
);
