import { ToolCallCard, HermesProvider } from "@hermes-app/ui";

const col = {
  width: 640,
  display: "flex",
  flexDirection: "column",
  gap: 8,
} as const;

export const States = () => (
  <div style={col}>
    <ToolCallCard
      name="terminal"
      summary="flutter test"
      status="running"
      duration="12s"
    />
    <ToolCallCard name="terminal" status="running" preparing />
    <ToolCallCard
      name="read_file"
      summary="lib/main.dart"
      duration="0.4s"
      input={'{\n  "path": "lib/main.dart"\n}'}
      result={"void main() {\n  runApp(const App());\n}"}
    />
    <ToolCallCard
      name="web_search"
      summary="flutter widgetbook"
      status="error"
      result="Request timed out after 30 s"
    />
    <ToolCallCard
      name="terminal"
      summary="restic backup /srv"
      status="cancelled"
      duration="1m 14s"
    />
  </div>
);

export const Opened = () => (
  <div style={col}>
    <ToolCallCard
      name="read_file"
      summary="lib/main.dart"
      duration="0.4s"
      defaultOpen
      input={'{\n  "path": "lib/main.dart"\n}'}
      result={"void main() {\n  runApp(const App());\n}"}
    />
    <ToolCallCard
      name="terminal"
      summary="systemctl status backup"
      status="error"
      duration="0.2s"
      defaultOpen
      body={{
        kind: "terminal",
        command: "systemctl status backup",
        output:
          "backup.service - Nightly backup\n   Active: failed (Result: exit-code)",
        exitCode: 3,
      }}
    />
  </div>
);

export const ToolViews = () => (
  <div style={col}>
    <ToolCallCard
      name="web_search"
      summary="restic connection reset by peer"
      duration="2.3s"
      defaultOpen
      body={{
        kind: "web_search",
        hits: [
          {
            title: 'Backups fail with "connection reset by peer"',
            url: "https://forum.restic.net/t/connection-reset/4512",
            description:
              "Raising the backend timeout and limiting connections fixed it.",
          },
          {
            title: "Tuning restic for flaky links",
            url: "https://restic.readthedocs.io/en/stable/tuning.html",
            description: "Options for retries, connections and pack size.",
          },
        ],
      }}
    />
    <ToolCallCard
      name="todo_list"
      defaultOpen
      body={{
        kind: "todo",
        items: [
          { content: "Read the backup logs", status: "completed" },
          { content: "Raise the retry cap", status: "in_progress" },
          { content: "Open a PR", status: "pending" },
          { content: "Page the on-call", status: "cancelled" },
        ],
      }}
    />
    <ToolCallCard
      name="patch"
      summary="/etc/backup.timer"
      duration="0.1s"
      defaultOpen
      body={{
        kind: "diff",
        diff: "a/etc/backup.timer → b/etc/backup.timer\n@@ -3,3 +3,3 @@\n [Timer]\n-OnCalendar=*-*-* 02:00\n+OnCalendar=*-*-* 03:30\n Persistent=true",
      }}
    />
  </div>
);

export const ApprovalPending = () => (
  <div style={col}>
    <ToolCallCard
      name="terminal"
      summary="backup-agent pin-cert --from /etc/ssl/certs/staging-2026-09.pem"
      status="running"
      duration="0s"
      approval={{
        description: "Replace the pinned certificate the backup agent trusts",
        command:
          "backup-agent pin-cert --from /etc/ssl/certs/staging-2026-09.pem",
        choices: ["once", "session", "always", "deny"],
        status: "pending",
        onAnswer: () => {},
      }}
    />
  </div>
);

export const ApprovalAnswered = () => (
  <div style={col}>
    <ToolCallCard
      name="terminal"
      summary="rm -rf build"
      duration="0.7s"
      defaultOpen
      body={{ kind: "terminal", command: "rm -rf build", output: "" }}
      approval={{
        description: "Delete the build folder",
        command: "rm -rf build",
        status: "answered",
        choice: "once",
      }}
    />
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={col}>
      <ToolCallCard
        name="terminal"
        summary="journalctl -u backup"
        status="running"
        duration="4s"
      />
      <ToolCallCard
        name="patch"
        summary="/etc/backup.timer"
        duration="0.1s"
        defaultOpen
        body={{
          kind: "diff",
          diff: "a/etc/backup.timer → b/etc/backup.timer\n@@ -3,3 +3,3 @@\n [Timer]\n-OnCalendar=*-*-* 02:00\n+OnCalendar=*-*-* 03:30\n Persistent=true",
        }}
      />
      <ToolCallCard
        name="terminal"
        summary="rm -rf build"
        status="running"
        approval={{
          description: "Delete the build folder",
          command: "rm -rf build",
          choices: ["once", "session", "always", "deny"],
          onAnswer: () => {},
        }}
      />
    </div>
  </HermesProvider>
);
