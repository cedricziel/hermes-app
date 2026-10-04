import {
  AppShell,
  ChatHeader,
  HermesProvider,
  IconButton,
  KanbanColumn,
  KanbanStatusChips,
  KanbanToolbar,
  ListDetailLayout,
  ShellNavigation,
  StateMessage,
  ThreadSidebar,
  WelcomeView,
} from "@hermes-app/ui";
import type { StarterPromptItem, ThreadItem } from "@hermes-app/ui";

const threads: ThreadItem[] = [
  { id: "logs", title: "Summarize last night's run logs" },
  { id: "release", title: "Draft release notes for v0.9" },
  { id: "pkce", title: "Explain the PKCE flow to a new hire" },
];

const prompts: StarterPromptItem[] = [
  {
    text: "Why did the scheduled job 'Nightly backup' fail on its last run?",
    source: "schedule",
  },
  {
    text: "What's blocking the Kanban task 'Rotate the staging certificates'?",
    source: "kanban",
  },
  { text: "Pick up 'Summarize last night's run logs'", source: "chat" },
  { text: "Use the release-notes skill to ", source: "skill" },
];

const desktop = {
  width: 800,
  height: 560,
  border: "1px solid var(--h-border)",
};
const phone = { width: 390, height: 640, border: "1px solid var(--h-border)" };

/** The Schedules page brings its own bar: title, Refresh and "New" (a "+" in the bar on Apple, a floating button on Material). */
const SchedulesPage = () => (
  <ListDetailLayout
    layout="list"
    title="Schedules"
    actions={<IconButton icon="refresh" label="Refresh" />}
    onAdd={() => {}}
    addLabel="New"
    list={
      <StateMessage
        icon="schedule"
        title="No scheduled tasks yet"
        detail="Ask Hermes to run something on a schedule, such as a nightly backup check."
      />
    }
  />
);

const ChatDesktop = () => (
  <AppShell
    layout="desktop"
    current="chat"
    sidebar={
      <ThreadSidebar
        threads={threads}
        navigation={
          <ShellNavigation
            destinations={["chat", "kanban", "schedules"]}
            current="chat"
          />
        }
      />
    }
  >
    <ChatHeader />
    <WelcomeView prompts={prompts} />
  </AppShell>
);

export const DesktopChat = () => (
  <div style={desktop}>
    <ChatDesktop />
  </div>
);

export const DesktopSchedules = () => (
  <div style={{ ...desktop, height: 380 }}>
    <AppShell layout="desktop" current="schedules">
      <SchedulesPage />
    </AppShell>
  </div>
);

const chatSidebar = (
  <ThreadSidebar
    threads={threads}
    navigation={
      <ShellNavigation
        destinations={["chat", "kanban", "schedules"]}
        current="chat"
      />
    }
  />
);

export const Phone = () => (
  <div style={{ display: "flex", gap: 24 }}>
    <div style={phone}>
      <AppShell layout="phone" current="chat" sidebar={chatSidebar}>
        <ChatHeader layout="phone" />
        <WelcomeView prompts={prompts} />
      </AppShell>
    </div>
    <div style={phone}>
      <AppShell layout="phone" current="chat" sidebar={chatSidebar} drawerOpen>
        <ChatHeader layout="phone" />
        <WelcomeView prompts={prompts} />
      </AppShell>
    </div>
  </div>
);

const KanbanPhonePage = () => (
  <>
    <KanbanToolbar wide={false} assignees={["coder", "reviewer"]} />
    <KanbanStatusChips
      statuses={[
        { name: "triage", count: 1 },
        { name: "todo", count: 2 },
        { name: "running", count: 2 },
        { name: "review", count: 1 },
        { name: "done", count: 7 },
      ]}
      selected="running"
    />
    <KanbanColumn
      variant="list"
      status="running"
      tasks={[
        {
          id: "t_run",
          title: "Migrate webhooks",
          status: "running",
          assignee: "coder",
          priority: 2,
          progressDone: 2,
          progressTotal: 5,
        },
        {
          id: "t_run2",
          title: "Rotate staging certificates",
          status: "running",
          assignee: "reviewer",
          progressDone: 0,
          progressTotal: 3,
        },
      ]}
    />
  </>
);

