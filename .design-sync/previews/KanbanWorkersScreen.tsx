import { HermesProvider, KanbanWorkersScreen } from "@hermes-app/ui";
import type { KanbanWorkerItem } from "@hermes-app/ui";

const workers: KanbanWorkerItem[] = [
  {
    runId: 7,
    taskId: "t_run",
    taskTitle: "Migrate webhooks to v2 signing",
    profile: "coder",
    started: "12m ago",
    heartbeat: "Just now",
  },
  {
    runId: 9,
    taskId: "t_notes",
    taskTitle: "Write the release notes",
    profile: "writer",
    started: "3m ago",
  },
];

const phone = {
  width: 390,
  height: 560,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;
const desktop = { ...phone, width: 800, height: 420 } as const;
const small = { ...phone, width: 260, height: 320 } as const;
const pair = { display: "flex", gap: 12, alignItems: "flex-start" } as const;
const noop = () => {};

/** iPhone: the title over "2 running", Refresh in the bar; each row's task, run and profile, then start and heartbeat; the iOS pull-down of a row open. */
export const ApplePhone = () => (
  <HermesProvider platform="apple" style={phone}>
    <KanbanWorkersScreen workers={workers} defaultMenuRun={7} onBack={noop} />
  </HermesProvider>
);

/** Android: a worker's "⋮" popup open (Inspect process, Terminate). */
export const MaterialPhone = () => (
  <HermesProvider platform="material" style={phone}>
    <KanbanWorkersScreen workers={workers} defaultMenuRun={7} onBack={noop} />
  </HermesProvider>
);

/** A Mac window: the 52px toolbar, 13px rows in the centred 600px column. */
export const Desktop = () => (
  <HermesProvider platform="apple" typeRamp="default" style={desktop}>
    <KanbanWorkersScreen device="mac" workers={workers} onBack={noop} />
  </HermesProvider>
);

/** No workers, loading, and a failed load with Retry. */
export const EmptyLoadingError = () => (
  <div style={pair}>
    <HermesProvider platform="apple" style={small}>
      <KanbanWorkersScreen workers={[]} onBack={noop} />
    </HermesProvider>
    <HermesProvider platform="apple" style={small}>
      <KanbanWorkersScreen state="loading" onBack={noop} />
    </HermesProvider>
    <HermesProvider platform="material" style={small}>
      <KanbanWorkersScreen state="error" onBack={noop} />
    </HermesProvider>
  </div>
);

export const Dark = () => (
  <div style={pair}>
    {(["apple", "material"] as const).map((platform) => (
      <HermesProvider
        key={platform}
        theme="dark"
        platform={platform}
        style={{ ...phone, height: 360 }}
      >
        <KanbanWorkersScreen workers={workers} onBack={noop} />
      </HermesProvider>
    ))}
  </div>
);
