import { ChatThread, HermesProvider } from "@hermes-app/ui";
import type { ChatTurn } from "@hermes-app/ui";

const box = { width: 720, height: 520, display: "flex" } as const;

const turns: ChatTurn[] = [
  { role: "user", text: "Why did the nightly backup fail?" },
  {
    role: "assistant",
    reasoning:
      "The user asks about last night's run. Check the unit's journal first, then the timer.",
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
    text: "`restic` could not reach **nas-02** at 03:00: the NAS was still rebooting after its update. Moving the backup to 03:30 avoids the window.",
    reviewNotes: ["Memory updated"],
  },
];

/** A finished reply: reasoning, text before the tools, the folded tool run, the answer with Copy, Try again and Edit prompt, and what the background review saved. */
export const Reply = () => (
  <div style={box}>
    <ChatThread turns={turns} onRetry={() => {}} onEdit={() => {}} />
  </div>
);

/** Waiting on the user: an approval, then a reply still thinking. */
export const Waiting = () => (
  <div style={box}>
    <ChatThread
      turns={[
        { role: "user", text: "Restart the backup now, please." },
        {
          role: "assistant",
          approval: {
            description: "Hermes wants to run a command on the server.",
            command: "sudo systemctl restart backup.service",
            choices: ["once", "session", "always", "deny"],
          },
        },
        { role: "user", text: "Also check the NAS update schedule." },
        {
          role: "assistant",
          thinking: { elapsedSeconds: 12, activity: "Reading the NAS logs" },
        },
      ]}
    />
  </div>
);

/** Apple, a failed reply with the error under what arrived. */
export const AppleFailed = () => (
  <HermesProvider platform="apple">
    <div style={box}>
      <ChatThread
        turns={[
          { role: "user", text: "Summarize last night's run logs" },
          {
            role: "assistant",
            text: "Three jobs ran overnight; the backup",
            error: "The connection to Hermes was lost.",
          },
        ]}
        onRetry={() => {}}
      />
    </div>
  </HermesProvider>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ ...box, width: 680, height: 480 }}>
      <ChatThread turns={turns} onRetry={() => {}} onEdit={() => {}} />
    </div>
  </HermesProvider>
);
