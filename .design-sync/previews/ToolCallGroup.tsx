import { ToolCallGroup, HermesProvider } from "@hermes-app/ui";

const box = { width: 640 } as const;

const finishedRun = [
  { name: "terminal", summary: "journalctl -u backup", duration: "0.3s" },
  { name: "read_file", summary: "/etc/backup.timer", duration: "0.1s" },
  { name: "edit_file", summary: "/etc/backup.timer", duration: "0.2s" },
];

export const Finished = () => (
  <div style={box}>
    <ToolCallGroup calls={finishedRun} />
  </div>
);

/** Apple: the group line and each card header are 44px tall. */
export const ApplePlatform = () => (
  <HermesProvider platform="apple" style={box}>
    <ToolCallGroup calls={finishedRun} defaultOpen />
  </HermesProvider>
);

export const Opened = () => (
  <div style={box}>
    <ToolCallGroup calls={finishedRun} defaultOpen />
  </div>
);

export const Running = () => (
  <div style={{ ...box, display: "flex", flexDirection: "column", gap: 8 }}>
    <ToolCallGroup
      calls={[
        { name: "terminal", summary: "journalctl -u backup", duration: "0.3s" },
        { name: "read_file", summary: "/etc/backup.timer", status: "running" },
      ]}
    />
    <ToolCallGroup
      calls={[
        { name: "terminal", summary: "ping nas-02", duration: "1.2s" },
        {
          name: "restic_run",
          status: "error",
          result: "connection reset by peer",
        },
      ]}
    />
    <ToolCallGroup
      calls={[
        { name: "terminal", summary: "ping nas-02", status: "cancelled" },
        { name: "restic_run", status: "cancelled" },
      ]}
    />
  </div>
);

export const WaitingOnApproval = () => (
  <div style={box}>
    <ToolCallGroup
      calls={[
        { name: "read_file", summary: "Makefile", duration: "0.1s" },
        {
          name: "terminal",
          summary: "rm -rf build",
          status: "running",
          approval: {
            description: "Delete the build folder",
            command: "rm -rf build",
            choices: ["once", "session", "always", "deny"],
            onAnswer: () => {},
          },
        },
      ]}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ ...box, display: "flex", flexDirection: "column", gap: 8 }}>
      <ToolCallGroup calls={finishedRun} />
      <ToolCallGroup calls={finishedRun} defaultOpen />
    </div>
  </HermesProvider>
);
