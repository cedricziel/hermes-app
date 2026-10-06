import { AppShell, HermesProvider, KanbanWorkersScreen } from "@hermes-app/ui";
import type { KanbanWorkerItem } from "@hermes-app/ui";

const workers: KanbanWorkerItem[] = [
  {
    runId: 7,
    taskId: "t_run",
    taskTitle: "Migrate webhooks to v2 signing",
    profile: "coder",
    started: "3 min ago",
    heartbeat: "20 s ago",
  },
  {
    runId: 9,
    taskId: "t_run2",
    taskTitle: "Backfill usage metrics",
    profile: "coder",
    started: "1 h ago",
    heartbeat: "6 min ago",
  },
];

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  overflow: "hidden",
} as const;

const small = { ...phone, width: 250, height: 360 } as const;

/** iPhone: two workers with wrapping details, chevron back with "Kanban". */
export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <KanbanWorkersScreen workers={workers} />
    </div>
  </HermesProvider>
);

/** Android: a worker's menu open (Inspect process, Terminate). */
export const MaterialPhone = () => (
  <div style={phone}>
    <KanbanWorkersScreen workers={workers} defaultMenuRun={7} />
  </div>
);

/** Desktop beside the shell's sidebar. */
export const Desktop = () => (
  <div
    style={{
      width: 800,
      height: 480,
      border: "1px solid var(--h-border)",
      overflow: "hidden",
    }}
  >
    <AppShell layout="desktop" current="kanban" account="Ada Lovelace">
      <KanbanWorkersScreen workers={workers} layout="desktop" />
    </AppShell>
  </div>
);

/** No workers, loading, and a failed load with Retry. */
export const EmptyLoadingError = () => (
  <div style={{ display: "flex", gap: 16 }}>
    <div style={small}>
      <KanbanWorkersScreen workers={[]} />
    </div>
    <div style={small}>
      <KanbanWorkersScreen state="loading" />
    </div>
    <div style={small}>
      <KanbanWorkersScreen state="error" />
    </div>
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ width: "fit-content" }}>
    <div style={{ ...phone, height: 360 }}>
      <KanbanWorkersScreen workers={workers} />
    </div>
  </HermesProvider>
);