/** The Kanban board on a phone (left) and the same board with the shell's drawer open over it (right). */
export const PhoneKanbanDrawer = () => (
  <div style={{ display: "flex", gap: 24 }}>
    <div style={phone}>
      <AppShell layout="phone" current="kanban">
        <KanbanPhonePage />
      </AppShell>
    </div>
    <div style={phone}>
      <AppShell layout="phone" current="kanban" drawerOpen>
        <KanbanPhonePage />
      </AppShell>
    </div>
  </div>
);

const macSidebar = (
  <ThreadSidebar
    threads={threads}
    selectedId="logs"
    account="Ada Lovelace"
    navigation={
      <ShellNavigation
        destinations={["chat", "kanban", "schedules"]}
        current="chat"
      />
    }
  />
);

/** The Mac window: sidebar under the traffic lights (78px left free), 52px toolbar header without a rule. */
export const AppleMac = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <AppShell
        layout="desktop"
        current="chat"
        sidebar={macSidebar}
        showTrafficLights
      >
        <ChatHeader title="Summarize last night's run logs" />
        <WelcomeView prompts={prompts} />
      </AppShell>
    </div>
  </HermesProvider>
);

/** The Mac sidebar hidden (Control-Command-S or the toolbar button): the header leaves room for the traffic lights and shows the toggle. */
export const AppleMacSidebarHidden = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <AppShell
        layout="desktop"
        current="chat"
        sidebar={macSidebar}
        sidebarCollapsed
        showTrafficLights
      >
        <ChatHeader title="Summarize last night's run logs" />
        <WelcomeView prompts={prompts} />
      </AppShell>
    </div>
  </HermesProvider>
);

/** Kanban and Schedules get the same Mac sidebar from the plain ShellSidebar. */
export const AppleMacSchedules = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={{ ...desktop, height: 380 }}>
      <AppShell layout="desktop" current="schedules" showTrafficLights>
        <SchedulesPage />
      </AppShell>
    </div>
  </HermesProvider>
);

/** The Mac sidebar hidden on a page without a ChatHeader: the shell draws a 52px toolbar strip with the show-sidebar button. */
export const AppleMacSchedulesSidebarHidden = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={{ ...desktop, height: 380 }}>
      <AppShell
        layout="desktop"
        current="schedules"
        sidebarCollapsed
        showTrafficLights
      >
        <StateMessage
          icon="schedule"
          title="No scheduled tasks yet"
          detail="Ask Hermes to run something on a schedule, such as a nightly backup check."
        />
      </AppShell>
    </div>
  </HermesProvider>
);

/** Full-screen iPad (`device="touch"`): the sidebar sits beside the page, but with the brand row, 44px touch rows and the iOS navigation bar instead of the Mac chrome. */
export const AppleIPad = () => (
  <HermesProvider platform="apple">
    <div style={desktop}>
      <AppShell
        layout="desktop"
        device="touch"
        current="chat"
        sidebar={macSidebar}
      >
        <ChatHeader title="Summarize last night's run logs" />
        <WelcomeView prompts={prompts} />
      </AppShell>
    </div>
  </HermesProvider>
);

const iphone = { ...phone, width: 380 };

/** iPhone: the drawer stays on phones. Nav bar 44px with a centred title; the drawer's thread rows are 44px with a 44px "…" target. */
export const ApplePhone = () => (
  <HermesProvider platform="apple" style={{ display: "flex", gap: 24 }}>
    <div style={iphone}>
      <AppShell layout="phone" current="chat">
        <ChatHeader layout="phone" title="Summarize last night's run logs" />
        <WelcomeView prompts={prompts} />
      </AppShell>
    </div>
    <div style={iphone}>
      <AppShell
        layout="phone"
        current="chat"
        drawerOpen
        sidebar={
          <ThreadSidebar
            layout="phone"
            threads={threads}
            selectedId="logs"
            account="Ada Lovelace"
            navigation={
              <ShellNavigation
                destinations={["chat", "kanban", "schedules"]}
                current="chat"
              />
            }
          />
        }
      >
        <ChatHeader layout="phone" title="Summarize last night's run logs" />
        <WelcomeView prompts={prompts} />
      </AppShell>
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={desktop}>
      <ChatDesktop />
    </div>
  </HermesProvider>
);
