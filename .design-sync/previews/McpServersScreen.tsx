import { HermesProvider, McpServersScreen } from "@hermes-app/ui";

const phone = {
  width: 390,
  height: 640,
  border: "1px solid var(--h-border)",
  borderRadius: 14,
  overflow: "hidden",
} as const;

const desktop = { ...phone, width: 800, height: 560 } as const;

const servers = [
  {
    name: "grafana",
    transport: "remote" as const,
    address: "https://mcp.grafana.com/mcp",
    auth: "OAuth",
    enabled: true,
    test: {
      status: "connected" as const,
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
    },
  },
  {
    name: "asana",
    transport: "remote" as const,
    address: "https://mcp.asana.com/sse",
    auth: "OAuth",
    enabled: true,
    test: { status: "signInNeeded" as const },
  },
  {
    name: "filesystem",
    transport: "command" as const,
    address: "npx -y @modelcontextprotocol/server-filesystem",
    enabled: false,
  },
];

export const ApplePhone = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <McpServersScreen layout="phone" profile="work" servers={servers} />
    </div>
  </HermesProvider>
);

export const MaterialPhone = () => (
  <div style={phone}>
    <McpServersScreen
      layout="phone"
      profile="work"
      servers={servers}
      addMenuOpen
    />
  </div>
);

export const Desktop = () => (
  <div style={desktop}>
    <McpServersScreen layout="desktop" profile="work" servers={servers} />
  </div>
);

/** The phone's server page, opened from the list. */
export const ApplePhoneServerPage = () => (
  <HermesProvider platform="apple">
    <div style={phone}>
      <McpServersScreen
        layout="phone"
        profile="work"
        servers={servers}
        openServer="asana"
      />
    </div>
  </HermesProvider>
);

export const Empty = () => (
  <div style={phone}>
    <McpServersScreen layout="phone" profile="work" servers={[]} />
  </div>
);

export const LoadingAndFailed = () => (
  <div style={{ display: "flex", gap: 16 }}>
    <div style={{ ...phone, width: 300, height: 400 }}>
      <McpServersScreen layout="phone" servers={[]} state="loading" />
    </div>
    <div style={{ ...phone, width: 300, height: 400 }}>
      <McpServersScreen layout="phone" servers={[]} state="failed" />
    </div>
  </div>
);

export const DarkDesktop = () => (
  <HermesProvider theme="dark" style={{ padding: 16, borderRadius: 14 }}>
    <div style={{ ...desktop, width: 768, height: 520 }}>
      <McpServersScreen
        layout="desktop"
        profile="work"
        servers={servers}
        selected="asana"
      />
    </div>
  </HermesProvider>
);
