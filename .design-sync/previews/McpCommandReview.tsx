import { HermesProvider, McpCommandReview, Sheet } from "@hermes-app/ui";

const frame = {
  position: "relative",
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
  background: "var(--h-bg)",
} as const;

const notes = {
  name: "notes-fs",
  command: "npx",
  args: ["-y", "@modelcontextprotocol/server-filesystem", "/srv/notes"],
  envNames: ["FS_TOKEN"],
};

/** One server, from the Add server form, in a phone's bottom sheet. */
export const OneServerSheet = () => (
  <div style={frame}>
    <Sheet padding={0}>
      <McpCommandReview
        commands={[notes]}
        confirmLabel="Add and run on server"
      />
    </Sheet>
  </div>
);

/** Two servers from a JSON save, in the 520px dialog used from 900px. */
export const TwoServersDialog = () => (
  <div style={{ ...frame, width: 800, height: 560 }}>
    <Sheet presentation="dialog" width={520} padding={0}>
      <McpCommandReview
        commands={[
          { name: "time", command: "uvx", args: ["mcp-server-time"] },
          {
            name: "buildkite",
            command: "node",
            args: ["dist/index.js --stdio"],
            cwd: "/opt/mcp/buildkite",
            envNames: ["BUILDKITE_API_TOKEN"],
          },
        ]}
        confirmLabel="Save and run on server"
      />
    </Sheet>
  </div>
);

export const Dark = () => (
  <HermesProvider
    theme="dark"
    platform="apple"
    style={{ padding: 16, borderRadius: 14 }}
  >
    <div style={frame}>
      <Sheet padding={0}>
        <McpCommandReview
          commands={[notes]}
          confirmLabel="Add and run on server"
        />
      </Sheet>
    </div>
  </HermesProvider>
);
