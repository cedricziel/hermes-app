import {
  AppShell,
  ChatHeader,
  HermesProvider,
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
const phone = { width: 390, height: 760, border: "1px solid var(--h-border)" };

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
      <StateMessage
        icon="schedule"
        title="No scheduled tasks yet"
        detail="Ask Hermes to run something on a schedule, such as a nightly backup check."
      />
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

export const PhoneKanbanDrawer = () => (
  <div style={phone}>
    <AppShell layout="phone" current="kanban" drawerOpen>
      <StateMessage
        icon="view_kanban"
        title="No tasks on this board"
        detail="Tasks you or Hermes create show up here."
      />
    </AppShell>
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
        <StateMessage
          icon="schedule"
          title="No scheduled tasks yet"
          detail="Ask Hermes to run something on a schedule, such as a nightly backup check."
        />
      </AppShell>
    </div>
  </HermesProvider>
);

const iphone = { width: 380, height: 700, border: "1px solid var(--h-border)" };

/** iPhone: the drawer stays on phones. Nav bar 44px with a centred title; the drawer's thread rows are 44px with no inline "…". */
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
