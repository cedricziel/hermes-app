import { HermesProvider, KanbanTaskChoiceDialog } from "@hermes-app/ui";

const phone = {
  position: "relative",
  width: 390,
  height: 460,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
  background: "var(--h-bg)",
} as const;
const mac = { ...phone, width: 640, height: 380 } as const;
const row = { display: "flex", gap: 16, alignItems: "flex-start" } as const;
const noop = () => {};

const assignees = ["Nobody", "research", "writer", "ops"];
const priorities = ["Normal", "P1", "P2", "P3"];

/** Mac: the task panel's Assignee chooser over the dimmed window, the current worker checked. */
export const Mac = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={mac}>
      <KanbanTaskChoiceDialog title="Assignee" options={assignees} selected={2} device="mac" onPick={noop} onDone={noop} />
    </div>
  </HermesProvider>
);

/** iPhone and Material: the Priority chooser in the touch dialog (title centred, Done) and the Material dialog (no Done). */
export const IPhoneAndMaterial = () => (
  <div style={row}>
    <HermesProvider platform="apple">
      <div style={phone}>
        <KanbanTaskChoiceDialog title="Priority" options={priorities} selected={0} onPick={noop} onDone={noop} />
      </div>
    </HermesProvider>
    <HermesProvider>
      <div style={phone}>
        <KanbanTaskChoiceDialog title="Priority" options={priorities} selected={1} onPick={noop} onDone={noop} />
      </div>
    </HermesProvider>
  </div>
);

/** Mac, dark, nobody assigned yet. */
export const Dark = () => (
  <HermesProvider platform="apple" typeRamp="default" theme="dark">
    <div style={mac}>
      <KanbanTaskChoiceDialog title="Assignee" options={assignees} selected={0} device="mac" onPick={noop} onDone={noop} />
    </div>
  </HermesProvider>
);
