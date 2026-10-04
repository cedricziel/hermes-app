import { HermesProvider, KanbanTaskPanel } from "@hermes-app/ui";

const running = {
  id: "t_run",
  title: "Migrate webhooks",
  status: "running",
  assignee: "coder",
  priority: 2,
  body: "Move every outgoing webhook to v2 signing.\n\n- endpoints\n- retries\n- docs",
};

const comments = [
  {
    author: "coder",
    when: "2026-05-28",
    body: "Endpoint 1 is done, moving on to the retry queue.",
  },
  {
    author: "writer",
    when: "2026-05-28",
    body: "Docs are drafted: https://example.internal/docs/webhooks/v2/signing-migration",
  },
];

const channels = [
  { name: "Ops chat", platform: "telegram", subscribed: true },
  { name: "Team", platform: "discord", subscribed: false },
];

const attachments = [
  { filename: "spec.pdf", size: 2048 },
  { filename: "screenshot.png", size: 350003 },
];

const runs = [
  {
    id: 6,
    profile: "ops-assistant-with-a-long-name",
    outcome: "crashed",
    detail: "Worker exited with code 137 (out of memory) after 12 seconds",
  },
  { id: 7, profile: "coder", active: true },
];

const events = [
  { kind: "created", when: "3d ago" },
  { kind: "assigned", when: "3d ago" },
  { kind: "status changed", when: "2h ago" },
];

export const Running = () => (
  <div style={{ width: 560 }}>
    <KanbanTaskPanel
      height="auto"
      task={running}
      parents={["t_triage"]}
      comments={comments}
      channels={channels}
      attachments={attachments}
      runs={runs}
      events={events}
    />
  </div>
);

export const TriageWithDiagnostics = () => (
  <div style={{ width: 560 }}>
    <KanbanTaskPanel
      height={640}
      task={{
        id: "t_rich",
        title:
          "Migrate every outgoing webhook to v2 signing and roll it out across all environments",
        status: "triage",
        tenant: "acme",
        modelOverride: "claude-sonnet-5-5",
        reasoningEffort: "High",
        body: "Start with the endpoints that carry payments, then the ones that carry user data.",
      }}
      diagnostics={[
        {
          title: "Worker stalled",
          detail: "No heartbeat for 10m. The process may be hung on a lock.",
          severity: "error",
        },
        { title: "Two parents are still open", severity: "warning" },
      ]}
      estimate={{
        summary: "About 2 hours",
        rationale: "Three endpoints, each with a retry queue and docs.",
      }}
      defaultMoveMenuOpen
    />
  </div>
);

export const RunsOpen = () => (
  <div style={{ width: 560 }}>
    <KanbanTaskPanel
      height="auto"
      task={{
        id: "t_done_result",
        title: "Plan the offline mode",
        status: "done",
        assignee: "researcher",
        result: "Wrote the plan: cache threads on device, queue sends.",
      }}
      subtasks={[
        {
          id: "t_child1",
          title: "Move the account section",
          status: "done",
          summary: "Moved and tested on phone and desktop.",
        },
      ]}
      attachments={attachments}
      runs={[{ id: 3, profile: "researcher", outcome: "completed" }]}
      events={events}
      defaultRunsOpen
      defaultHistoryOpen
    />
  </div>
);

export const LoadingAndError = () => (
  <div style={{ display: "flex", gap: 16 }}>
    <div style={{ width: 300 }}>
      <KanbanTaskPanel state="loading" height={240} />
    </div>
    <div style={{ width: 300 }}>
      <KanbanTaskPanel state="error" height={240} />
    </div>
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ width: 390 }}>
      <KanbanTaskPanel
        frame="sheet"
        height={720}
        task={{ ...running, tenant: "acme", warningCount: 2 }}
        diagnostics={[
          {
            title: "Worker stalled",
            detail: "No heartbeat for 10m.",
            severity: "error",
          },
          { title: "Two parents are still open", severity: "warning" },
        ]}
        comments={comments}
        channels={channels}
      />
    </div>
  </HermesProvider>
);

const sheetFrame = {
  width: 380,
  height: 540,
  position: "relative" as const,
  display: "flex",
  flexDirection: "column" as const,
  background: "var(--h-scrim)",
  overflow: "hidden",
};

/** iPhone: the medium (half) and large detents of the Apple sheet, with the 36x5 grabber and 12px radius. */
export const AppleSheetDetents = () => (
  <HermesProvider platform="apple" style={{ display: "flex", gap: 20 }}>
    <div style={sheetFrame}>
      <KanbanTaskPanel
        frame="sheet"
        detent="medium"
        task={running}
        channels={channels}
      />
    </div>
    <div style={sheetFrame}>
      <KanbanTaskPanel frame="sheet" task={running} channels={channels} />
    </div>
  </HermesProvider>
);

/** iPad and Mac: a 560px form sheet with a 12px radius, and Apple toggles in the Notify section. */
export const AppleFormSheet = () => (
  <HermesProvider platform="apple" style={{ width: 560 }}>
    <KanbanTaskPanel height={540} task={running} channels={channels} />
  </HermesProvider>
);
