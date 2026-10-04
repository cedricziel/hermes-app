import { HermesProvider, KanbanBulkBar, KanbanToolbar } from "@hermes-app/ui";

const assignees = [
  "writer",
  "ops-assistant-with-a-long-name",
  "reviewer",
  "designer",
  "coder",
];
const tenants = ["acme", "mobile"];
const boards = [
  { slug: "default", name: "Default", total: 12 },
  { slug: "platform", name: "Platform", total: 34 },
  { slug: "mobile", name: "Mobile app", total: 7 },
];

export const Desktop = () => (
  <div style={{ width: 760 }}>
    <KanbanToolbar
      assignees={assignees}
      tenants={tenants}
      boards={boards}
      board="default"
    />
  </div>
);

export const AssigneeMenuOpen = () => (
  <div style={{ width: 760, height: 470 }}>
    <KanbanToolbar
      assignees={assignees}
      tenants={tenants}
      tenant="acme"
      includeArchived
      defaultOpenMenu="assignee"
    />
  </div>
);

export const PhoneRefreshFailed = () => (
  <div style={{ width: 390 }}>
    <KanbanToolbar
      wide={false}
      live={false}
      refreshFailed
      assignees={assignees}
      tenants={tenants}
      boards={boards}
    />
  </div>
);

const screen = {
  width: 760,
  height: 400,
  display: "flex",
  flexDirection: "column",
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

export const Selection = () => (
  <div style={screen}>
    <KanbanToolbar selectedCount={3} assignees={assignees} tenants={tenants} />
    <div style={{ flex: 1 }} />
    <KanbanBulkBar selectedCount={3} />
  </div>
);

export const BulkBarNoneSelected = () => (
  <div style={{ ...screen, height: "auto" }}>
    <KanbanBulkBar selectedCount={0} />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ width: "100%", maxWidth: 760, height: 300 }}>
      <KanbanToolbar
        assignees={assignees}
        tenants={tenants}
        boards={boards}
        board="platform"
        defaultOpenMenu="board"
      />
    </div>
  </HermesProvider>
);

const appleFrame = { ...screen, width: 380, height: 260 } as const;

/** Apple: the iOS search field (left) and, in selection mode, the 44px icon-and-label bulk toolbar pinned to the bottom of the screen (right). */
export const AppleSearchAndBulkBar = () => (
  <HermesProvider platform="apple" style={{ display: "flex", gap: 20 }}>
    <div style={appleFrame}>
      <KanbanToolbar wide={false} assignees={assignees} tenants={tenants} />
    </div>
    <div style={appleFrame}>
      <KanbanToolbar
        wide={false}
        selectedCount={3}
        assignees={assignees}
        tenants={tenants}
      />
      <div style={{ flex: 1 }} />
      <KanbanBulkBar selectedCount={3} />
    </div>
  </HermesProvider>
);
