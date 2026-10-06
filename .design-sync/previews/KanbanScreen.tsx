import {
  AppShell,
  HermesProvider,
  KanbanScreen,
  ShellNavigation,
  ThreadSidebar,
} from "@hermes-app/ui";
import type { KanbanBoardColumn, KanbanBoardItem } from "@hermes-app/ui";

const columns: KanbanBoardColumn[] = [
  {
    name: "triage",
    tasks: [
      {
        id: "t_tri1",
        title: "Investigate flaky login test",
        status: "triage",
        tenant: "mobile",
      },
    ],
  },
  {
    name: "todo",
    tasks: [
      {
        id: "t_todo",
        title: "Write the release notes",
        status: "todo",
        assignee: "writer",
      },
      {
        id: "t_todo2",
        title: "Rotate the staging certificates",
        status: "todo",
        priority: 1,
        commentCount: 2,
      },
    ],
  },
  {
    name: "running",
    tasks: [
      {
        id: "t_run",
        title: "Migrate webhooks to v2 signing",
        status: "running",
        assignee: "coder",
        priority: 2,
        commentCount: 4,
        progressDone: 2,
        progressTotal: 5,
      },
      {
        id: "t_run2",
        title: "Backfill usage metrics",
        status: "running",
        assignee: "coder",
        warningCount: 1,
      },
    ],
  },
  {
    name: "review",
    tasks: [
      {
        id: "t_review",
        title: "Review the settings layout",
        status: "review",
        assignee: "reviewer",
      },
    ],
  },
  {
    name: "done",
    tasks: [{ id: "t_done", title: "Bump dependencies", status: "done" }],
  },
];

const empty: KanbanBoardColumn[] = columns.map((c) => ({
  name: c.name,
  tasks: [],
}));

const boards: KanbanBoardItem[] = [
  { slug: "default", name: "Default", total: 7 },
  { slug: "ops", name: "Ops", total: 1 },
];

const board = {
  columns,
  boards,
  board: "default",
  assignees: ["coder", "writer", "reviewer"],
  tenants: ["mobile"],
};

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

const navigation = (
  <ShellNavigation
    destinations={["chat", "kanban", "schedules"]}
    current="kanban"
  />
);

/** iPhone: iOS search field, status chips over the Running list, the floating "New task" button. */
export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <AppShell layout="phone" current="kanban">
        <KanbanScreen
          layout="phone"
          {...board}
          shownStatus="running"
          onOpenMenu={() => {}}
        />
      </AppShell>
    </div>
  </HermesProvider>
);

/** Android: the same board with Material chrome and the "…" menu open. */
export const MaterialPhone = () => (
  <div style={phone}>
    <AppShell layout="phone" current="kanban">
      <KanbanScreen
        layout="phone"
        {...board}
        shownStatus="todo"
        defaultOpenMenu="more"
        onOpenMenu={() => {}}
      />
    </AppShell>
  </div>
);

/** Desktop (Linux, Windows): the shell's sidebar beside 260px columns that scroll sideways. */
export const Desktop = () => (
  <div style={desktop}>
    <AppShell layout="desktop" current="kanban" account="Ada Lovelace">
      <KanbanScreen {...board} />
    </AppShell>
  </div>
);

/** Mac window, dark: the Mac toolbar (live dot, New Task, profile filter, board menu, inspector toggle, "…") over the columns, the open task in the 380px inspector, over the board from the right as the window is narrower than 760px. */
export const MacInspectorDark = () => (
  <HermesProvider
    theme="dark"
    platform="apple"
    typeRamp="default"
    style={{ width: "fit-content" }}
  >
    <div style={desktop}>
      <AppShell
        layout="desktop"
        current="kanban"
        showTrafficLights
        sidebarWidth={220}
        sidebar={
          <ThreadSidebar
            threads={[
              { id: "logs", title: "Summarize last night's run logs" },
              { id: "notes", title: "Draft release notes for v0.9" },
            ]}
            account="Ada Lovelace"
            navigation={navigation}
          />
        }
      >
        <KanbanScreen
          {...board}
          openTaskId="t_run"
          openTask={{
            task: {
              ...columns[2].tasks[0],
              body: "Move every endpoint to the v2 signature scheme.",
            },
            comments: [
              {
                author: "coder",
                when: "3h ago",
                body: "Endpoint 1 done, starting on the second.",
              },
            ],
            runs: [{ id: 7, profile: "coder", active: true }],
          }}
        />
      </AppShell>
    </div>
  </HermesProvider>
);

/** iPhone selection mode: "2 selected" with a close button, picked cards outlined, the 44px bulk toolbar at the bottom. */
export const AppleSelecting = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <KanbanScreen
        layout="phone"
        {...board}
        shownStatus="running"
        selectedIds={["t_run", "t_run2"]}
      />
    </div>
  </HermesProvider>
);

/** iPhone: a task open in the Apple sheet at the medium detent over the board. */
export const AppleTaskSheet = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <KanbanScreen
        layout="phone"
        {...board}
        shownStatus="running"
        openTaskId="t_run"
        openTask={{
          detent: "medium",
          task: {
            ...columns[2].tasks[0],
            body: "Move every endpoint to the v2 signature scheme.",
          },
        }}
      />
    </div>
  </HermesProvider>
);

const third = { ...phone, width: 260, height: 460 } as const;

/** A board with no tasks (every chip at 0, "No tasks here"), the first load, and a failed load with Retry. */
export const EmptyLoadingError = () => (
  <div style={{ display: "flex", gap: 12 }}>
    <div style={third}>
      <KanbanScreen
        layout="phone"
        columns={empty}
        boards={boards}
        board="default"
        onOpenMenu={() => {}}
      />
    </div>
    <div style={third}>
      <KanbanScreen layout="phone" state="loading" onOpenMenu={() => {}} />
    </div>
    <div style={third}>
      <KanbanScreen layout="phone" state="error" onOpenMenu={() => {}} />
    </div>
  </div>
);

/** Mac window with the sidebar hidden: the board is 760px or wider, so the inspector is docked beside it and says "No task selected" until a card is clicked. */
export const MacDocked = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <AppShell
        layout="desktop"
        current="kanban"
        showTrafficLights
        sidebarCollapsed
      >
        <KanbanScreen {...board} assignee="coder" />
      </AppShell>
    </div>
  </HermesProvider>
);
