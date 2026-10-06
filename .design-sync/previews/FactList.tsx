import { Card, FactList, HermesProvider } from "@hermes-app/ui";

const pane = { width: 440 } as const;

/** The install panel's "What Hermes will run" for an entry built on the server. */
export const BuiltOnServer = () => (
  <div style={pane}>
    <Card padding={12}>
      <FactList
        facts={[
          { label: "type", value: "command (stdio)" },
          { label: "command", value: "node" },
          { label: "args", value: "dist/index.js --stdio" },
          {
            label: "repository",
            value: "https://github.com/buildkite/mcp-server",
          },
          { label: "ref", value: "v1.2.0" },
          { label: "steps", value: "npm ci" },
          { label: "", value: "npm run build" },
        ]}
      />
    </Card>
  </div>
);

/** The command review: one line per argument and variable name, 72px labels. */
export const CommandReview = () => (
  <div style={pane}>
    <Card padding={12}>
      <div className="h-title-sm" style={{ marginBottom: 8 }}>
        notes-fs
      </div>
      <FactList
        labelWidth={72}
        facts={[
          { label: "command", value: "npx" },
          {
            label: "args",
            value: [
              "-y",
              "@modelcontextprotocol/server-filesystem",
              "/srv/notes",
            ],
          },
          { label: "env", value: ["FS_TOKEN", "LOG_LEVEL"] },
        ]}
      />
    </Card>
  </div>
);

export const Dark = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={pane}>
      <Card padding={12}>
        <FactList
          facts={[
            { label: "type", value: "remote (http)" },
            { label: "url", value: "https://mcp.airtable.com/mcp" },
            { label: "auth", value: "API key" },
          ]}
        />
      </Card>
    </div>
  </HermesProvider>
);
