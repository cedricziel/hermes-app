import { ChatScreen, HermesProvider } from "@hermes-app/ui";
import type { ChatTurn, StarterPromptItem, ThreadItem } from "@hermes-app/ui";

const now = "2026-10-04T12:00:00";

const threads: ThreadItem[] = [
  {
    id: "release",
    title: "Plan the release",
    pinned: true,
    updatedAt: "2026-10-02T16:00:00",
  },
  {
    id: "backup",
    title: "Why did the nightly backup fail?",
    updatedAt: "2026-10-04T08:40:00",
  },
  {
    id: "login",
    title: "Fix the flaky login test",
    updatedAt: "2026-10-03T10:15:00",
  },
  {
    id: "photos",
    title: "Compare the backup providers for the photo library",
    updatedAt: "2026-09-20T09:00:00",
  },
  {
    id: "onboarding",
    title: "Draft the onboarding email",
    updatedAt: "2026-08-11T14:00:00",
  },
];

const turns: ChatTurn[] = [
  { role: "user", text: "Why did the nightly backup fail?" },
  {
    role: "assistant",
    prose: "I'll check the backup service's log and its timer first.",
    toolCalls: [
      {
        name: "terminal",
        summary: "journalctl -u backup --since yesterday",
        status: "completed",
        duration: "1.2s",
      },
      {
        name: "read_file",
        summary: "/etc/backup.timer",
        status: "completed",
        duration: "0.1s",
      },
    ],
    text: "The backup ran at **03:00** but `restic` could not reach **nas-02**: the NAS was still rebooting after its 02:55 update.\n\n- The timer and the repository are fine.\n- Moving the backup to 03:30 avoids the update window.",
  },
  { role: "user", text: "Restart the backup now, please." },
  {
    role: "assistant",
    approval: {
      description: "Hermes wants to run a command on the server.",
      command: "sudo systemctl restart backup.service",
      choices: ["once", "session", "always", "deny"],
    },
  },
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
  { text: "Pick up 'Plan the release'", source: "chat" },
  { text: "Use the release-notes skill to ", source: "skill" },
];

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

const loaded = {
  threads,
  selectedId: "backup",
  turns,
  now,
  profile: "default",
  account: "Ada Lovelace",
  serverUrl: "https://hermes.example.net",
  model: { model: "claude-opus-4", effort: "Medium" },
};

/** iPhone: 44px navigation bar with the centred title, the thread with a tool-call run and an approval waiting, the composer at the bottom. */
export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <ChatScreen {...loaded} layout="phone" />
    </div>
  </HermesProvider>
);

/** Material phone: 64px app bar with the menu button that opens the drawer. */
export const MaterialPhone = () => (
  <div style={phone}>
    <ChatScreen {...loaded} layout="phone" />
  </div>
);

/** Mac window: the sidebar as a source list under the traffic lights (recency sections), the 52px toolbar header, the 680px chat column. */
export const AppleMac = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={desktop}>
      <ChatScreen {...loaded} showTrafficLights windowSize="medium" />
    </div>
  </HermesProvider>
);

/** Material desktop (Windows, Linux): the 280px sidebar beside the chat. */
export const MaterialDesktop = () => (
  <div style={desktop}>
    <ChatScreen {...loaded} />
  </div>
);

/** No chat open: the welcome view with starter prompts from the profile's context. */
export const Welcome = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <ChatScreen
        threads={threads}
        now={now}
        prompts={prompts}
        greetingName="Ada"
        layout="phone"
      />
    </div>
  </HermesProvider>
);

/** Loading the chats (left, Apple phone: the app bar stays for the drawer) and failed to load them (right, Material desktop: no sidebar yet). */
export const LoadingAndFailed = () => (
  <div style={{ display: "flex", gap: 24 }}>
    <HermesProvider platform="apple">
      <div style={{ ...phone, width: 300, height: 480 }}>
        <ChatScreen state="loading" layout="phone" />
      </div>
    </HermesProvider>
    <div style={{ ...desktop, width: 480, height: 480 }}>
      <ChatScreen state="failed" />
    </div>
  </div>
);

/** Dark, Material desktop, a reply in progress: Stop instead of send. */
export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ ...desktop, width: 768, height: 528 }}>
      <ChatScreen
        {...loaded}
        replying
        turns={[
          ...turns.slice(0, 3),
          {
            role: "assistant",
            toolCalls: [
              {
                name: "terminal",
                summary: "systemctl restart backup.service",
                status: "running",
              },
            ],
          },
        ]}
      />
    </div>
  </HermesProvider>
);
