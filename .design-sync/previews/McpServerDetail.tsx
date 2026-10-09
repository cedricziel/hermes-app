import { HermesProvider, McpServerDetail } from "@hermes-app/ui";

const pane = {
  width: 420,
  height: 600,
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

/** iPhone: a tested OAuth server, Connected with its tools and their schema sizes. */
export const TestedOAuthServer = () => (
  <HermesProvider platform="apple" style={pane}>
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
  </HermesProvider>
);

/** Material: a command server switched off, its test running (a spinner in place of the check). */
export const CommandServerOff = () => (
  <div style={{ ...pane, height: 420 }}>
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

/** Mac: sign in needed; the banner's Sign in replaces the Sign in row. */
export const AppleSignInNeeded = () => (
  <HermesProvider platform="apple" typeRamp="default">
    <div style={{ ...pane, height: 420 }}>
      <McpServerDetail
        device="mac"
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

/** Material, dark: a sign-in that could not start and a failed test. */
export const DarkFailed = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ ...pane, height: 480 }}>
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
