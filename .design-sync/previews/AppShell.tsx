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

export const Phone = () => (
  <div style={{ display: "flex", gap: 24 }}>
    <div style={phone}>
      <AppShell layout="phone" current="chat">
        <ChatHeader layout="phone" />
        <WelcomeView prompts={prompts} />
      </AppShell>
    </div>
    <div style={phone}>
      <AppShell
        layout="phone"
        current="kanban"
        destinations={["chat", "kanban"]}
      >
        <StateMessage
          icon="view_kanban"
          title="No tasks on this board"
          detail="Tasks you or Hermes create show up here."
        />
      </AppShell>
    </div>
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={desktop}>
      <ChatDesktop />
    </div>
  </HermesProvider>
);
