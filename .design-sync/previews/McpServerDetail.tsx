import { HermesProvider, McpServerDetail } from "@hermes-app/ui";

const pane = {
  width: 420,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

const grafana = {
  name: "grafana",
  transport: "remote" as const,
  address: "https://mcp.grafana.com/mcp",
  auth: "OAuth",
  enabled: true,
};

/** A tested OAuth server: Connected with its tools and their schema sizes. */
export const TestedOAuthServer = () => (
  <div style={pane}>
    <McpServerDetail
      server={grafana}
      test={{
        status: "connected",
        tools: [
          {
            name: "search_dashboards",
            description: "Find dashboards by title or tag.",
            schemaChars: 320,
          },
          {
            name: "query_prometheus",
            description: "Run a PromQL query.",
            schemaChars: 1420,
          },
        ],
        prompts: 1,
      }}
    />
  </div>
);

/** A command server switched off, its test running. */
export const CommandServerOff = () => (
  <div style={pane}>
    <McpServerDetail
      server={{
        name: "filesystem",
        transport: "command",
        address: "npx -y @modelcontextprotocol/server-filesystem",
        enabled: false,
      }}
      test={{ status: "running" }}
    />
  </div>
);

/** Apple: sign in needed, the banner's Sign in replaces the outlined one. */
export const AppleSignInNeeded = () => (
  <HermesProvider platform="apple">
    <div style={pane}>
      <McpServerDetail
        server={{
          ...grafana,
          name: "asana",
          address: "https://mcp.asana.com/sse",
        }}
        test={{ status: "signInNeeded" }}
      />
    </div>
  </HermesProvider>
);

export const DarkFailed = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={pane}>
      <McpServerDetail
        server={{
          name: "flaky",
          transport: "remote",
          address: "https://flaky.example/mcp",
          enabled: true,
        }}
        signInNote="A sign-in to flaky is already in progress"
        test={{
          status: "failed",
          error: "Connection refused: https://flaky.example/mcp",
        }}
      />
    </div>
  </HermesProvider>
);
